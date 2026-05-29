// @ts-nocheck
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

type Json = Record<string, unknown>

function normalizePhoneVN(input: string): string {
  const digits = (input ?? '').replace(/[^\d+]/g, '')
  const onlyDigits = digits.replace(/[^\d]/g, '')
  if (!onlyDigits) return ''

  if (onlyDigits.startsWith('84')) return `+${onlyDigits}`
  if (onlyDigits.startsWith('0')) return `+84${onlyDigits.slice(1)}`
  if (onlyDigits.startsWith('9') || onlyDigits.startsWith('3') || onlyDigits.startsWith('7') || onlyDigits.startsWith('8') || onlyDigits.startsWith('5')) {
    return `+84${onlyDigits}`
  }

  if (digits.startsWith('+')) return digits
  return `+${onlyDigits}`
}

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

function looksLikeUuid(input: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(input)
}

serve(async (req: any) => {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

    if (!supabaseUrl || !serviceRoleKey || !anonKey) {
      return json({ error: 'Server misconfigured' }, 500)
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'Missing authorization header' }, 401)
    }

    const supabaseUserClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: userErr } = await supabaseUserClient.auth.getUser()
    if (userErr || !user) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const body = (await req.json().catch(() => ({}))) as Json
    const rawPhone = typeof body.phone === 'string' ? body.phone.trim() : ''
    const phone = rawPhone ? normalizePhoneVN(rawPhone) : ''
    const rawTargetUserId =
      typeof body.target_user_id === 'string'
        ? body.target_user_id.trim()
        : (typeof body.targetUserId === 'string' ? body.targetUserId.trim() : '')

    if (!phone && !rawTargetUserId) {
      return json({ error: 'Missing phone or target_user_id' }, 400)
    }

    if (phone && !phone.startsWith('+')) {
      return json({ error: 'Invalid phone' }, 400)
    }

    if (rawTargetUserId && !looksLikeUuid(rawTargetUserId)) {
      return json({ error: 'Invalid target_user_id' }, 400)
    }

    console.log('[release-phone-number] requester=', user.id, 'phone=', phone, 'target_user_id=', rawTargetUserId)

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey)

    let targetUserId = ''
    let targetPhone = phone

    if (rawTargetUserId) {
      targetUserId = rawTargetUserId
      const { data, error } = await supabaseAdmin.auth.admin.getUserById(targetUserId)
      if (error) {
        console.log('[release-phone-number] cannot get user by id=', targetUserId, 'error=', error?.message ?? error)
        return json({ error: 'Target user not found' }, 404)
      }

      const authUser = data?.user as { phone?: string | null } | undefined
      targetPhone = normalizePhoneVN(authUser?.phone ?? '')
    } else {
      const perPage = 1000
      for (let page = 1; page <= 100; page++) {
        const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage })
        if (error) {
          return json({ error: 'Cannot list users' }, 500)
        }

        const users = (data?.users ?? []) as Array<{ id: string; phone?: string | null }>
        if (!users.length) break

        const found = users.find((u) => normalizePhoneVN(u.phone ?? '') === phone)
        if (found) {
          targetUserId = found.id
          break
        }
      }
    }

    if (!targetUserId) {
      console.log('[release-phone-number] target not found for phone=', phone)
      return json({ success: true, status: 'not_found' }, 200)
    }

    if (targetUserId === user.id) {
      console.log('[release-phone-number] phone already belongs to requester')
      return json({ success: true, status: 'already_me' }, 200)
    }

    console.log('[release-phone-number] targetUserId=', targetUserId, 'targetPhone=', targetPhone)

    // Check if target has data (for logging only, still proceed to delete)
    const { data: ownedStores } = await supabaseAdmin
      .from('stores')
      .select('id')
      .eq('owner_id', targetUserId)
      .limit(1)

    const { data: memberStores } = await supabaseAdmin
      .from('store_members')
      .select('id')
      .eq('user_id', targetUserId)
      .limit(1)

    const { data: msgs } = await supabaseAdmin
      .from('messages')
      .select('id')
      .or(`sender_id.eq.${targetUserId},receiver_id.eq.${targetUserId}`)
      .limit(1)

    const hasData = (ownedStores && ownedStores.length > 0) || 
                    (memberStores && memberStores.length > 0) || 
                    (msgs && msgs.length > 0)

    if (hasData) {
      console.log('[release-phone-number] target has data but forcing release anyway')
    }

    // Delete all related data
    await supabaseAdmin.from('profiles').delete().eq('id', targetUserId)
    await supabaseAdmin.from('store_members').delete().eq('user_id', targetUserId)
    await supabaseAdmin.from('messages').delete().or(`sender_id.eq.${targetUserId},receiver_id.eq.${targetUserId}`)
    
    // Handle stores owned by target: set owner_id to null (orphaned stores can be claimed later)
    await supabaseAdmin.from('stores').update({ owner_id: null }).eq('owner_id', targetUserId)

    // Release phone by updating to a placeholder value
    // This breaks the phone_unique constraint tie, allowing the real phone to be reused
    const placeholderPhone = `+999999999${Math.floor(Math.random() * 100000)}`
    const { error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(targetUserId, { phone: placeholderPhone })
    if (updateErr) {
      console.log('[release-phone-number] failed to set placeholder phone:', updateErr)
      return json({ error: 'Cannot release phone', details: updateErr.message }, 500)
    }

    console.log('[release-phone-number] released phone by setting placeholder for target user id=', targetUserId)
    return json({ success: true, status: 'released', target_user_id: targetUserId, released_phone: targetPhone || null }, 200)
  } catch (error: any) {
    return json({ error: error?.message ?? 'Unknown error' }, 400)
  }
})

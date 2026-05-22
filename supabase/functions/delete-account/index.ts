import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Verify the requesting user from their JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization header' }), { status: 401 })
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    // 1) Delete all related data in public schema first (to avoid FK constraints)
    const { error: msgErr } = await supabaseAdmin.from('messages').delete().or('sender_id.eq.' + user.id + ',receiver_id.eq.' + user.id)
    if (msgErr) console.error('Error deleting messages:', msgErr)
    
    const { error: smErr } = await supabaseAdmin.from('store_members').delete().eq('user_id', user.id)
    if (smErr) console.error('Error deleting store_members:', smErr)
    
    const { error: profErr } = await supabaseAdmin.from('profiles').delete().eq('id', user.id)
    if (profErr) console.error('Error deleting profiles:', profErr)
    
    // Delete stores owned by this user (cascade will clean up store-related tables)
    const { error: storeErr } = await supabaseAdmin.from('stores').delete().eq('owner_id', user.id)
    if (storeErr) console.error('Error deleting stores:', storeErr)

    // 2) Delete the auth user permanently
    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id)

    if (deleteError) throw deleteError

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})

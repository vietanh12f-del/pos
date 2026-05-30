
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.21.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { phone, code } = await req.json()
    
    const apiKey = req.headers.get('apikey')
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'Missing apikey header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!phone || !code) {
      return new Response(
        JSON.stringify({ error: 'Phone and code are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Normalize phone - create both formats for comparison
    let normalizedPhoneWithPlus = phone.trim().replace(/\s/g, '')
    let normalizedPhoneWithoutPlus = normalizedPhoneWithPlus
    
    if (normalizedPhoneWithPlus.startsWith('0')) {
      normalizedPhoneWithPlus = '+84' + normalizedPhoneWithPlus.substring(1)
      normalizedPhoneWithoutPlus = normalizedPhoneWithPlus.substring(1)
    } else if (normalizedPhoneWithPlus.startsWith('+')) {
      normalizedPhoneWithoutPlus = normalizedPhoneWithPlus.substring(1)
    } else if (normalizedPhoneWithPlus.startsWith('84')) {
      normalizedPhoneWithPlus = '+' + normalizedPhoneWithPlus
    } else {
      normalizedPhoneWithPlus = '+84' + normalizedPhoneWithPlus
      normalizedPhoneWithoutPlus = normalizedPhoneWithPlus.substring(1)
    }
    
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Verify OTP from database - check both phone formats
    let otpRecords: any[] | null = null
    let fetchError: any = null

    let { data: otpRecordsWithPlus, error: fetchErrorWithPlus } = await supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('phone', normalizedPhoneWithPlus)
      .eq('code', code)
      .eq('purpose', 'login')
      .eq('used', false)
      .order('created_at', { ascending: false })
      .limit(1)
    
    if (fetchErrorWithPlus || !otpRecordsWithPlus || otpRecordsWithPlus.length === 0) {
      let { data: otpRecordsWithoutPlus, error: fetchErrorWithoutPlus } = await supabaseAdmin
        .from('otp_codes')
        .select('*')
        .eq('phone', normalizedPhoneWithoutPlus)
        .eq('code', code)
        .eq('purpose', 'login')
        .eq('used', false)
        .order('created_at', { ascending: false })
        .limit(1)
      
      otpRecords = otpRecordsWithoutPlus
      fetchError = fetchErrorWithoutPlus
    } else {
      otpRecords = otpRecordsWithPlus
      fetchError = fetchErrorWithPlus
    }
    
    if (fetchError || !otpRecords || otpRecords.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Invalid OTP code' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    const otpRecord = otpRecords[0]
    
    const now = new Date()
    const expiresAt = new Date(otpRecord.expires_at)
    
    if (now > expiresAt) {
      return new Response(
        JSON.stringify({ error: 'OTP has expired' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Delete OTP after using it
    await supabaseAdmin
      .from('otp_codes')
      .delete()
      .eq('id', otpRecord.id)

    let userId: string | null = null
    const getDigitsOnly = (str: string | null | undefined) => (str ? str.replace(/\D/g, '') : '')
    const incomingDigits = getDigitsOnly(normalizedPhoneWithPlus)
    
    const { data: userList, error: listError } = await supabaseAdmin.auth.admin.listUsers()
    const { data: profiles } = await supabaseAdmin.from('profiles').select('id, phone_number, email')
    
    if (!listError && userList?.users) {
      let existingUser = userList.users.find(u => getDigitsOnly(u.phone) === incomingDigits)
      
      if (!existingUser && profiles) {
        const matchingProfile = profiles.find(p => getDigitsOnly(p.phone_number) === incomingDigits)
        if (matchingProfile) {
          existingUser = userList.users.find(u => u.id === matchingProfile.id)
        }
      }
      
      if (existingUser) {
        userId = existingUser.id
      }
    }
    
    if (!userId) {
      const dummyEmail = `${normalizedPhoneWithoutPlus}@example.com`
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        email: dummyEmail,
        phone: normalizedPhoneWithPlus,
        phone_confirm: true,
        email_confirm: true,
        user_metadata: { source: 'zalo_otp_login' }
      })
      
      if (!createError && newUser?.user) {
        userId = newUser.user.id
      } else if (createError) {
        const { data: userListRetry } = await supabaseAdmin.auth.admin.listUsers()
        if (userListRetry?.users) {
          const existingUser = userListRetry.users.find(u => getDigitsOnly(u.phone) === incomingDigits)
          if (existingUser) userId = existingUser.id
        }
        if (!userId) {
          throw createError
        }
      }
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Failed to get or create user' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { data: existingUserData } = await supabaseAdmin.auth.admin.getUserById(userId)
    const existingEmail = existingUserData?.user?.email
    const dummyEmail = `${normalizedPhoneWithoutPlus}@example.com`
    const emailToUse = existingEmail || dummyEmail
    
    if (!existingEmail) {
      try {
        await supabaseAdmin.auth.admin.updateUserById(userId, {
          email: dummyEmail,
          email_confirm: true
        })
      } catch (_) {}
    }

    const { data: signInData, error: signInError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: emailToUse,
      options: {
        redirectTo: 'https://cgqxrsoaxgyvcskbixuu.supabase.co/auth/v1/callback'
      }
    })

    let accessToken: string | undefined
    let refreshToken: string | undefined

    if (!signInError && signInData?.properties?.email_otp) {
      const { data: sessionData } = await supabaseAdmin.auth.verifyOtp({
        email: emailToUse,
        token: signInData.properties.email_otp,
        type: 'magiclink'
      })
      
      if (sessionData?.session) {
        accessToken = sessionData.session.access_token
        refreshToken = sessionData.session.refresh_token
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true,
        user_id: userId,
        phone: normalizedPhoneWithPlus,
        access_token: accessToken,
        refresh_token: refreshToken,
        message: 'OTP verified successfully'
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    return new Response(
      JSON.stringify({ error: error?.message ?? 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


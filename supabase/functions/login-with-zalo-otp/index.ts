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
    console.log('[login-with-zalo-otp] DEBUG Raw phone:', phone)
    
    if (normalizedPhoneWithPlus.startsWith('0')) {
      normalizedPhoneWithPlus = '+84' + normalizedPhoneWithPlus.substring(1)
      normalizedPhoneWithoutPlus = '84' + normalizedPhoneWithPlus.substring(3) // Remove +84 and add just 84
    } else if (normalizedPhoneWithPlus.startsWith('+')) {
      normalizedPhoneWithoutPlus = normalizedPhoneWithPlus.substring(1)
    } else {
      normalizedPhoneWithPlus = '+' + normalizedPhoneWithPlus
      // normalizedPhoneWithoutPlus remains as is
    }
    // Create Supabase admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Verify OTP from database (check expiration in memory) - check both phone formats
    let otpRecords: any[] | null = null
    let fetchError: any = null

    // First try with + prefix
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
      // If no match, try without + prefix
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
      console.error('[login-with-zalo-otp] No matching OTP found:', fetchError)
      return new Response(
        JSON.stringify({ error: 'Invalid OTP code' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    const otpRecord = otpRecords[0]
    
    // Check expiration in memory
    const now = new Date()
    const expiresAt = new Date(otpRecord.expires_at)
    console.log('[login-with-zalo-otp] Checking expiration:', { now: now.toISOString(), expiresAt: expiresAt.toISOString(), isExpired: now > expiresAt })
    
    if (now > expiresAt) {
      console.error('[login-with-zalo-otp] OTP expired')
      return new Response(
        JSON.stringify({ error: 'OTP has expired' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Mark OTP as used
    await supabaseAdmin
      .from('otp_codes')
      .update({ used: true })
      .eq('id', otpRecord.id)

    // Find or create user with this phone
    let userId: string | null = null
    
    // First, try to find existing user by listing all users
    const { data: userList, error: listError } = await supabaseAdmin.auth.admin.listUsers()
    
    if (listError) {
      console.error('[login-with-zalo-otp] Error listing users:', listError)
    } else if (userList?.users) {
      // More robust comparison - match either format
      const existingUser = userList.users.find(u => {
        const userPhone = u.phone?.trim()
        const matchWithPlus = userPhone === normalizedPhoneWithPlus
        const matchWithoutPlus = userPhone === normalizedPhoneWithoutPlus
        return matchWithPlus || matchWithoutPlus
      })
      
      if (existingUser) {
        userId = existingUser.id
      }
    }
    
    // If no user found, create new user
    if (!userId) {
      console.log('[login-with-zalo-otp] No existing user found, creating new user')
      try {
        // Create a dummy email based on phone number
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
          console.error('[login-with-zalo-otp] Error creating user, trying to find again:', createError)
          // If create failed, try listing users one more time
          const { data: userListRetry, error: listErrorRetry } = await supabaseAdmin.auth.admin.listUsers()
          if (!listErrorRetry && userListRetry?.users) {
            const existingUser = userListRetry.users.find(u => {
              const userPhone = u.phone?.trim()
              return userPhone === normalizedPhoneWithPlus || userPhone === normalizedPhoneWithoutPlus
            })
            if (existingUser) {
              console.log('[login-with-zalo-otp] Found user on retry:', existingUser.id)
              userId = existingUser.id
            }
          }
          if (!userId) {
            throw createError
          }
        }
      } catch (err: any) {
        console.error('[login-with-zalo-otp] Failed to get or create user:', err)
        return new Response(
          JSON.stringify({ error: 'Failed to get or create user', details: err.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Failed to get or create user' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create a dummy email based on phone number
    const dummyEmail = `${normalizedPhoneWithoutPlus}@example.com`
    
    // First, make sure the user has an email set (for existing users)
    try {
      await supabaseAdmin.auth.admin.updateUserById(userId, {
        email: dummyEmail,
        email_confirm: true
      })
    } catch (updateError) {
      console.log('[login-with-zalo-otp] User may already have email, continuing...', updateError)
    }

    // Create session for user using generateLink
    console.log('[login-with-zalo-otp] Generating link with email:', dummyEmail)
    const { data: signInData, error: signInError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: dummyEmail,
      options: {
        redirectTo: 'https://cgqxrsoaxgyvcskbixuu.supabase.co/auth/v1/callback'
      }
    })

    let accessToken: string | undefined
    let refreshToken: string | undefined

    if (signInError) {
      console.error('[login-with-zalo-otp] Failed to generate link:', signInError)
    } else if (signInData?.properties?.email_otp) {
      // Now use the email OTP to sign in and get a session
      const { data: sessionData, error: signInOtpError } = await supabaseAdmin.auth.verifyOtp({
        email: dummyEmail,
        token: signInData.properties.email_otp,
        type: 'magiclink'
      })
      
      if (!signInOtpError && sessionData?.session) {
        accessToken = sessionData.session.access_token
        refreshToken = sessionData.session.refresh_token
      } else {
        console.error('[login-with-zalo-otp] Failed to sign in with OTP:', signInOtpError)
      }
    }

    // Return the user info - client will use this to establish session
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
    console.error('[login-with-zalo-otp] Error:', error)
    return new Response(
      JSON.stringify({ error: error?.message ?? 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

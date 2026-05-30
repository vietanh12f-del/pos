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
      normalizedPhoneWithoutPlus = normalizedPhoneWithPlus.substring(1) // Remove '+' to get 84xxx
    } else if (normalizedPhoneWithPlus.startsWith('+')) {
      normalizedPhoneWithoutPlus = normalizedPhoneWithPlus.substring(1)
    } else if (normalizedPhoneWithPlus.startsWith('84')) {
      normalizedPhoneWithPlus = '+' + normalizedPhoneWithPlus
    } else {
      normalizedPhoneWithPlus = '+84' + normalizedPhoneWithPlus
      normalizedPhoneWithoutPlus = normalizedPhoneWithPlus.substring(1)
    }
    console.log('[login-with-zalo-otp] DEBUG Phones for match:', { withPlus: normalizedPhoneWithPlus, withoutPlus: normalizedPhoneWithoutPlus })
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
    
    // Also fetch profiles table in case phone is stored there!
    const { data: profiles } = await supabaseAdmin.from('profiles').select('id, phone_number, email')
    console.log('[login-with-zalo-otp] Profiles:', JSON.stringify(profiles))
    
    // Helper function to extract only digits from string for comparison
    const getDigitsOnly = (str: string | null | undefined) => {
      if (!str) return ''
      return str.replace(/\D/g, '') // removes anything that's not a digit
    }
    
    // Get digits only for incoming phone to compare
    const incomingDigits = getDigitsOnly(normalizedPhoneWithPlus)
    console.log('[login-with-zalo-otp] Looking for user, incoming digits:', incomingDigits)
    
    if (listError) {
      console.error('[login-with-zalo-otp] Error listing users:', listError)
    } else if (userList?.users) {
      // Log all users' phones for debugging!
      // First, fetch all stores and memberships
      const { data: allStores } = await supabaseAdmin.from('stores').select('id, name, owner_id')
      const { data: allMemberships } = await supabaseAdmin.from('store_members').select('*')
      
      console.log('[login-with-zalo-otp] All stores:', JSON.stringify(allStores))
      console.log('[login-with-zalo-otp] All memberships:', JSON.stringify(allMemberships))
      
      // Log all users' phones for debugging!
      console.log('[login-with-zalo-otp] All users (count:', userList.users.length, '):')
      userList.users.forEach(u => {
        const userStores = allStores?.filter(s => s.owner_id === u.id)
        const userMemberships = allMemberships?.filter(m => m.user_id === u.id)
        console.log('[login-with-zalo-otp] User FULL:', JSON.stringify({ 
          id: u.id, 
          email: u.email, 
          phone: u.phone, 
          digits: getDigitsOnly(u.phone),
          created_at: u.created_at,
          owned_stores: userStores?.map(s => s.name),
          memberships: userMemberships?.map(m => ({ store: m.store_id, role: m.role }))
        }))
      })
      
      // Try first via auth.users.phone
      let existingUser = userList.users.find(u => {
        const userPhoneDigits = getDigitsOnly(u.phone)
        return userPhoneDigits === incomingDigits
      })
      
      // If not found, try via profiles.phone_number
      if (!existingUser && profiles) {
        const matchingProfile = profiles.find(p => {
          const profilePhoneDigits = getDigitsOnly(p.phone_number)
          return profilePhoneDigits === incomingDigits
        })
        if (matchingProfile) {
          existingUser = userList.users.find(u => u.id === matchingProfile.id)
        }
      }
      
      if (existingUser) {
        userId = existingUser.id
        console.log('[login-with-zalo-otp] Found existing user:', existingUser.id)
      } else {
        console.log('[login-with-zalo-otp] No existing user found with matching digits')
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
              const userPhoneDigits = getDigitsOnly(u.phone)
              return userPhoneDigits === incomingDigits
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

    // Get existing user details
    const { data: existingUserData } = await supabaseAdmin.auth.admin.getUserById(userId)
    const existingEmail = existingUserData?.user?.email
    const dummyEmail = `${normalizedPhoneWithoutPlus}@example.com`
    const emailToUse = existingEmail || dummyEmail

    console.log('[login-with-zalo-otp] Using email for login:', emailToUse, '(existingEmail:', existingEmail, ')')
    
    // First, make sure the user has an email set (for existing users) - only set if they don't have one
    if (!existingEmail) {
      try {
        await supabaseAdmin.auth.admin.updateUserById(userId, {
          email: dummyEmail,
          email_confirm: true
        })
      } catch (updateError) {
        console.log('[login-with-zalo-otp] User may already have email, continuing...', updateError)
      }
    }

    // Create session for user using generateLink
    console.log('[login-with-zalo-otp] Generating link with email:', emailToUse)
    const { data: signInData, error: signInError } = await supabaseAdmin.auth.admin.generateLink({
      type: 'magiclink',
      email: emailToUse,
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
        email: emailToUse,
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

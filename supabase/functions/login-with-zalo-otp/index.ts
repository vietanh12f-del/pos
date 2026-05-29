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

    // Normalize phone
    let normalizedPhone = phone.trim().replace(/\s/g, '')
    if (normalizedPhone.startsWith('0')) {
      normalizedPhone = '+84' + normalizedPhone.substring(1)
    } else if (!normalizedPhone.startsWith('+')) {
      normalizedPhone = '+' + normalizedPhone
    }

    // Create Supabase admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Verify OTP from database (check expiration in memory)
    const { data: otpRecords, error: fetchError } = await supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('phone', normalizedPhone)
      .eq('code', code)
      .eq('purpose', 'login')
      .eq('used', false)
      .order('created_at', { ascending: false })
      .limit(1)
    
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
    // First, try to find existing user by phone
    const { data: existingUser, error: userError } = await supabaseAdmin.auth.admin.listUsers()
    
    let userId: string | null = null
    
    // Search for user with matching phone
    if (existingUser?.users) {
      const userWithPhone = existingUser.users.find(u => u.phone === normalizedPhone)
      if (userWithPhone) {
        userId = userWithPhone.id
      }
    }

    // If no user found, create new user
    if (!userId) {
      const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
        phone: normalizedPhone,
        user_metadata: { source: 'zalo_otp_login' }
      })
      
      if (createError) {
        return new Response(
          JSON.stringify({ error: 'Failed to create user', details: createError.message }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
      
      userId = newUser?.user?.id ?? null
    }

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Failed to get or create user' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create session for user using signInWithIdToken or custom token
    // For now, we return the user_id and let client handle session creation
    // Or we can create a custom JWT
    
    // Simple approach: Return user info and let client call signInWithOTP
    // Advanced approach: Create custom JWT (requires more setup)

    return new Response(
      JSON.stringify({ 
        success: true,
        user_id: userId,
        phone: normalizedPhone,
        message: 'OTP verified. Please complete login.'
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

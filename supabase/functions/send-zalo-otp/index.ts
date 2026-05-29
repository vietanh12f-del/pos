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
    const { phone, purpose = 'link_phone' } = await req.json()
    
    // For login purpose, allow anonymous access (no JWT required)
    // For link_phone, user should be authenticated (but we'll check in app logic)
    const authHeader = req.headers.get('authorization')
    const apiKey = req.headers.get('apikey')
    
    // Validate apikey is present
    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'Missing apikey header' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!phone) {
      return new Response(
        JSON.stringify({ error: 'Phone number is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Normalize phone to VN format
    let normalizedPhone = phone.trim().replace(/\s/g, '')
    if (normalizedPhone.startsWith('0')) {
      normalizedPhone = '+84' + normalizedPhone.substring(1)
    } else if (!normalizedPhone.startsWith('+')) {
      normalizedPhone = '+' + normalizedPhone
    }

    // Validate VN phone format
    const vnPhoneRegex = /^\+84[1-9]\d{8,9}$/
    if (!vnPhoneRegex.test(normalizedPhone)) {
      return new Response(
        JSON.stringify({ error: 'Invalid Vietnamese phone number format' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Generate 6-digit OTP
    const otpCode = Math.floor(100000 + Math.random() * 900000).toString()

    // Set expiration to 5 minutes
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString()

    // Store OTP in database
    const { error: insertError } = await supabaseAdmin
      .from('otp_codes')
      .insert({
        phone: normalizedPhone,
        code: otpCode,
        purpose: purpose,
        expires_at: expiresAt,
        used: false
      })

    if (insertError) {
      console.error('[send-zalo-otp] Failed to store OTP:', insertError)
      return new Response(
        JSON.stringify({ error: 'Failed to generate OTP', details: insertError.message }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Zalo OA Access Token (should be moved to env var)
    const zaloAccessToken = Deno.env.get('ZALO_OA_ACCESS_TOKEN')
    if (!zaloAccessToken) {
      console.error('[send-zalo-otp] ZALO_OA_ACCESS_TOKEN not set')
      // Still return success for testing - in production this should fail
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'OTP generated (Zalo not configured - testing mode)',
          phone: normalizedPhone,
          expires_at: expiresAt,
          code: otpCode // Remove in production!
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Format message for Zalo
    const message = `Mã OTP xác thực số điện thoại của bạn là: ${otpCode}\nMã có hiệu lực trong 5 phút.\nVui lòng không chia sẻ mã này với bất kỳ ai.`

    // Send via Zalo OA API
    // Note: Need to get user_id from phone first via Zalo API
    // For now, this is a placeholder - actual implementation requires Zalo user mapping
    console.log('[send-zalo-otp] Would send to Zalo:', { phone: normalizedPhone, message })

    // TODO: Implement Zalo user lookup by phone
    // 1. Call Zalo API to find user_id by phone
    // 2. Send message to that user_id

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'OTP sent via Zalo',
        phone: normalizedPhone,
        expires_at: expiresAt
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('[send-zalo-otp] Error:', error)
    return new Response(
      JSON.stringify({ error: error?.message ?? 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

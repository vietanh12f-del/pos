
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
    
    const apiKey = req.headers.get('apikey')
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

    let normalizedPhone = phone.trim().replace(/\s/g, '')
    if (normalizedPhone.startsWith('0')) {
      normalizedPhone = '+84' + normalizedPhone.substring(1)
    } else if (!normalizedPhone.startsWith('+')) {
      normalizedPhone = '+' + normalizedPhone
    }

    const vnPhoneRegex = /^\+84[1-9]\d{8,9}$/
    if (!vnPhoneRegex.test(normalizedPhone)) {
      return new Response(
        JSON.stringify({ error: 'Invalid Vietnamese phone number format' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString()
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString()

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

    const zaloAccessToken = Deno.env.get('ZALO_OA_ACCESS_TOKEN')
    const USE_ZALO = Deno.env.get('USE_ZALO') === 'true'

    if (!USE_ZALO || !zaloAccessToken) {
      console.log('[send-zalo-otp] Test mode - returning OTP in response')
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'OTP generated (test mode)',
          phone: normalizedPhone,
          expires_at: expiresAt,
          code: otpCode
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Chỉ chạy nếu USE_ZALO = true và có token
    const message = `Mã OTP xác thực số điện thoại của bạn là: ${otpCode}\nMã có hiệu lực trong 5 phút.\nVui lòng không chia sẻ mã này với bất kỳ ai.`
    
    try {
      console.log('[send-zalo-otp] Attempting to send Zalo message to:', normalizedPhone)
      
      // Note: Zalo OA thường cần user_id (không phải số điện thoại) để gửi tin
      // Nếu bạn có map user_id <-> số điện thoại, hãy dùng ở đây
      // Hiện tại, bỏ qua bước gửi Zalo và dùng test mode
      
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'OTP sent (Zalo integration placeholder)',
          phone: normalizedPhone,
          expires_at: expiresAt,
          code: otpCode
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
      
    } catch (zaloError: any) {
      console.error('[send-zalo-otp] Zalo API error:', zaloError)
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: `OTP generated (Zalo failed: ${zaloError.message})`,
          phone: normalizedPhone,
          expires_at: expiresAt,
          code: otpCode
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

  } catch (error: any) {
    console.error('[send-zalo-otp] Error:', error)
    return new Response(
      JSON.stringify({ error: error?.message ?? 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


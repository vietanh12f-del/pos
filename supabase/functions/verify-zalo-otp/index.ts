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
    const { phone, code, purpose = 'link_phone' } = await req.json()

    if (!phone || !code) {
      return new Response(
        JSON.stringify({ error: 'Phone number and code are required' }),
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

    // Find matching OTP (not checking expiration in query, will check in memory)
    console.log('[verify-zalo-otp] Checking OTP:', { phone: normalizedPhone, code, purpose })
    
    const { data: otpRecords, error: fetchError } = await supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('phone', normalizedPhone)
      .eq('code', code)
      .eq('purpose', purpose)
      .eq('used', false)
      .order('created_at', { ascending: false })
      .limit(1)
    
    console.log('[verify-zalo-otp] Found records:', otpRecords)
    
    if (fetchError || !otpRecords || otpRecords.length === 0) {
      console.error('[verify-zalo-otp] No matching OTP found:', fetchError)
      return new Response(
        JSON.stringify({ error: 'Invalid OTP code' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    const otpRecord = otpRecords[0]
    
    // Check expiration in memory
    const now = new Date()
    const expiresAt = new Date(otpRecord.expires_at)
    console.log('[verify-zalo-otp] Checking expiration:', { now: now.toISOString(), expiresAt: expiresAt.toISOString(), isExpired: now > expiresAt })
    
    if (now > expiresAt) {
      console.error('[verify-zalo-otp] OTP expired')
      return new Response(
        JSON.stringify({ error: 'OTP has expired', debug: { expiredAt: otpRecord.expires_at } }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Mark as used
    const { error: updateError } = await supabaseAdmin
      .from('otp_codes')
      .update({ used: true })
      .eq('id', otpRecord.id)

    if (updateError) {
      console.error('[verify-zalo-otp] Failed to mark OTP as used:', updateError)
      // Non-critical error, continue
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        verified: true,
        phone: normalizedPhone,
        purpose: purpose
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error: any) {
    console.error('[verify-zalo-otp] Error:', error)
    return new Response(
      JSON.stringify({ error: error?.message ?? 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

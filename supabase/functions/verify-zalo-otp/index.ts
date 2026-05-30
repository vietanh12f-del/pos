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

    // Normalize phone - create both formats for comparison
    let normalizedPhoneWithPlus = phone.trim().replace(/\s/g, '')
    let normalizedPhoneWithoutPlus = normalizedPhoneWithPlus
    if (normalizedPhoneWithPlus.startsWith('0')) {
      normalizedPhoneWithPlus = '+84' + normalizedPhoneWithPlus.substring(1)
      normalizedPhoneWithoutPlus = '84' + normalizedPhoneWithPlus.substring(3)
    } else if (normalizedPhoneWithPlus.startsWith('+')) {
      normalizedPhoneWithoutPlus = normalizedPhoneWithPlus.substring(1)
    } else {
      normalizedPhoneWithPlus = '+' + normalizedPhoneWithPlus
    }

    // Create Supabase admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    )

    // Find matching OTP - check both formats
    console.log('[verify-zalo-otp] Checking OTP:', { phone: normalizedPhoneWithPlus, code, purpose })
    
    let otpRecords: any[] | null = null
    let fetchError: any = null

    const { data: otpRecordsWithPlus, error: fetchErrorWithPlus } = await supabaseAdmin
      .from('otp_codes')
      .select('*')
      .eq('phone', normalizedPhoneWithPlus)
      .eq('code', code)
      .eq('purpose', purpose)
      .eq('used', false)
      .order('created_at', { ascending: false })
      .limit(1)
    
    if (fetchErrorWithPlus || !otpRecordsWithPlus || otpRecordsWithPlus.length === 0) {
      const { data: otpRecordsWithoutPlus, error: fetchErrorWithoutPlus } = await supabaseAdmin
        .from('otp_codes')
        .select('*')
        .eq('phone', normalizedPhoneWithoutPlus)
        .eq('code', code)
        .eq('purpose', purpose)
        .eq('used', false)
        .order('created_at', { ascending: false })
        .limit(1)
      
      otpRecords = otpRecordsWithoutPlus
      fetchError = fetchErrorWithoutPlus
    } else {
      otpRecords = otpRecordsWithPlus
      fetchError = fetchErrorWithPlus
    }
    
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

    // Note: Not marking as used here - login-with-zalo-otp will handle it
    // This allows the same OTP to be used for both verification and login

    return new Response(
      JSON.stringify({ 
        success: true, 
        verified: true,
        phone: normalizedPhoneWithPlus,
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

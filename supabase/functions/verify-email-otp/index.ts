
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
        const { email, code, purpose = 'login' } = await req.json()
        
        const apiKey = req.headers.get('apikey')
        if (!apiKey) {
            return new Response(
                JSON.stringify({ error: 'Missing apikey header' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        
        if (!email || !code) {
            return new Response(
                JSON.stringify({ error: 'Email and code are required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
            { auth: { autoRefreshToken: false, persistSession: false } }
        )

        // Find valid OTP
        const { data: otpRecords, error: fetchError } = await supabaseAdmin
            .from('otp_codes')
            .select('*')
            .eq('email', email)
            .eq('code', code)
            .eq('purpose', purpose)
            .eq('used', false)
            .order('created_at', { ascending: false })
            .limit(1)

        if (fetchError || !otpRecords || otpRecords.length === 0) {
            console.error('[verify-email-otp] Invalid OTP:', fetchError)
            return new Response(
                JSON.stringify({ error: 'Invalid OTP code' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const otpRecord = otpRecords[0]
        
        // Check if expired
        const now = new Date()
        const expiresAt = new Date(otpRecord.expires_at)
        if (now > expiresAt) {
            console.error('[verify-email-otp] OTP expired')
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

        // Find or create user
        let userId: string | undefined
        const { data: existingUsers } = await supabaseAdmin.auth.admin.listUsers()
        const existingUser = existingUsers.users.find(u => u.email?.toLowerCase() === email.toLowerCase())
        
        if (existingUser) {
            userId = existingUser.id
        } else {
            const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
                email: email,
                email_confirm: true
            })
            
            if (createError || !newUser.user) {
                console.error('[verify-email-otp] Failed to create user:', createError)
                return new Response(
                    JSON.stringify({ error: 'Failed to get or create user' }),
                    { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
                )
            }
            userId = newUser.user.id
        }

        // Generate session tokens
        const { data: signInData, error: signInError } = await supabaseAdmin.auth.admin.generateLink({
            type: 'magiclink',
            email: email,
            options: {
                redirectTo: Deno.env.get('SUPABASE_URL') + '/auth/v1/callback'
            }
        })

        let accessToken: string | undefined
        let refreshToken: string | undefined

        if (!signInError && signInData?.properties?.email_otp) {
            const { data: sessionData } = await supabaseAdmin.auth.verifyOtp({
                email: email,
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
                email: email,
                access_token: accessToken,
                refresh_token: refreshToken,
                message: 'OTP verified successfully'
            }),
            { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )

    } catch (error: any) {
        console.error('[verify-email-otp] Error:', error)
        return new Response(
            JSON.stringify({ error: error?.message ?? 'Unknown error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

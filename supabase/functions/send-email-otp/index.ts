
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.21.0'
import { SmtpClient } from 'https://deno.land/x/smtp@v0.7.0/mod.ts'

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders })
    }

    try {
        const { email, purpose = 'login' } = await req.json()
        const apiKey = req.headers.get('apikey')
        
        if (!apiKey) {
            return new Response(
                JSON.stringify({ error: 'Missing apikey header' }),
                { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
        
        if (!email) {
            return new Response(
                JSON.stringify({ error: 'Email is required' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Validate email
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
        if (!emailRegex.test(email)) {
            return new Response(
                JSON.stringify({ error: 'Invalid email format' }),
                { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        const supabaseAdmin = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
            { auth: { autoRefreshToken: false, persistSession: false } }
        )

        // Generate OTP code and store in database
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString()
        const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString()

        // Store OTP in otp_codes (using email instead of phone)
        const { error: insertError } = await supabaseAdmin
            .from('otp_codes')
            .insert({
                email: email,
                code: otpCode,
                purpose: purpose,
                expires_at: expiresAt,
                used: false
            })

        if (insertError) {
            console.error('[send-email-otp] Failed to store OTP:', insertError)
            return new Response(
                JSON.stringify({ error: 'Failed to generate OTP', details: insertError.message }),
                { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Check if we should use real email sending or test mode
        const useRealEmail = Deno.env.get('USE_REAL_EMAIL') === 'true'
        const smtpHost = Deno.env.get('SMTP_HOST')
        const smtpUser = Deno.env.get('SMTP_USER')
        const smtpPassword = Deno.env.get('SMTP_PASSWORD')
        const smtpPort = parseInt(Deno.env.get('SMTP_PORT') || '587')
        const smtpEnableSSL = Deno.env.get('SMTP_ENABLE_SSL') === 'true'
        const smtpFromAddress = Deno.env.get('SMTP_FROM_ADDRESS')
        
        if (!useRealEmail || !smtpHost || !smtpUser || !smtpPassword || !smtpFromAddress) {
            console.log('[send-email-otp] Test mode - returning OTP in response')
            return new Response(
                JSON.stringify({ 
                    success: true, 
                    message: 'OTP generated (test mode)',
                    email: email,
                    expires_at: expiresAt,
                    code: otpCode
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }

        // Send email via SMTP (like VNVending.com)
        const client = new SmtpClient()
        try {
            console.log('[send-email-otp] Connecting to SMTP server...')
            await client.connect({
                hostname: smtpHost,
                port: smtpPort,
                username: smtpUser,
                password: smtpPassword,
                tls: smtpEnableSSL
            })

            console.log('[send-email-otp] Sending email...')
            const fromAddress = smtpFromAddress
            const toAddress = email
            const subject = 'Mã OTP xác thực SmartKiot của bạn'
            const htmlBody = `
                <p>Xin chào,</p>
                <p>Mã OTP xác thực của bạn là: <strong>${otpCode}</strong></p>
                <p>Mã này có hiệu lực trong 5 phút. Vui lòng không chia sẻ mã này với bất kỳ ai.</p>
                <p>Trân trọng,<br>Đội ngũ SmartKiot</p>
            `
            const textBody = `
                Xin chào,

                Mã OTP xác thực của bạn là: ${otpCode}

                Mã này có hiệu lực trong 5 phút. Vui lòng không chia sẻ mã này với bất kỳ ai.

                Trân trọng,
                Đội ngũ SmartKiot
            `

            await client.send({
                from: fromAddress,
                to: toAddress,
                subject: subject,
                content: textBody,
                html: htmlBody
            })

            console.log('[send-email-otp] Email sent successfully!')
            await client.close()

            return new Response(
                JSON.stringify({ 
                    success: true, 
                    message: 'OTP đã được gửi qua email',
                    email: email,
                    expires_at: expiresAt
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        } catch (emailError: any) {
            console.error('[send-email-otp] Error sending SMTP email:', emailError)
            await client.close()
            // Fallback to test mode if email fails
            return new Response(
                JSON.stringify({ 
                    success: true, 
                    message: `OTP generated (email failed: ${emailError.message})`,
                    email: email,
                    expires_at: expiresAt,
                    code: otpCode
                }),
                { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
            )
        }
    } catch (error: any) {
        console.error('[send-email-otp] Error:', error)
        return new Response(
            JSON.stringify({ error: error?.message ?? 'Unknown error' }),
            { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
    }
})

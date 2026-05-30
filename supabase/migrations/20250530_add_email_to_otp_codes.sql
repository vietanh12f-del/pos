
-- Add email column to otp_codes table to support email OTP
alter table otp_codes add column if not exists email text;

-- Make phone column optional since we can have OTPs for email
alter table otp_codes alter column phone drop not null;

-- Add indexes for email and phone lookups
create index if not exists idx_otp_codes_email on otp_codes(email);
create index if not exists idx_otp_codes_phone on otp_codes(phone);

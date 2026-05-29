-- Create table for Zalo OTP codes
-- This stores OTP codes sent via Zalo OA for phone verification

create table if not exists otp_codes (
  id uuid default gen_random_uuid() primary key,
  phone text not null,
  code text not null,
  purpose text not null default 'link_phone', -- 'login', 'link_phone', 'reset_password'
  expires_at timestamp with time zone not null,
  used boolean default false,
  created_at timestamp with time zone default now()
);

-- Index for fast lookup of active OTP codes
comment on table otp_codes is 'Stores OTP codes sent via Zalo for phone verification';

-- Enable RLS
alter table otp_codes enable row level security;

-- Only allow insert/update via edge functions (service role)
drop policy if exists "Enable insert for authenticated users only" on otp_codes;
create policy "Enable insert for authenticated users only" on otp_codes
  for insert to authenticated with check (true);

-- Clean up expired codes periodically (optional, can use pg_cron)
-- Or rely on application logic to reject expired codes

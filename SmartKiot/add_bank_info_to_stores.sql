-- Add bank account information to stores table
-- Run this in Supabase SQL Editor

ALTER TABLE stores 
ADD COLUMN IF NOT EXISTS bank_account_number TEXT,
ADD COLUMN IF NOT EXISTS bank_name TEXT;

-- Update Store model in app accordingly

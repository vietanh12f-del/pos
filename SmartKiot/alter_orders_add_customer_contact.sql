-- Add customer contact fields to orders table
-- Run this in Supabase SQL Editor

ALTER TABLE orders
ADD COLUMN IF NOT EXISTS customer_phone TEXT,
ADD COLUMN IF NOT EXISTS customer_address TEXT,
ADD COLUMN IF NOT EXISTS customer_email TEXT;

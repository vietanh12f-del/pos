-- Migration to add payment status to orders table
-- Run this in Supabase SQL Editor

ALTER TABLE orders 
ADD COLUMN is_paid BOOLEAN DEFAULT TRUE;

-- Update existing orders to be paid (optional, but good for consistency)
UPDATE orders SET is_paid = TRUE WHERE is_paid IS NULL;

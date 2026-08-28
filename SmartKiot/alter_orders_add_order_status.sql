-- Add order_status field to orders table
-- Values: 'prepared' | 'delivered' | 'completed' | 'cancelled'
-- Run this in Supabase SQL Editor

ALTER TABLE orders
ADD COLUMN IF NOT EXISTS order_status TEXT;

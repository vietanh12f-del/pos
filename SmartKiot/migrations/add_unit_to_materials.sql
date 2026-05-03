-- Migration to add unit column to materials and production_transaction_items
-- Run this in your Supabase SQL Editor

-- Add unit column to materials table
ALTER TABLE materials ADD COLUMN IF NOT EXISTS unit TEXT;

-- Add unit column to production_transaction_items table
ALTER TABLE production_transaction_items ADD COLUMN IF NOT EXISTS unit TEXT;

-- Update existing materials to 'kg' if they don't have a unit (optional)
-- UPDATE materials SET unit = 'kg' WHERE unit IS NULL;

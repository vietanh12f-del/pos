-- Add creator_id and creator_name columns to orders table
ALTER TABLE orders ADD COLUMN IF NOT EXISTS creator_id UUID;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS creator_name TEXT;

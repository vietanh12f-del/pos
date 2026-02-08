-- Fix for "Giá vốn" (Cost Price) resetting issue
-- The bug occurs because the 'cost_price' column is missing in the database table.
-- Running this script will add the missing column and ensure data persists.

-- 1. Add cost_price to products table
ALTER TABLE public.products 
ADD COLUMN IF NOT EXISTS cost_price DOUBLE PRECISION DEFAULT 0;

-- 2. Add cost_price to order_items table (for historical accuracy)
ALTER TABLE public.order_items 
ADD COLUMN IF NOT EXISTS cost_price DOUBLE PRECISION DEFAULT 0;

-- 3. Optional: Initialize cost_price from price if needed (conservative estimate, usually 0 is safer)
-- UPDATE products SET cost_price = 0 WHERE cost_price IS NULL;

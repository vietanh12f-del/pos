-- Migration to add 'cost_price' column to 'products' table
-- This allows tracking the Cost of Goods Sold (COGS) for each product.

ALTER TABLE products 
ADD COLUMN IF NOT EXISTS cost_price NUMERIC DEFAULT 0;

-- Optional: Update existing records to have a default cost price if needed
-- UPDATE products SET cost_price = 0 WHERE cost_price IS NULL;

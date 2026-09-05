-- Add isHidden column to products table
-- This allows hiding products from order creation while keeping them visible in inventory

ALTER TABLE products 
ADD COLUMN IF NOT EXISTS is_hidden BOOLEAN DEFAULT FALSE;

-- Create index for better performance when filtering hidden products
CREATE INDEX IF NOT EXISTS idx_products_is_hidden ON products(is_hidden);

-- Comment for documentation
COMMENT ON COLUMN products.is_hidden IS 'Hide product from order creation but keep in inventory view';
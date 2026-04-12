-- Add decimal kilograms column to products to support fractional weights
ALTER TABLE IF EXISTS products
  ADD COLUMN IF NOT EXISTS stock_weight_kg DOUBLE PRECISION DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_products_stock_weight_kg ON products(stock_weight_kg);

NOTIFY pgrst, 'reload schema';

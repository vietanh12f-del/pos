-- Add is_finished_good flag to distinguish finished goods from normal goods
ALTER TABLE IF EXISTS products
  ADD COLUMN IF NOT EXISTS is_finished_good BOOLEAN DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_products_is_finished_good ON products(is_finished_good);

NOTIFY pgrst, 'reload schema';

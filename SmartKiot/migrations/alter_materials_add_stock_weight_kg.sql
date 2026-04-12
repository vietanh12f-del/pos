-- Add decimal kilograms column to materials to support fractional weights
ALTER TABLE IF EXISTS materials
  ADD COLUMN IF NOT EXISTS stock_weight_kg DOUBLE PRECISION DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_materials_stock_weight_kg ON materials(stock_weight_kg);

NOTIFY pgrst, 'reload schema';

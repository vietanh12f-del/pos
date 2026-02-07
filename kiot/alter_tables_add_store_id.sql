-- Add store_id to business tables to support multi-store data isolation
-- Run in Supabase SQL Editor

ALTER TABLE products ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
CREATE INDEX IF NOT EXISTS idx_products_store_id ON products(store_id);

ALTER TABLE orders ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
CREATE INDEX IF NOT EXISTS idx_orders_store_id ON orders(store_id);

ALTER TABLE restock_bills ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
CREATE INDEX IF NOT EXISTS idx_restock_bills_store_id ON restock_bills(store_id);

ALTER TABLE operating_expenses ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
CREATE INDEX IF NOT EXISTS idx_operating_expenses_store_id ON operating_expenses(store_id);

-- Optional: price history per store (comment out if global desired)
-- ALTER TABLE price_history ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
-- CREATE INDEX IF NOT EXISTS idx_price_history_store_id ON price_history(store_id);

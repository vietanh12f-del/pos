-- Materials Schema
-- Run in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS materials (
  id UUID PRIMARY KEY,
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  stock_quantity INT NOT NULL DEFAULT 0,
  last_unit_price DOUBLE PRECISION DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_materials_store_id ON materials(store_id);
CREATE INDEX IF NOT EXISTS idx_materials_name ON materials(name);

ALTER TABLE materials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Access materials if member" ON materials;
CREATE POLICY "Access materials if member" ON materials
  FOR ALL
  USING (
    store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
  );

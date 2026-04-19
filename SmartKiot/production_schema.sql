-- Production Management Schema
-- Run this in Supabase SQL Editor

-- Header table for production transactions
CREATE TABLE IF NOT EXISTS production_transactions (
  id UUID PRIMARY KEY,
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  mode TEXT NOT NULL, -- 'Nhập nguyên liệu' | 'Xuất nguyên liệu' | 'Nhập thành phẩm' | 'Xuất thành phẩm'
  total_cost DOUBLE PRECISION DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  creator_id UUID,
  creator_name TEXT,
  note TEXT
);

CREATE INDEX IF NOT EXISTS idx_production_transactions_store_id ON production_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_production_transactions_mode ON production_transactions(mode);
CREATE INDEX IF NOT EXISTS idx_production_transactions_created_at ON production_transactions(created_at);

-- Item table
CREATE TABLE IF NOT EXISTS production_transaction_items (
  id UUID PRIMARY KEY,
  transaction_id UUID REFERENCES production_transactions(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  quantity INT NOT NULL,
  unit_price DOUBLE PRECISION DEFAULT 0,
  additional_cost DOUBLE PRECISION DEFAULT 0,
  source TEXT,
  document_image_url TEXT
);

CREATE INDEX IF NOT EXISTS idx_production_items_tx_id ON production_transaction_items(transaction_id);

-- Migration-safe: ensure column exists on older deployments
ALTER TABLE production_transaction_items
  ADD COLUMN IF NOT EXISTS additional_cost DOUBLE PRECISION DEFAULT 0;
ALTER TABLE production_transaction_items
  ADD COLUMN IF NOT EXISTS source TEXT;
ALTER TABLE production_transaction_items
  ADD COLUMN IF NOT EXISTS document_image_url TEXT;

-- Enable RLS
ALTER TABLE production_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_transaction_items ENABLE ROW LEVEL SECURITY;

-- Migration-safe: ensure header note exists on older deployments
ALTER TABLE production_transactions
  ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE production_transactions
  ADD COLUMN IF NOT EXISTS creator_id UUID;
ALTER TABLE production_transactions
  ADD COLUMN IF NOT EXISTS creator_name TEXT;

-- Policies: Access transactions if user is a member of the store
DROP POLICY IF EXISTS "Access production transactions if member" ON production_transactions;
CREATE POLICY "Access production transactions if member" ON production_transactions
  FOR ALL
  USING (
    store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
  );

-- Access items via parent transaction membership
DROP POLICY IF EXISTS "Access production items via transaction" ON production_transaction_items;
CREATE POLICY "Access production items via transaction" ON production_transaction_items
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM production_transactions pt
      WHERE pt.id = production_transaction_items.transaction_id
      AND pt.store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    )
  );

-- Edit history table for production transactions (analogous to order_edits)
CREATE TABLE IF NOT EXISTS production_edits (
  id UUID PRIMARY KEY,
  transaction_id UUID NOT NULL REFERENCES production_transactions(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  old_total DOUBLE PRECISION NOT NULL,
  new_total DOUBLE PRECISION NOT NULL,
  editor_id UUID REFERENCES profiles(id),
  editor_name TEXT,
  store_id UUID REFERENCES stores(id),
  note TEXT,
  details JSONB
);

CREATE INDEX IF NOT EXISTS idx_production_edits_tx_id ON production_edits(transaction_id);
CREATE INDEX IF NOT EXISTS idx_production_edits_created_at ON production_edits(created_at DESC);

ALTER TABLE production_edits ENABLE ROW LEVEL SECURITY;

-- Policies: store members or editor can read/insert
DROP POLICY IF EXISTS "Store members can read production edits" ON production_edits;
CREATE POLICY "Store members can read production edits"
ON production_edits FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = production_edits.store_id
      AND m.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Store members can insert production edits" ON production_edits;
CREATE POLICY "Store members can insert production edits"
ON production_edits FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM store_members m
    WHERE m.store_id = production_edits.store_id
      AND m.user_id = auth.uid()
  )
);

-- Relaxed policies: allow editor to read/insert their own edits
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'production_edits'
      AND policyname = 'Production edits insert by editor'
  ) THEN
    CREATE POLICY "Production edits insert by editor"
    ON production_edits FOR INSERT
    WITH CHECK (editor_id = auth.uid());
  END IF;
  
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'production_edits'
      AND policyname = 'Production edits select by editor'
  ) THEN
    CREATE POLICY "Production edits select by editor"
    ON production_edits FOR SELECT
    USING (editor_id = auth.uid());
  END IF;
END $$;

-- =================================================================
-- Fix 'materials' table: add missing 'category' column for Supabase cache
-- =================================================================
ALTER TABLE IF EXISTS materials
  ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Vật liệu';

CREATE INDEX IF NOT EXISTS idx_materials_category ON materials(category);

-- Refresh PostgREST schema cache so the 'category' column is recognized
NOTIFY pgrst, 'reload config';

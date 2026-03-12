-- Production Management Schema
-- Run this in Supabase SQL Editor

-- Header table for production transactions
CREATE TABLE IF NOT EXISTS production_transactions (
  id UUID PRIMARY KEY,
  store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
  mode TEXT NOT NULL, -- 'Nhập nguyên liệu' | 'Xuất nguyên liệu' | 'Nhập thành phẩm' | 'Xuất thành phẩm'
  total_cost DOUBLE PRECISION DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
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
  unit_price DOUBLE PRECISION DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_production_items_tx_id ON production_transaction_items(transaction_id);

-- Enable RLS
ALTER TABLE production_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_transaction_items ENABLE ROW LEVEL SECURITY;

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

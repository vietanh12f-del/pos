-- ============================================================
-- Migration: Add export buyer info & payment fields
-- to production_transactions table
-- Run this in Supabase SQL Editor
-- ============================================================

-- Buyer info
ALTER TABLE production_transactions
  ADD COLUMN IF NOT EXISTS buyer_name TEXT,
  ADD COLUMN IF NOT EXISTS buyer_phone TEXT,
  ADD COLUMN IF NOT EXISTS buyer_address TEXT;

-- Payment info
ALTER TABLE production_transactions
  ADD COLUMN IF NOT EXISTS grand_total DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS paid_amount DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS debt_amount DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vat_rate DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vat_amount DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_paid BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS expected_pay_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS payment_receipt_url TEXT;

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_production_transactions_buyer_phone
  ON production_transactions(buyer_phone);

CREATE INDEX IF NOT EXISTS idx_production_transactions_is_paid
  ON production_transactions(is_paid);

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

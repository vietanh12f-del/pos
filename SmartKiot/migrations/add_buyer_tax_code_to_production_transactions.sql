-- ============================================================
-- Migration: Add buyer_tax_code to production_transactions
-- ============================================================

-- Add buyer_tax_code column if not exists
ALTER TABLE production_transactions
ADD COLUMN IF NOT EXISTS buyer_tax_code TEXT;

-- Create index for buyer_tax_code lookups
CREATE INDEX IF NOT EXISTS idx_production_transactions_buyer_tax_code ON production_transactions(buyer_tax_code);

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

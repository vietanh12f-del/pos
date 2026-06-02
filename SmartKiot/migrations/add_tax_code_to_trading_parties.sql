-- ============================================================
-- Migration: Add tax_code to trading_parties table
-- ============================================================

-- Add tax_code column if not exists
ALTER TABLE trading_parties
ADD COLUMN IF NOT EXISTS tax_code TEXT;

-- Create index for tax_code lookups
CREATE INDEX IF NOT EXISTS idx_trading_parties_tax_code ON trading_parties(tax_code);

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

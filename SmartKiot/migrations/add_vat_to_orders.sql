-- ============================================================
-- Migration: Add VAT fields (vat_rate and vat_amount) to orders table
-- Run this in Supabase SQL Editor
-- ============================================================

-- Add VAT columns to orders table
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS vat_rate DOUBLE PRECISION DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vat_amount DOUBLE PRECISION DEFAULT 0;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

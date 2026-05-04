-- ============================================================
-- Migration: Add image_urls column to trading_parties
-- Run this in Supabase SQL Editor
-- ============================================================

ALTER TABLE trading_parties
  ADD COLUMN IF NOT EXISTS image_urls TEXT[] DEFAULT '{}';

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

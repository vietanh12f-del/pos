-- ============================================================
-- Add customer info fields to trading_parties table
-- ============================================================

ALTER TABLE trading_parties 
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS birthday DATE,
ADD COLUMN IF NOT EXISTS customer_category TEXT DEFAULT 'buyer',
ADD COLUMN IF NOT EXISTS disease_description TEXT,
ADD COLUMN IF NOT EXISTS patient_note TEXT,
ADD COLUMN IF NOT EXISTS treatment_name TEXT,
ADD COLUMN IF NOT EXISTS treatment_sessions JSONB DEFAULT '[]'::jsonb;

-- Migration to add supplier columns to production_transactions
-- For tracking material import supplier info (Cơ sở nhập)

-- Add supplier columns
ALTER TABLE production_transactions 
  ADD COLUMN IF NOT EXISTS supplier_name TEXT,
  ADD COLUMN IF NOT EXISTS supplier_phone TEXT,
  ADD COLUMN IF NOT EXISTS supplier_address TEXT;

-- Create index for faster filtering by supplier
CREATE INDEX IF NOT EXISTS idx_production_transactions_supplier_name 
  ON production_transactions(supplier_name);

-- Update existing material import transactions to copy buyer_name to supplier_name
-- This ensures the filter works correctly for old data
-- Handle case-insensitive and empty strings
UPDATE production_transactions 
SET supplier_name = buyer_name,
    supplier_phone = buyer_phone,
    supplier_address = buyer_address
WHERE LOWER(mode) = 'nhập nguyên liệu'
  AND (supplier_name IS NULL OR supplier_name = '')
  AND (buyer_name IS NOT NULL AND buyer_name != '');

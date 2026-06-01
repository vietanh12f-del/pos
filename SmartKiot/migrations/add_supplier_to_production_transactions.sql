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

-- Update existing material import transactions to set supplier_name from note or other sources if available
-- This is optional and depends on your data
-- UPDATE production_transactions 
-- SET supplier_name = creator_name 
-- WHERE mode = 'Nhập nguyên liệu' AND supplier_name IS NULL;

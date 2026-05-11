ALTER TABLE restock_bills ADD COLUMN IF NOT EXISTS supplier_name TEXT;
ALTER TABLE restock_bills ADD COLUMN IF NOT EXISTS supplier_phone TEXT;
ALTER TABLE restock_bills ADD COLUMN IF NOT EXISTS supplier_address TEXT;

-- Thêm các cột supplier vào bảng restock_bills
ALTER TABLE restock_bills 
ADD COLUMN IF NOT EXISTS supplier_name TEXT,
ADD COLUMN IF NOT EXISTS supplier_phone TEXT,
ADD COLUMN IF NOT EXISTS supplier_address TEXT;

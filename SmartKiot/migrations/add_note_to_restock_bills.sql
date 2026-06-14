-- Thêm cột note vào bảng restock_bills
ALTER TABLE restock_bills 
ADD COLUMN IF NOT EXISTS note TEXT;
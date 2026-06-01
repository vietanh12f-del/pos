-- Migration to add category column to production_transaction_items
-- This fixes the x1000 calculation error for material costs

-- Add category column to production_transaction_items table
ALTER TABLE production_transaction_items ADD COLUMN IF NOT EXISTS category TEXT;

-- For existing material import/export transactions, set category to 'Vật liệu'
-- based on the parent transaction's mode (must match Category.materials.rawValue)
UPDATE production_transaction_items 
SET category = 'Vật liệu'
WHERE category IS NULL 
AND transaction_id IN (
    SELECT id FROM production_transactions 
    WHERE mode IN ('Nhập nguyên liệu', 'Xuất nguyên liệu')
);

-- For existing finished good export transactions, set category to 'Thành phẩm'
UPDATE production_transaction_items 
SET category = 'Thành phẩm'
WHERE category IS NULL 
AND transaction_id IN (
    SELECT id FROM production_transactions 
    WHERE mode = 'Xuất thành phẩm'
);

-- Also update any with wrong/empty category values
UPDATE production_transaction_items 
SET category = 'Vật liệu'
WHERE category IS NULL OR category = '' OR category = 'materials'
AND transaction_id IN (
    SELECT id FROM production_transactions 
    WHERE mode IN ('Nhập nguyên liệu', 'Xuất nguyên liệu')
);

-- Migration: thêm cột has_vat vào bảng products
-- Mặc định false cho các sản phẩm cũ

ALTER TABLE products
ADD COLUMN IF NOT EXISTS has_vat BOOLEAN NOT NULL DEFAULT FALSE;

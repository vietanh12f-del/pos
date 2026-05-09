-- Migration: thêm cột has_vat vào bảng restock_items
-- Mặc định false (không có VAT) cho các bản ghi cũ

ALTER TABLE restock_items
ADD COLUMN IF NOT EXISTS has_vat BOOLEAN NOT NULL DEFAULT FALSE;

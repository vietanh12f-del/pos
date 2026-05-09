-- Migration: thêm cột has_vat vào bảng materials
-- Mặc định false cho các nguyên liệu cũ

ALTER TABLE materials
ADD COLUMN IF NOT EXISTS has_vat BOOLEAN NOT NULL DEFAULT FALSE;

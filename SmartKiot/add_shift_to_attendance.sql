-- ============================================================
-- Migration: Add shift column to attendance_records
-- Cho phép điểm danh nhiều ca trong ngày
-- Run this in Supabase SQL Editor
-- ============================================================

-- Thêm column shift (số thứ tự ca: 1, 2, 3...)
ALTER TABLE attendance_records
    ADD COLUMN IF NOT EXISTS shift INTEGER NOT NULL DEFAULT 1;

-- Xóa unique constraint cũ (chỉ theo user+date)
DROP INDEX IF EXISTS idx_attendance_user_date;

-- Tạo unique constraint mới (user + date + shift)
CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_user_date_shift
    ON attendance_records(store_id, user_id, date, shift);

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

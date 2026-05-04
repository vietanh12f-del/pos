-- ============================================================
-- Migration: Create attendance_records table
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS attendance_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_name TEXT NOT NULL,
    date DATE NOT NULL,                          -- ngày điểm danh (YYYY-MM-DD)
    check_in_time TIMESTAMPTZ,
    check_out_time TIMESTAMPTZ,
    check_in_selfie_url TEXT,
    check_out_selfie_url TEXT,
    note TEXT,
    status TEXT NOT NULL DEFAULT 'checked_in',  -- 'checked_in' | 'checked_out' | 'late'
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Unique: mỗi user chỉ có 1 record/ngày/store
CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_user_date
    ON attendance_records(store_id, user_id, date);

CREATE INDEX IF NOT EXISTS idx_attendance_store_date
    ON attendance_records(store_id, date);

CREATE INDEX IF NOT EXISTS idx_attendance_user_id
    ON attendance_records(user_id);

-- RLS
ALTER TABLE attendance_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can access attendance" ON attendance_records;
CREATE POLICY "Store members can access attendance" ON attendance_records
    FOR ALL
    USING (
        store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    );

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

-- ============================================================
-- Migration: Create leave_requests table
-- Nhân viên đăng ký nghỉ trước
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS leave_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_name TEXT NOT NULL,
    leave_date DATE NOT NULL,           -- ngày xin nghỉ
    leave_type TEXT NOT NULL DEFAULT 'personal', -- 'personal' | 'sick' | 'annual' | 'other'
    reason TEXT,
    status TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'approved' | 'rejected'
    reviewed_by UUID,                   -- id chủ cửa hàng duyệt
    reviewed_at TIMESTAMPTZ,
    review_note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_leave_requests_store_user
    ON leave_requests(store_id, user_id);

CREATE INDEX IF NOT EXISTS idx_leave_requests_date
    ON leave_requests(store_id, leave_date);

-- RLS
ALTER TABLE leave_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can access leave requests" ON leave_requests;
CREATE POLICY "Store members can access leave requests" ON leave_requests
    FOR ALL
    USING (
        store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    );

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

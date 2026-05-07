-- ============================================================
-- Migration: Create sequence_counters table
-- Lưu số thứ tự tăng dần cho từng loại phiếu
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS sequence_counters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    counter_type TEXT NOT NULL,  -- 'XBL' | 'NBL' | 'NNL' | 'XNL' | 'NTP' | 'XTP' | ...
    current_value BIGINT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(store_id, counter_type)
);

-- Index
CREATE INDEX IF NOT EXISTS idx_sequence_counters_store_type
    ON sequence_counters(store_id, counter_type);

-- RLS
ALTER TABLE sequence_counters ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can access sequence counters" ON sequence_counters;
CREATE POLICY "Store members can access sequence counters" ON sequence_counters
    FOR ALL
    USING (
        store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    );

-- Hàm atomic increment — trả về giá trị MỚI sau khi tăng
CREATE OR REPLACE FUNCTION increment_sequence_counter(
    p_store_id UUID,
    p_type TEXT
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_new_value BIGINT;
BEGIN
    INSERT INTO sequence_counters (store_id, counter_type, current_value, updated_at)
    VALUES (p_store_id, p_type, 1, NOW())
    ON CONFLICT (store_id, counter_type)
    DO UPDATE SET
        current_value = sequence_counters.current_value + 1,
        updated_at = NOW()
    RETURNING current_value INTO v_new_value;
    RETURN v_new_value;
END;
$$;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

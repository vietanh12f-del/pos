-- ============================================================
-- Migration: Create trading_parties table
-- Stores buyer (bên mua) and supplier (cơ sở cung cấp) info
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS trading_parties (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    party_type TEXT NOT NULL DEFAULT 'buyer', -- 'buyer' | 'supplier'
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    total_debt DOUBLE PRECISION DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trading_parties_store_id ON trading_parties(store_id);
CREATE INDEX IF NOT EXISTS idx_trading_parties_type ON trading_parties(party_type);
CREATE INDEX IF NOT EXISTS idx_trading_parties_name ON trading_parties(name);

-- RLS
ALTER TABLE trading_parties ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Store members can access trading parties" ON trading_parties;
CREATE POLICY "Store members can access trading parties" ON trading_parties
    FOR ALL
    USING (
        store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    );

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

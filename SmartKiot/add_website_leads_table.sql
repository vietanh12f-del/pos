-- ============================================================
-- Migration: Create website_leads table
-- Stores consultation requests and appointment bookings from website
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS website_leads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    lead_type TEXT NOT NULL DEFAULT 'consultation', -- 'consultation' | 'appointment'

    -- Common fields
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    service_type TEXT,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'new', -- 'new' | 'contacted' | 'done' | 'cancelled'

    -- Appointment-only fields
    booking_date DATE,
    time_slot TEXT,
    email TEXT,
    branch TEXT,

    -- Metadata
    source TEXT DEFAULT 'website'
);

CREATE INDEX IF NOT EXISTS idx_website_leads_store_id ON website_leads(store_id);
CREATE INDEX IF NOT EXISTS idx_website_leads_lead_type ON website_leads(lead_type);
CREATE INDEX IF NOT EXISTS idx_website_leads_created_at ON website_leads(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_website_leads_phone ON website_leads(phone);
CREATE INDEX IF NOT EXISTS idx_website_leads_status ON website_leads(status);

-- RLS: Allow public insert (from website), restrict read to store members
ALTER TABLE website_leads ENABLE ROW LEVEL SECURITY;

-- Anyone can insert (website form submissions - no auth required)
DROP POLICY IF EXISTS "Public can insert website leads" ON website_leads;
CREATE POLICY "Public can insert website leads" ON website_leads
    FOR INSERT
    WITH CHECK (true);

-- Only store members can read
DROP POLICY IF EXISTS "Store members can read website leads" ON website_leads;
CREATE POLICY "Store members can read website leads" ON website_leads
    FOR SELECT
    USING (
        store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    );

-- Store members can update status
DROP POLICY IF EXISTS "Store members can update website leads" ON website_leads;
CREATE POLICY "Store members can update website leads" ON website_leads
    FOR UPDATE
    USING (
        store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    );

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload config';

-- ============================================================
-- Fix: Allow store members to update leads with NULL store_id
-- Run this if leads from website (store_id = NULL) cannot be updated
-- ============================================================

DROP POLICY IF EXISTS "Store members can update website leads" ON website_leads;
CREATE POLICY "Store members can update website leads" ON website_leads
    FOR UPDATE
    USING (
        store_id IS NULL
        OR store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    );

-- Also fix SELECT policy for NULL store_id leads
DROP POLICY IF EXISTS "Store members can read website leads" ON website_leads;
CREATE POLICY "Store members can read website leads" ON website_leads
    FOR SELECT
    USING (
        store_id IS NULL
        OR store_id IN (SELECT store_id FROM store_members WHERE user_id = auth.uid())
    );

NOTIFY pgrst, 'reload config';

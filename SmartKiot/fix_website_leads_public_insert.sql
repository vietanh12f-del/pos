-- ============================================================
-- FIX: Restore Public Insert Policy for website_leads
-- ============================================================

-- 1. Drop existing policies if any
DROP POLICY IF EXISTS "Secure Website Leads Policy" ON website_leads;
DROP POLICY IF EXISTS "Public can insert website leads" ON website_leads;
DROP POLICY IF EXISTS "Store members can read website leads" ON website_leads;
DROP POLICY IF EXISTS "Store members can update website leads" ON website_leads;

-- 2. Recreate all necessary policies
CREATE POLICY "Public can insert website leads" ON website_leads
    FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Store members can read website leads" ON website_leads
    FOR SELECT
    USING (
        store_id IS NULL
        OR EXISTS (SELECT 1 FROM store_members WHERE store_id = website_leads.store_id AND user_id = auth.uid())
        OR EXISTS (SELECT 1 FROM stores WHERE id = website_leads.store_id AND owner_id = auth.uid())
    );

CREATE POLICY "Store members can update website leads" ON website_leads
    FOR UPDATE
    USING (
        store_id IS NULL
        OR EXISTS (SELECT 1 FROM store_members WHERE store_id = website_leads.store_id AND user_id = auth.uid())
        OR EXISTS (SELECT 1 FROM stores WHERE id = website_leads.store_id AND owner_id = auth.uid())
    );

-- 3. Check and add website_leads to realtime publication if not already there
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'website_leads'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE website_leads;
    END IF;
END
$$;

-- 4. Reload PostgREST schema cache
NOTIFY pgrst, 'reload config';

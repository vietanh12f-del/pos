-- =============================================
-- COMPREHENSIVE RLS FIX - SAFE TO RUN MULTIPLE TIMES
-- Drop ALL existing policies first, then recreate everything
-- =============================================

-- =============================================
-- STEP 1: HELPER FUNCTION (Create if not exists)
-- =============================================
CREATE OR REPLACE FUNCTION public.check_is_member_or_owner(lookup_store_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check if user is a member
  IF EXISTS (
    SELECT 1 FROM store_members
    WHERE store_id = lookup_store_id
    AND user_id = auth.uid()
  ) THEN
    RETURN TRUE;
  END IF;

  -- Check if user is the owner (fallback if not in store_members)
  IF EXISTS (
    SELECT 1 FROM stores
    WHERE id = lookup_store_id
    AND owner_id = auth.uid()
  ) THEN
    RETURN TRUE;
  END IF;

  RETURN FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_is_member_or_owner(UUID) TO authenticated;

-- =============================================
-- STEP 2: DROP ALL EXISTING POLICIES FOR ALL TABLES
-- =============================================
DO $$
DECLARE
    r RECORD;
BEGIN
    -- Drop policies for all tables in public schema
    FOR r IN 
        SELECT tablename, policyname 
        FROM pg_policies 
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, r.tablename);
        RAISE NOTICE 'Dropped policy: % on table: %', r.policyname, r.tablename;
    END LOOP;
END $$;

-- =============================================
-- STEP 3: ENABLE RLS ON ALL TABLES
-- =============================================
ALTER TABLE IF EXISTS products ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS restock_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS restock_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS price_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS operating_expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS store_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS trading_parties ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS website_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS leave_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS order_edits ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS restock_edits ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS production_edits ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS production_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS production_transaction_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS auto_material_export_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS auto_material_export_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS user_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS sequence_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS device_tokens ENABLE ROW LEVEL SECURITY;

-- =============================================
-- STEP 4: CREATE NEW SECURE POLICIES
-- =============================================

-- 1. PRODUCTS
CREATE POLICY "Secure Products Policy" ON products
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 2. ORDERS
CREATE POLICY "Secure Orders Policy" ON orders
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 3. ORDER ITEMS
CREATE POLICY "Secure Order Items Policy" ON order_items
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 4. RESTOCK BILLS
CREATE POLICY "Secure Restock Bills Policy" ON restock_bills
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 5. RESTOCK ITEMS
CREATE POLICY "Secure Restock Items Policy" ON restock_items
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM restock_bills 
            WHERE restock_bills.id = restock_items.bill_id
            AND check_is_member_or_owner(restock_bills.store_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM restock_bills 
            WHERE restock_bills.id = restock_items.bill_id
            AND check_is_member_or_owner(restock_bills.store_id)
        )
    );

-- 6. OPERATING EXPENSES
CREATE POLICY "Secure Expenses Policy" ON operating_expenses
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 7. PROFILES
CREATE POLICY "Users can view all profiles" ON profiles
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- 8. MESSAGES
CREATE POLICY "Users can view their messages" ON messages
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);

CREATE POLICY "Users can send messages" ON messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- 9. STORES
CREATE POLICY "Secure Stores Policy" ON stores
    FOR ALL
    USING (check_is_member_or_owner(id))
    WITH CHECK (check_is_member_or_owner(id));

-- 10. STORE MEMBERS
CREATE POLICY "Secure Store Members Policy" ON store_members
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 11. CATEGORIES
CREATE POLICY "Secure Categories Policy" ON categories
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 12. TRADING PARTIES
CREATE POLICY "Secure Trading Parties Policy" ON trading_parties
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 13. WEBSITE LEADS
CREATE POLICY "Secure Website Leads Policy" ON website_leads
    FOR ALL
    USING (check_is_member_or_owner(store_id) OR store_id IS NULL)
    WITH CHECK (check_is_member_or_owner(store_id) OR store_id IS NULL);

-- 14. ATTENDANCE RECORDS
CREATE POLICY "Secure Attendance Policy" ON attendance_records
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 15. LEAVE REQUESTS
CREATE POLICY "Secure Leave Requests Policy" ON leave_requests
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 16. ORDER EDITS
CREATE POLICY "Secure Order Edits Policy" ON order_edits
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 17. RESTOCK EDITS
CREATE POLICY "Secure Restock Edits Policy" ON restock_edits
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 18. PRODUCTION EDITS
CREATE POLICY "Secure Production Edits Policy" ON production_edits
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 19. PRODUCTION TRANSACTIONS
CREATE POLICY "Secure Production Transactions Policy" ON production_transactions
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 20. PRODUCTION TRANSACTION ITEMS
CREATE POLICY "Secure Production Items Policy" ON production_transaction_items
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM production_transactions 
            WHERE production_transactions.id = production_transaction_items.transaction_id
            AND check_is_member_or_owner(production_transactions.store_id)
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM production_transactions 
            WHERE production_transactions.id = production_transaction_items.transaction_id
            AND check_is_member_or_owner(production_transactions.store_id)
        )
    );

-- 21. MATERIALS
CREATE POLICY "Secure Materials Policy" ON materials
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 22. AUTO MATERIAL EXPORT TEMPLATES
CREATE POLICY "Secure Auto Export Templates Policy" ON auto_material_export_templates
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 23. AUTO MATERIAL EXPORT LOGS
CREATE POLICY "Secure Auto Export Logs Policy" ON auto_material_export_logs
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 24. USER FEEDBACK
CREATE POLICY "Secure User Feedback Policy" ON user_feedback
    FOR ALL
    USING (auth.uid() = user_id OR check_is_member_or_owner(store_id))
    WITH CHECK (auth.uid() = user_id OR check_is_member_or_owner(store_id));

-- 25. SEQUENCE COUNTERS
CREATE POLICY "Secure Sequence Counters Policy" ON sequence_counters
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 26. DEVICE TOKENS
CREATE POLICY "Secure Device Tokens Policy" ON device_tokens
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 27. PRICE HISTORY (if you want it per-store, add store_id column first)
-- For now, allow authenticated users (adjust if needed)
CREATE POLICY "Price History Policy" ON price_history
    FOR ALL
    USING (auth.role() = 'authenticated')
    WITH CHECK (auth.role() = 'authenticated');

-- =============================================
-- STEP 5: SELF-HEALING - ENSURE OWNERS ARE IN STORE_MEMBERS
-- =============================================
INSERT INTO store_members (store_id, user_id, role, status)
SELECT id, owner_id, 'owner', 'active'
FROM stores
WHERE NOT EXISTS (
    SELECT 1 FROM store_members 
    WHERE store_members.store_id = stores.id 
    AND store_members.user_id = stores.owner_id
);

-- =============================================
-- FINISHED!
-- =============================================
-- ✅ All RLS policies have been reset and recreated successfully!
-- Verify by running:
-- SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename;

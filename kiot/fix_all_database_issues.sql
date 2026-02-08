-- FIX ALL DATABASE ISSUES (Run this in Supabase SQL Editor)

-- 1. FIX OPERATING EXPENSES (Chi phí)
-- Ensure store_id column exists
ALTER TABLE operating_expenses 
ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE CASCADE;

-- Backfill store_id for old expenses (Assign to the first found store to prevent data loss)
DO $$
DECLARE
    first_store_id UUID;
BEGIN
    SELECT id INTO first_store_id FROM stores LIMIT 1;
    IF first_store_id IS NOT NULL THEN
        UPDATE operating_expenses SET store_id = first_store_id WHERE store_id IS NULL;
    END IF;
END $$;

-- Enable RLS and Add Policy for Expenses
ALTER TABLE operating_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Manage expenses based on store membership" ON operating_expenses;
CREATE POLICY "Manage expenses based on store membership" ON operating_expenses
    FOR ALL
    USING (
        store_id IN (
            SELECT store_id FROM store_members WHERE user_id = auth.uid()
        )
    );

-- 2. FIX ORDER ITEMS (No Items Issue)
-- Enable RLS on order_items
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Policy: Allow access if user has access to the parent order
DROP POLICY IF EXISTS "Access order items via order" ON order_items;
CREATE POLICY "Access order items via order" ON order_items
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM orders
            WHERE orders.id = order_items.order_id
            AND orders.store_id IN (
                SELECT store_id FROM store_members WHERE user_id = auth.uid()
            )
        )
    );

-- 3. FIX ORDERS (Just in case)
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Manage orders based on store membership" ON orders;
CREATE POLICY "Manage orders based on store membership" ON orders
    FOR ALL
    USING (
        store_id IN (
            SELECT store_id FROM store_members WHERE user_id = auth.uid()
        )
    );

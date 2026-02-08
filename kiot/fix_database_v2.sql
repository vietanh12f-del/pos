-- FIX DATABASE V2: ROBUST FIX FOR EXPENSES AND ORDERS
-- Run this in Supabase SQL Editor

-- =================================================================
-- 1. FIX OPERATING EXPENSES (Chi phí)
-- =================================================================

-- Ensure store_id column exists
ALTER TABLE operating_expenses 
ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE CASCADE;

-- Backfill store_id for old expenses if missing
-- Strategy: Assign to the first store the user is a member of, or just the first store found.
DO $$
DECLARE
    default_store_id UUID;
BEGIN
    -- Try to find a store
    SELECT id INTO default_store_id FROM stores LIMIT 1;
    
    IF default_store_id IS NOT NULL THEN
        UPDATE operating_expenses SET store_id = default_store_id WHERE store_id IS NULL;
    END IF;
END $$;

-- Enable RLS
ALTER TABLE operating_expenses ENABLE ROW LEVEL SECURITY;

-- Drop old policies to be safe
DROP POLICY IF EXISTS "Manage expenses based on store membership" ON operating_expenses;
DROP POLICY IF EXISTS "Owners and Managers can manage expenses" ON operating_expenses;
DROP POLICY IF EXISTS "Employees can view expenses with permission" ON operating_expenses;

-- Create a SINGLE, SIMPLE policy for testing and production
-- Allows access if the user is a member of the store referenced by store_id
CREATE POLICY "Access expenses if member" ON operating_expenses
    FOR ALL
    USING (
        store_id IN (
            SELECT store_id FROM store_members WHERE user_id = auth.uid()
        )
    );

-- =================================================================
-- 2. FIX ORDER ITEMS (No Items Issue) - Denormalization Strategy
-- =================================================================

-- Add store_id to order_items to avoid complex joins in RLS
ALTER TABLE order_items 
ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE CASCADE;

-- Backfill store_id from parent orders
UPDATE order_items 
SET store_id = orders.store_id 
FROM orders 
WHERE order_items.order_id = orders.id 
AND order_items.store_id IS NULL;

-- Enable RLS
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Access order items via order" ON order_items;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON order_items;

-- Create SIMPLE policy using the new store_id column
CREATE POLICY "Access order items if member" ON order_items
    FOR ALL
    USING (
        store_id IN (
            SELECT store_id FROM store_members WHERE user_id = auth.uid()
        )
    );

-- =================================================================
-- 3. FIX STORE MEMBERS (Ensure visibility)
-- =================================================================

-- Ensure users can see their own memberships (critical for the subqueries above)
ALTER TABLE store_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their memberships" ON store_members;
CREATE POLICY "Users can view their memberships" ON store_members
    FOR SELECT
    USING (auth.uid() = user_id);

-- =================================================================
-- 4. FIX ORDERS (Just in case)
-- =================================================================
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Manage orders based on store membership" ON orders;
CREATE POLICY "Manage orders based on store membership" ON orders
    FOR ALL
    USING (
        store_id IN (
            SELECT store_id FROM store_members WHERE user_id = auth.uid()
        )
    );

-- =================================================================
-- 5. REFRESH SCHEMA CACHE
-- =================================================================
NOTIFY pgrst, 'reload config';

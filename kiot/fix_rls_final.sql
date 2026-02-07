-- FIX RLS FINAL: COMPREHENSIVE FIX FOR PERMISSION ISSUES
-- Run this in Supabase SQL Editor

-- 1. Helper Function: Check if user is Member OR Owner
-- This uses SECURITY DEFINER to bypass RLS recursion and ensure access
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

-- 2. FIX OPERATING EXPENSES (Chi phí)
ALTER TABLE operating_expenses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Access expenses if member" ON operating_expenses;
DROP POLICY IF EXISTS "Manage expenses based on store membership" ON operating_expenses;
DROP POLICY IF EXISTS "Owners and Managers can manage expenses" ON operating_expenses;
DROP POLICY IF EXISTS "Employees can view expenses with permission" ON operating_expenses;

-- Single robust policy for ALL operations (Select, Insert, Update, Delete)
CREATE POLICY "Unified Expense Policy" ON operating_expenses
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 3. FIX ORDER ITEMS (Products in Order)
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Access order items if member" ON order_items;
DROP POLICY IF EXISTS "Access order items via order" ON order_items;

CREATE POLICY "Unified Order Items Policy" ON order_items
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 4. FIX ORDERS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Manage orders based on store membership" ON orders;

CREATE POLICY "Unified Orders Policy" ON orders
    FOR ALL
    USING (check_is_member_or_owner(store_id))
    WITH CHECK (check_is_member_or_owner(store_id));

-- 5. SELF-HEALING: Ensure Owner is in Store Members
-- This fixes the root cause where an owner might not be listed as a member
INSERT INTO store_members (store_id, user_id, role, status)
SELECT id, owner_id, 'owner', 'active'
FROM stores
WHERE NOT EXISTS (
    SELECT 1 FROM store_members 
    WHERE store_members.store_id = stores.id 
    AND store_members.user_id = stores.owner_id
);

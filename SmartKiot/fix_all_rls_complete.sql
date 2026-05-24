-- COMPLETE RLS FIX: Store Members and Stores
-- Run this in Supabase SQL Editor

-- ============================================
-- 1. FIX STORE_MEMBERS POLICIES
-- ============================================

-- Drop all existing store_members policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their memberships" ON public.store_members;
DROP POLICY IF EXISTS "Managers can view store members" ON public.store_members;
DROP POLICY IF EXISTS "Owners can manage store members" ON public.store_members;
DROP POLICY IF EXISTS "Managers can manage members" ON public.store_members;
DROP POLICY IF EXISTS "Users can update their own membership status" ON public.store_members;
DROP POLICY IF EXISTS "Owners can insert store members" ON public.store_members;
DROP POLICY IF EXISTS "Users can link own invited email" ON public.store_members;

-- Ensure helper functions exist
CREATE OR REPLACE FUNCTION public.check_is_owner(lookup_store_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM stores
    WHERE id = lookup_store_id
    AND owner_id = auth.uid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.check_is_manager(lookup_store_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM store_members
    WHERE store_id = lookup_store_id
    AND user_id = auth.uid()
    AND role IN ('owner', 'manager')
    AND status = 'active'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_is_owner(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.check_is_manager(UUID) TO authenticated;

-- SELECT: Users can see their own memberships (by user_id, by email, or if they're owner/manager)
CREATE POLICY "Users can view their memberships" ON public.store_members
FOR SELECT
USING (
    auth.uid() = user_id
    OR (
        lower(email) = lower((auth.jwt() ->> 'email'))
        AND email IS NOT NULL
    )
    OR check_is_owner(store_id)
    OR check_is_manager(store_id)
);

-- INSERT: Owners and managers can add members
CREATE POLICY "Owners and managers can insert members" ON public.store_members
FOR INSERT
WITH CHECK (
    check_is_owner(store_id) OR check_is_manager(store_id)
);

-- UPDATE: 
-- 1. Users can update their own membership (accept invitation)
-- 2. Owners/managers can update any member in their store
CREATE POLICY "Users can update own membership" ON public.store_members
FOR UPDATE
USING (
    auth.uid() = user_id
    OR check_is_owner(store_id)
    OR check_is_manager(store_id)
)
WITH CHECK (
    auth.uid() = user_id
    OR check_is_owner(store_id)
    OR check_is_manager(store_id)
);

-- DELETE: Only owners can delete members
CREATE POLICY "Owners can delete members" ON public.store_members
FOR DELETE
USING (check_is_owner(store_id));

-- ============================================
-- 2. FIX STORES POLICIES (if needed)
-- ============================================

-- Drop and recreate stores SELECT policy for clarity
DROP POLICY IF EXISTS "Users can view their stores" ON public.stores;

CREATE POLICY "Users can view their stores" ON public.stores
FOR SELECT
USING (
    auth.uid() = owner_id
    OR EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = stores.id
        AND sm.user_id = auth.uid()
        AND (sm.status = 'active' OR sm.status = 'invited')
    )
);

-- ============================================
-- 3. NOTIFY PG TO RELOAD
-- ============================================
NOTIFY pgrst, 'reload schema';

-- Migration to add Stores and Multi-Store Support
-- Run this in Supabase SQL Editor

-- 1. Create Stores Table first
CREATE TABLE IF NOT EXISTS stores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT,
    owner_id UUID REFERENCES auth.users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create Store Members Table immediately after
CREATE TABLE IF NOT EXISTS store_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT CHECK (role IN ('owner', 'manager', 'employee')) DEFAULT 'employee',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'invited', 'declined')),
    permissions JSONB DEFAULT '[]'::jsonb,
    UNIQUE(store_id, user_id)
);

-- 2.1 Ensure columns exist if table was already created
ALTER TABLE store_members ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' CHECK (status IN ('active', 'invited', 'declined'));
ALTER TABLE store_members ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '[]'::jsonb;

-- 3. Enable RLS and Add Policies for Stores
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;

-- Policy: Owners can do everything with their stores
DROP POLICY IF EXISTS "Owners can manage their stores" ON stores;
CREATE POLICY "Owners can manage their stores" ON stores
    USING (auth.uid() = owner_id);

-- Policy: Members can view stores they belong to (via store_members)
DROP POLICY IF EXISTS "Members can view their stores" ON stores;
CREATE POLICY "Members can view their stores" ON stores
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM store_members
            WHERE store_members.store_id = stores.id
            AND store_members.user_id = auth.uid()
            AND (store_members.status = 'active' OR store_members.status = 'invited')
        )
    );

-- 4. Enable RLS and Add Policies for Store Members
ALTER TABLE store_members ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view memberships they are part of (including invitations)
DROP POLICY IF EXISTS "Users can view their memberships" ON store_members;
CREATE POLICY "Users can view their memberships" ON store_members
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy: Owners and Managers can manage members in their store
-- 60. Fix infinite recursion using a SECURITY DEFINER function
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

GRANT EXECUTE ON FUNCTION public.check_is_manager(UUID) TO authenticated;

-- Helper function to check ownership without triggering recursion on 'stores' table
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

GRANT EXECUTE ON FUNCTION public.check_is_owner(UUID) TO authenticated;

-- 8. Fix RLS for Accepting Invitations (Updating own membership status)
DROP POLICY IF EXISTS "Users can update their own membership status" ON store_members;
CREATE POLICY "Users can update their own membership status" ON store_members
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 3. Update Policies to use the secure functions
DROP POLICY IF EXISTS "Managers can manage members" ON store_members;
CREATE POLICY "Managers can manage members" ON store_members
    USING (check_is_manager(store_id));

-- 5. Update Profiles to track current store
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS current_store_id UUID REFERENCES stores(id);

-- 6. Secure User Lookup Function (for invitations)
-- Allows searching for users by email or phone number without exposing the entire profiles table
-- Uses auth.users as the source of truth for email/phone
CREATE OR REPLACE FUNCTION public.find_user_by_email_or_phone(search_term TEXT)
RETURNS TABLE (
  id UUID,
  full_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    au.id, 
    COALESCE(p.full_name, (au.raw_user_meta_data->>'full_name'), 'Người dùng') as full_name
  FROM auth.users au
  LEFT JOIN public.profiles p ON p.id = au.id
  WHERE au.email = search_term 
     OR au.phone = search_term; -- Note: Phone must match format in auth.users (usually E.164)
END;
$$;

GRANT EXECUTE ON FUNCTION public.find_user_by_email_or_phone(TEXT) TO authenticated;

-- 7. Fix RLS Policy for Owners (Critical for first insert and invite)
-- Use SECURITY DEFINER function check_is_owner to avoid recursion
DROP POLICY IF EXISTS "Owners can manage store members" ON store_members;
CREATE POLICY "Owners can manage store members" ON store_members
    USING (check_is_owner(store_id));

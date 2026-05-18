-- Fix RLS policies for "stores" table to allow creating new stores
-- Run this in Supabase SQL Editor

-- Drop the old single policy
DROP POLICY IF EXISTS "Secure Stores Policy" ON stores;

-- Create separate policies for each operation (more flexible)
-- 1. Policy for SELECT: members/owners can view their stores
CREATE POLICY "Users can view their stores" ON stores
    FOR SELECT
    USING (
        auth.uid() = owner_id OR
        EXISTS (
            SELECT 1 FROM store_members
            WHERE store_members.store_id = stores.id
            AND store_members.user_id = auth.uid()
            AND (store_members.status = 'active' OR store_members.status = 'invited')
        )
    );

-- 2. Policy for INSERT: any authenticated user can create a store with owner_id = auth.uid()
CREATE POLICY "Users can create their own stores" ON stores
    FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

-- 3. Policy for UPDATE: only the owner can update the store
CREATE POLICY "Owners can update their stores" ON stores
    FOR UPDATE
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

-- 4. Policy for DELETE: only the owner can delete the store
CREATE POLICY "Owners can delete their stores" ON stores
    FOR DELETE
    USING (auth.uid() = owner_id);

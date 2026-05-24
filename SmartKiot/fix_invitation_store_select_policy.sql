-- Fix RLS policy to allow users to read stores they are invited to
-- This policy allows users to read stores where they are members (invited or active)

-- Drop existing policy if exists
DROP POLICY IF EXISTS "Users can view stores they are members of" ON stores;

-- Create new policy that allows reading stores if user is in store_members
CREATE POLICY "Users can view stores they are members of"
ON stores
FOR SELECT
USING (
  id IN (
    SELECT store_id 
    FROM store_members 
    WHERE user_id = auth.uid() 
       OR (email = auth.email() AND user_id IS NULL)
  )
);

-- Also ensure store_members policy allows reading by email
DROP POLICY IF EXISTS "Users can view store memberships" ON store_members;

CREATE POLICY "Users can view store memberships"
ON store_members
FOR SELECT
USING (
  user_id = auth.uid() 
  OR (email = auth.email() AND user_id IS NULL)
);

-- Verify policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies 
WHERE tablename IN ('stores', 'store_members')
ORDER BY tablename, policyname;

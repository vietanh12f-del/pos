-- Complete fix for invitation flow issues

-- 1. Fix UPDATE policy for store_members
DROP POLICY IF EXISTS "Users can update their own store memberships" ON store_members;

CREATE POLICY "Users can update their own store memberships"
ON store_members
FOR UPDATE
USING (
  user_id = auth.uid() 
  OR (email = auth.email() AND user_id IS NULL)
);

-- 2. Fix SELECT policy for stores (already done but include for completeness)
DROP POLICY IF EXISTS "Users can view stores they are members of" ON stores;

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

-- 3. Ensure store_members SELECT policy is correct
DROP POLICY IF EXISTS "Users can view store memberships" ON store_members;

CREATE POLICY "Users can view store memberships"
ON store_members
FOR SELECT
USING (
  user_id = auth.uid() 
  OR (email = auth.email() AND user_id IS NULL)
);

-- 4. Test update directly
UPDATE store_members 
SET status = 'active', user_id = '82D7B309-C19F-4566-9FAC-54D255DB8A39'
WHERE store_id = '7E34DDB4-DA3B-4F77-B6F4-C3E837436593' 
  AND email = 'datchau576@gmail.com';

-- 5. Verify all policies
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

-- Add UPDATE policy for store_members to allow users to update their own invitations
DROP POLICY IF EXISTS "Users can update their own store memberships" ON store_members;

CREATE POLICY "Users can update their own store memberships"
ON store_members
FOR UPDATE
USING (
  user_id = auth.uid() 
  OR (email = auth.email() AND user_id IS NULL)
);

-- Verify all policies
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
WHERE tablename = 'store_members'
ORDER BY policyname;

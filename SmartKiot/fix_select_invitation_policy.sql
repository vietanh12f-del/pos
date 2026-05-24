-- Fix: Add SELECT policy for users to view their own memberships by user_id OR by email
-- This ensures users can see pending invitations even before user_id is linked

-- Drop the old restrictive policy
DROP POLICY IF EXISTS "Users can view their memberships" ON public.store_members;

-- Create new policy that allows viewing by user_id OR by matching email OR by ownership
CREATE POLICY "Users can view their memberships" ON public.store_members
FOR SELECT
USING (
    auth.uid() = user_id
    OR (
        lower(email) = lower((auth.jwt() ->> 'email'))
        AND email IS NOT NULL
    )
    OR check_is_owner(store_id)  -- Allow owners to view members in their stores
);

-- Also ensure managers/owners can view members in their store
DROP POLICY IF EXISTS "Managers can view store members" ON public.store_members;
CREATE POLICY "Managers can view store members" ON public.store_members
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.store_members sm
        WHERE sm.store_id = store_members.store_id
        AND sm.user_id = auth.uid()
        AND sm.role IN ('owner', 'manager')
        AND sm.status = 'active'
    )
);

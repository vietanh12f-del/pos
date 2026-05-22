ALTER TABLE public.store_members
ADD COLUMN IF NOT EXISTS email text;

ALTER TABLE public.store_members
ALTER COLUMN user_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_store_members_email_status
ON public.store_members (lower(email), status)
WHERE email IS NOT NULL;

DROP POLICY IF EXISTS "Owners can insert store members" ON public.store_members;
CREATE POLICY "Owners can insert store members" ON public.store_members
FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.stores
        WHERE stores.id = store_members.store_id
          AND stores.owner_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Users can link own invited email" ON public.store_members;
CREATE POLICY "Users can link own invited email" ON public.store_members
FOR UPDATE
USING (
    status = 'invited'
    AND user_id IS NULL
    AND lower(email) = lower((auth.jwt() ->> 'email'))
)
WITH CHECK (
    status = 'invited'
    AND user_id = auth.uid()
    AND lower(email) = lower((auth.jwt() ->> 'email'))
);

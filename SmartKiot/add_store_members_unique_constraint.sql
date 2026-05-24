-- Add unique constraint on store_id + email for upsert to work properly
-- This allows re-inviting employees who were previously deleted/declined

-- First, check if constraint exists
DO $$
BEGIN
    -- Add unique index/constraint if not exists
    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes 
        WHERE indexname = 'idx_store_members_store_email_unique'
    ) THEN
        -- Create unique index (will fail if there are duplicates - handle manually)
        CREATE UNIQUE INDEX idx_store_members_store_email_unique 
        ON public.store_members (store_id, lower(email)) 
        WHERE email IS NOT NULL;
    END IF;
END $$;

-- Alternative: If you want to handle duplicates first, run this before:
-- DELETE FROM store_members 
-- WHERE id NOT IN (
--     SELECT MIN(id) 
--     FROM store_members 
--     GROUP BY store_id, lower(email)
-- );

-- Fix duplicates and add unique constraint for store_members
-- Step 0: Drop any existing unique indexes on store_members first
DROP INDEX IF EXISTS idx_store_members_store_email_unique;
DROP INDEX IF EXISTS idx_store_members_store_email;

-- Step 1: Delete ALL duplicate entries for same (store_id, email)
-- Keep only the one with the most recent status (invited > active > declined)
WITH ranked AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY store_id, email 
               ORDER BY 
                   CASE status 
                       WHEN 'invited' THEN 1 
                       WHEN 'active' THEN 2 
                       WHEN 'declined' THEN 3 
                       ELSE 4 
                   END,
                   joined_at DESC NULLS LAST,
                   id
           ) as rn
    FROM store_members
    WHERE email IS NOT NULL
)
DELETE FROM store_members 
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

-- Step 2: Create unique constraint/index on (store_id, email)
-- This matches exactly with Swift .upsert(onConflict: "store_id,email")
CREATE UNIQUE INDEX idx_store_members_store_email 
ON public.store_members (store_id, email) 
WHERE email IS NOT NULL;

-- Step 3: Verify
SELECT 'Unique constraint created successfully' as status;

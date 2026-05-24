-- Fix cleanup when profile is deleted
-- Add cascade delete or trigger to clean up store_members

-- Option 1: Add ON DELETE CASCADE (if foreign key exists)
-- ALTER TABLE store_members DROP CONSTRAINT store_members_user_id_fkey;
-- ALTER TABLE store_members ADD CONSTRAINT store_members_user_id_fkey 
--   FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- Option 2: Create trigger to clean up when profile is deleted
CREATE OR REPLACE FUNCTION cleanup_store_members_on_profile_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- Delete store_members when user profile is deleted
    DELETE FROM store_members 
    WHERE user_id = OLD.id 
       OR (email = (SELECT email FROM profiles WHERE id = OLD.id) AND user_id IS NULL);
    
    -- Also clean up any orphaned invitations (no user_id and no matching profile)
    DELETE FROM store_members 
    WHERE user_id IS NULL 
      AND email NOT IN (SELECT email FROM profiles WHERE email IS NOT NULL);
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if exists
DROP TRIGGER IF EXISTS cleanup_store_members_trigger ON profiles;

-- Create trigger
CREATE TRIGGER cleanup_store_members_trigger
    AFTER DELETE ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_store_members_on_profile_delete();

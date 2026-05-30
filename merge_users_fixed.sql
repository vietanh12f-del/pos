
-- 1. Set the user IDs here first! Get them from your auth.users table!
-- Replace these with the actual IDs from your logs!
-- For example:
-- old_user_id = ID of user with email vnvendingvnvending@gmail.com
-- new_user_id = ID of user with phone +84986653040 (without +)
DO $$
DECLARE
    old_user_id UUID;  -- Replace this with the old user ID
    new_user_id UUID;  -- Replace this with the new user ID
BEGIN
    -- Replace these values with the actual user IDs!
    old_user_id := 'ENTER_OLD_USER_ID_HERE';
    new_user_id := 'ENTER_NEW_USER_ID_HERE';

    -- 2. Update stores to change owner
    UPDATE stores
    SET owner_id = new_user_id
    WHERE owner_id = old_user_id;

    -- 3. Update store_members where user_id matches
    UPDATE store_members
    SET user_id = new_user_id
    WHERE user_id = old_user_id;

    -- 4. Update store_members where email matches old user's email
    UPDATE store_members
    SET user_id = new_user_id, email = NULL
    FROM auth.users u
    WHERE store_members.email = u.email AND u.id = old_user_id;

    -- 5. Update profiles table (if exists)
    UPDATE profiles
    SET id = new_user_id
    WHERE id = old_user_id;

    -- Optional: Delete the old user
    -- DELETE FROM auth.users WHERE id = old_user_id;
END $$;

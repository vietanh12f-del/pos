
-- 1. Find the old user (Gmail user) and new user (phone user)
-- Replace these placeholders with the actual IDs from your auth.users table!
WITH old_user AS (
    SELECT id AS old_id FROM auth.users WHERE email = 'vnvendingvnvending@gmail.com'
),
new_user AS (
    SELECT id AS new_id FROM auth.users WHERE phone = '+84986653040' OR phone = '84986653040'
)

-- 2. Update stores to change owner from old user to new user
UPDATE stores
SET owner_id = new_user.new_id
FROM old_user, new_user
WHERE owner_id = old_user.old_id;

-- 3. Update store_members to change user_id from old to new where user_id matches
UPDATE store_members
SET user_id = new_user.new_id
FROM old_user, new_user
WHERE user_id = old_user.old_id;

-- 4. Update store_members where email matches old user's email (set user_id to new and clear email if needed)
UPDATE store_members
SET user_id = new_user.new_id, email = NULL
FROM old_user, new_user, auth.users u
WHERE store_members.email = u.email AND u.id = old_user.old_id;

-- 5. Update any other tables that reference user_id (add your tables here!)
-- For example, if you have a profiles table:
UPDATE profiles
SET id = new_user.new_id
FROM old_user, new_user
WHERE profiles.id = old_user.old_id;

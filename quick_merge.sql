
-- STEP 1: Find the old user ID (the one with the stores)
-- Uncomment and run this first to get the IDs
-- SELECT id, email, phone FROM auth.users ORDER BY created_at DESC;

-- STEP 2: Replace these with your actual user IDs!
-- Copy the old user ID from the query above and paste it here!
-- Copy the new user ID too!
UPDATE stores
SET owner_id = 'ENTER_NEW_USER_ID_HERE'
WHERE owner_id = 'ENTER_OLD_USER_ID_HERE';

UPDATE store_members
SET user_id = 'ENTER_NEW_USER_ID_HERE'
WHERE user_id = 'ENTER_OLD_USER_ID_HERE';

-- STEP 3: Update store_members where email matches too!
UPDATE store_members
SET user_id = 'ENTER_NEW_USER_ID_HERE', email = NULL
WHERE email = 'vnvendingvnvending@gmail.com';

-- STEP 4: Update profiles too!
UPDATE profiles
SET id = 'ENTER_NEW_USER_ID_HERE'
WHERE id = 'ENTER_OLD_USER_ID_HERE';

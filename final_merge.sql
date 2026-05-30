
-- ACTUAL USER IDs:
-- Old user (Gmail): 15f52f0c-3dee-4e65-af0f-fc066e69014e
-- New user (phone): a90c23bf-6a59-46a0-b645-7261925747c4

-- Update stores to change owner from old to new
UPDATE stores
SET owner_id = 'a90c23bf-6a59-46a0-b645-7261925747c4'
WHERE owner_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';

-- Update store_members where user_id matches old user
UPDATE store_members
SET user_id = 'a90c23bf-6a59-46a0-b645-7261925747c4'
WHERE user_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';

-- Update store_members where email is old user's email
UPDATE store_members
SET user_id = 'a90c23bf-6a59-46a0-b645-7261925747c4', email = NULL
WHERE email = 'vnvendingvnvending@gmail.com';

-- Update profiles table (swap old id to new id)
UPDATE profiles
SET id = 'a90c23bf-6a59-46a0-b645-7261925747c4'
WHERE id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';

-- Optional: Update the new auth user to have the original email (instead of dummy)
UPDATE auth.users
SET email = 'vnvendingvnvending@gmail.com', email_confirmed_at = NOW()
WHERE id = 'a90c23bf-6a59-46a0-b645-7261925747c4';

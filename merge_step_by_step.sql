
-- =============================================
-- STEP 1: Update everything except profiles first
-- =============================================
UPDATE stores
SET owner_id = 'a90c23bf-6a59-46a0-b645-7261925747c4'
WHERE owner_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';

UPDATE store_members
SET user_id = 'a90c23bf-6a59-46a0-b645-7261925747c4'
WHERE user_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';

UPDATE store_members
SET user_id = 'a90c23bf-6a59-46a0-b645-7261925747c4', email = NULL
WHERE email = 'vnvendingvnvending@gmail.com';

-- Update other tables too
UPDATE order_edits SET editor_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE editor_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';
UPDATE production_edits SET editor_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE editor_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';
UPDATE restock_edits SET editor_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE editor_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';
UPDATE attendance_records SET user_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE user_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';
UPDATE user_feedback SET user_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE user_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';
UPDATE operating_expenses SET creator_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE creator_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';
UPDATE orders SET creator_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE creator_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';
UPDATE restock_bills SET creator_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE creator_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';
UPDATE production_transactions SET creator_id = 'a90c23bf-6a59-46a0-b645-7261925747c4' WHERE creator_id = '15f52f0c-3dee-4e65-af0f-fc066e69014e';

-- =============================================
-- STEP 2: Swap the profiles carefully
-- =============================================
-- First, temporarily disable the foreign key constraints for order_edits (or just update profile data)
-- Let's just copy data from old profile to new profile instead!
UPDATE profiles
SET 
    full_name = (SELECT full_name FROM profiles WHERE id = '15f52f0c-3dee-4e65-af0f-fc066e69014e'),
    email = 'vnvendingvnvending@gmail.com',
    phone_number = '84986653040',
    address = (SELECT address FROM profiles WHERE id = '15f52f0c-3dee-4e65-af0f-fc066e69014e'),
    avatar_url = (SELECT avatar_url FROM profiles WHERE id = '15f52f0c-3dee-4e65-af0f-fc066e69014e'),
    current_store_id = (SELECT current_store_id FROM profiles WHERE id = '15f52f0c-3dee-4e65-af0f-fc066e69014e'),
    account_role = (SELECT account_role FROM profiles WHERE id = '15f52f0c-3dee-4e65-af0f-fc066e69014e')
WHERE id = 'a90c23bf-6a59-46a0-b645-7261925747c4';

-- =============================================
-- STEP 3: Update auth user
-- =============================================
UPDATE auth.users
SET email = 'vnvendingvnvending@gmail.com', email_confirmed_at = NOW()
WHERE id = 'a90c23bf-6a59-46a0-b645-7261925747c4';

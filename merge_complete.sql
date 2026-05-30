
-- ACTUAL USER IDs:
-- Old user (Gmail): 15f52f0c-3dee-4e65-af0f-fc066e69014e
-- New user (phone): a90c23bf-6a59-46a0-b645-7261925747c4

-- Function to update user ID in any table
DO $$
DECLARE
    old_user UUID := '15f52f0c-3dee-4e65-af0f-fc066e69014e';
    new_user UUID := 'a90c23bf-6a59-46a0-b645-7261925747c4';
BEGIN
    -- 1. First, update all tables that have new_user references to old_user first (then update to new_user)
    -- This way, we can safely delete the new_user's profile!
    UPDATE order_edits SET editor_id = old_user WHERE editor_id = new_user;
    UPDATE production_edits SET editor_id = old_user WHERE editor_id = new_user;
    UPDATE restock_edits SET editor_id = old_user WHERE editor_id = new_user;
    UPDATE attendance_records SET user_id = old_user WHERE user_id = new_user;
    UPDATE user_feedback SET user_id = old_user WHERE user_id = new_user;
    UPDATE operating_expenses SET creator_id = old_user WHERE creator_id = new_user;
    UPDATE orders SET creator_id = old_user WHERE creator_id = new_user;
    UPDATE restock_bills SET creator_id = old_user WHERE creator_id = new_user;
    UPDATE production_transactions SET creator_id = old_user WHERE creator_id = new_user;

    -- 2. Now delete new_user's profile safely
    DELETE FROM profiles WHERE id = new_user;

    -- 3. Now update everything from old_user to new_user!
    -- Update stores ownership
    UPDATE stores SET owner_id = new_user WHERE owner_id = old_user;

    -- Update store_members
    UPDATE store_members SET user_id = new_user WHERE user_id = old_user;
    UPDATE store_members SET user_id = new_user, email = NULL WHERE email = 'vnvendingvnvending@gmail.com';

    -- Update all other tables!
    UPDATE order_edits SET editor_id = new_user WHERE editor_id = old_user;
    UPDATE production_edits SET editor_id = new_user WHERE editor_id = old_user;
    UPDATE restock_edits SET editor_id = new_user WHERE editor_id = old_user;

    -- Update attendance records if you have them
    UPDATE attendance_records SET user_id = new_user WHERE user_id = old_user;

    -- Update user feedback if you have it
    UPDATE user_feedback SET user_id = new_user WHERE user_id = old_user;

    -- Update operating expenses if you have them
    UPDATE operating_expenses SET creator_id = new_user WHERE creator_id = old_user;

    -- Update orders if you have them
    UPDATE orders SET creator_id = new_user WHERE creator_id = old_user;

    -- Update restock bills
    UPDATE restock_bills SET creator_id = new_user WHERE creator_id = old_user;

    -- Update production transactions
    UPDATE production_transactions SET creator_id = new_user WHERE creator_id = old_user;

    -- Finally, update the old profile to use new user's ID
    UPDATE profiles SET id = new_user WHERE id = old_user;

    -- Update auth.user to use original email
    UPDATE auth.users
    SET email = 'vnvendingvnvending@gmail.com', email_confirmed_at = NOW()
    WHERE id = new_user;

    -- Optional: Delete old auth user (uncomment if you want!)
    -- DELETE FROM auth.users WHERE id = old_user;

END $$;

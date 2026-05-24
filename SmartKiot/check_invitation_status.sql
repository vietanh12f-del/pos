-- Check current status of store_members for this user
SELECT 
    id,
    store_id,
    user_id,
    email,
    role,
    status,
    joined_at
FROM store_members 
WHERE email = 'datchau576@gmail.com' 
   OR user_id = '82D7B309-C19F-4566-9FAC-54D255DB8A39'
ORDER BY joined_at DESC;

-- Also check stores to verify they exist
SELECT id, name, owner_id 
FROM stores 
WHERE id IN (
    '7E34DDB4-DA3B-4F77-B6F4-C3E837436593',
    'A15F0B2B-3FB3-4E59-9DD0-DDBC141D9D23',
    '486E31C2-4CAD-4CD3-BE2A-1265E0F199A8',
    'D17BB808-7C9F-4B61-A74D-F69AC6E29B4E',
    'A49A4558-6698-4229-9D95-CDBB961426A7'
);

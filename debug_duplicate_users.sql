
-- List all auth users
SELECT id, email, phone FROM auth.users ORDER BY created_at DESC;

-- List all store members with user details
SELECT 
    sm.id AS store_member_id,
    sm.store_id,
    sm.user_id,
    sm.email AS member_email,
    sm.role,
    sm.status,
    s.name AS store_name
FROM 
    store_members sm
LEFT JOIN 
    stores s ON sm.store_id = s.id
ORDER BY 
    s.name;

-- List all stores
SELECT 
    id, name, owner_id, address, created_at
FROM 
    stores
ORDER BY 
    created_at DESC;

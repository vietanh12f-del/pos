-- Test updating status directly
UPDATE store_members 
SET status = 'active', user_id = '82D7B309-C19F-4566-9FAC-54D255DB8A39'
WHERE store_id = '7E34DDB4-DA3B-4F77-B6F4-C3E837436593' 
  AND email = 'datchau576@gmail.com';

-- Check result
SELECT 
    id,
    store_id,
    user_id,
    email,
    role,
    status,
    joined_at
FROM store_members 
WHERE store_id = '7E34DDB4-DA3B-4F77-B6F4-C3E837436593' 
  AND email = 'datchau576@gmail.com';

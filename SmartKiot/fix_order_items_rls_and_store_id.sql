-- Fix order_items: add store_id column and correct RLS policy
-- Run this in Supabase SQL Editor

-- 1. Add store_id column to order_items (referencing orders.store_id)
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id);
CREATE INDEX IF NOT EXISTS idx_order_items_store_id ON order_items(store_id);

-- 2. Backfill store_id for existing order_items from their parent orders
UPDATE order_items 
SET store_id = orders.store_id 
FROM orders 
WHERE order_items.order_id = orders.id 
AND order_items.store_id IS NULL;

-- 3. Fix the RLS policy for order_items to use either:
--    a) its own store_id (for new items), OR
--    b) the parent order's store_id (for backcompat)
DROP POLICY IF EXISTS "Secure Order Items Policy" ON order_items;
CREATE POLICY "Secure Order Items Policy" ON order_items
    FOR ALL
    USING (
        -- Check either order_items.store_id OR parent orders.store_id
        check_is_member_or_owner(store_id) OR 
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = order_items.order_id 
            AND check_is_member_or_owner(orders.store_id)
        )
    )
    WITH CHECK (
        -- When inserting/updating, ensure we have store_id either on item or parent
        check_is_member_or_owner(store_id) OR 
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = order_items.order_id 
            AND check_is_member_or_owner(orders.store_id)
        )
    );

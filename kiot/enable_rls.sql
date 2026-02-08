-- Enable RLS (Row Level Security) on all tables
-- This ensures that access is controlled via policies.
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE restock_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE restock_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_history ENABLE ROW LEVEL SECURITY;

-- Create Policy to allow ALL operations for Anonymous users (Public access)
-- Note: This is suitable for a single-user app or development. 
-- For multi-user apps, you should implement Authentication.

-- 1. Products
CREATE POLICY "Enable access for all users" ON products
FOR ALL USING (true) WITH CHECK (true);

-- 2. Orders
CREATE POLICY "Enable access for all users" ON orders
FOR ALL USING (true) WITH CHECK (true);

-- 3. Order Items
CREATE POLICY "Enable access for all users" ON order_items
FOR ALL USING (true) WITH CHECK (true);

-- 4. Restock Bills
CREATE POLICY "Enable access for all users" ON restock_bills
FOR ALL USING (true) WITH CHECK (true);

-- 5. Restock Items
CREATE POLICY "Enable access for all users" ON restock_items
FOR ALL USING (true) WITH CHECK (true);

-- 6. Price History
CREATE POLICY "Enable access for all users" ON price_history
FOR ALL USING (true) WITH CHECK (true);

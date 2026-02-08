-- Enable Realtime for all core tables to ensure synchronization between devices

-- 1. Enable Realtime for Products
ALTER PUBLICATION supabase_realtime ADD TABLE products;

-- 2. Enable Realtime for Orders
ALTER PUBLICATION supabase_realtime ADD TABLE orders;

-- 3. Enable Realtime for Restock Bills
ALTER PUBLICATION supabase_realtime ADD TABLE restock_bills;

-- 4. Enable Realtime for Operating Expenses
ALTER PUBLICATION supabase_realtime ADD TABLE operating_expenses;

-- 5. Enable Realtime for Store Members (to sync permission changes)
ALTER PUBLICATION supabase_realtime ADD TABLE store_members;

-- Note: You might need to run these individually if some are already added. 
-- Supabase might throw an error if the table is already in the publication, 
-- but usually it's safe to run or check first.

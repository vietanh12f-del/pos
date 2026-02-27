-- Fix for Operating Expenses not saving/loading per store
-- Run this in Supabase SQL Editor

-- 1. Ensure store_id column exists (if it was missed in previous migrations)
ALTER TABLE operating_expenses 
ADD COLUMN IF NOT EXISTS store_id UUID REFERENCES stores(id) ON DELETE CASCADE;

-- 2. Create index for performance
CREATE INDEX IF NOT EXISTS idx_operating_expenses_store_id ON operating_expenses(store_id);

-- 3. Enable RLS (Row Level Security)
ALTER TABLE operating_expenses ENABLE ROW LEVEL SECURITY;

-- 4. Create Policies

-- Policy: Owners and Managers can do everything
DROP POLICY IF EXISTS "Owners and Managers can manage expenses" ON operating_expenses;
CREATE POLICY "Owners and Managers can manage expenses" ON operating_expenses
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM store_members
            WHERE store_id = operating_expenses.store_id
            AND user_id = auth.uid()
            AND role IN ('owner', 'manager')
            AND status = 'active'
        )
    );

-- Policy: Employees with 'viewExpenses' permission can view
DROP POLICY IF EXISTS "Employees can view expenses with permission" ON operating_expenses;
CREATE POLICY "Employees can view expenses with permission" ON operating_expenses
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM store_members
            WHERE store_id = operating_expenses.store_id
            AND user_id = auth.uid()
            AND role = 'employee'
            AND status = 'active'
            AND permissions @> '["viewExpenses"]'::jsonb
        )
    );

-- Add ON DELETE CASCADE to store-related foreign keys
-- Run this in Supabase SQL Editor

-- Drop existing foreign key constraints and re-add with ON DELETE CASCADE

-- Profiles table (current_store_id) - THIS IS THE ISSUE FROM THE ERROR!
ALTER TABLE profiles 
DROP CONSTRAINT IF EXISTS profiles_current_store_id_fkey,
ADD CONSTRAINT profiles_current_store_id_fkey 
FOREIGN KEY (current_store_id) REFERENCES stores(id) ON DELETE SET NULL;

-- Products table
ALTER TABLE products 
DROP CONSTRAINT IF EXISTS products_store_id_fkey,
ADD CONSTRAINT products_store_id_fkey 
FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;

-- Orders table
ALTER TABLE orders 
DROP CONSTRAINT IF EXISTS orders_store_id_fkey,
ADD CONSTRAINT orders_store_id_fkey 
FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;

-- Restock bills table
ALTER TABLE restock_bills 
DROP CONSTRAINT IF EXISTS restock_bills_store_id_fkey,
ADD CONSTRAINT restock_bills_store_id_fkey 
FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;

-- Operating expenses table
ALTER TABLE operating_expenses 
DROP CONSTRAINT IF EXISTS operating_expenses_store_id_fkey,
ADD CONSTRAINT operating_expenses_store_id_fkey 
FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;

-- Also check other tables that might reference stores (like sequence_counters, leave_requests, attendance_records, etc.)
-- Let's check those too to be safe

-- Sequence counters
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'sequence_counters' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE sequence_counters 
        DROP CONSTRAINT IF EXISTS sequence_counters_store_id_fkey,
        ADD CONSTRAINT sequence_counters_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Leave requests
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'leave_requests' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE leave_requests 
        DROP CONSTRAINT IF EXISTS leave_requests_store_id_fkey,
        ADD CONSTRAINT leave_requests_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Attendance records
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'attendance_records' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE attendance_records 
        DROP CONSTRAINT IF EXISTS attendance_records_store_id_fkey,
        ADD CONSTRAINT attendance_records_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Trading parties
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'trading_parties' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE trading_parties 
        DROP CONSTRAINT IF EXISTS trading_parties_store_id_fkey,
        ADD CONSTRAINT trading_parties_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Website leads
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'website_leads' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE website_leads 
        DROP CONSTRAINT IF EXISTS website_leads_store_id_fkey,
        ADD CONSTRAINT website_leads_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Materials table (from materials_schema.sql)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'materials' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE materials 
        DROP CONSTRAINT IF EXISTS materials_store_id_fkey,
        ADD CONSTRAINT materials_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Production transactions (from production_schema.sql)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'production_transactions' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE production_transactions 
        DROP CONSTRAINT IF EXISTS production_transactions_store_id_fkey,
        ADD CONSTRAINT production_transactions_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Auto material export logs
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'auto_material_export_logs' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE auto_material_export_logs 
        DROP CONSTRAINT IF EXISTS auto_material_export_logs_store_id_fkey,
        ADD CONSTRAINT auto_material_export_logs_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Order edits
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'order_edits' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE order_edits 
        DROP CONSTRAINT IF EXISTS order_edits_store_id_fkey,
        ADD CONSTRAINT order_edits_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Restock edits
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'restock_edits' 
        AND constraint_type = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE restock_edits 
        DROP CONSTRAINT IF EXISTS restock_edits_store_id_fkey,
        ADD CONSTRAINT restock_edits_store_id_fkey 
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE;
    END IF;
END $$;

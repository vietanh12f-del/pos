-- Migration: Add sequence_number to orders, restock_bills, and production_transactions
-- This column stores a unique, human-readable order/bill number (e.g., 20260502-123456-ABCD)

ALTER TABLE orders ADD COLUMN IF NOT EXISTS sequence_number TEXT;
ALTER TABLE restock_bills ADD COLUMN IF NOT EXISTS sequence_number TEXT;
ALTER TABLE production_transactions ADD COLUMN IF NOT EXISTS sequence_number TEXT;

-- Unit System Support
ALTER TABLE products ADD COLUMN IF NOT EXISTS unit_system TEXT DEFAULT 'weight';
ALTER TABLE materials ADD COLUMN IF NOT EXISTS unit_system TEXT DEFAULT 'weight';
ALTER TABLE restock_items ADD COLUMN IF NOT EXISTS unit_system TEXT DEFAULT 'weight';
ALTER TABLE production_transaction_items ADD COLUMN IF NOT EXISTS unit_system TEXT DEFAULT 'weight';

-- Indexing for faster lookup
CREATE INDEX IF NOT EXISTS idx_orders_sequence_number ON orders(sequence_number);
CREATE INDEX IF NOT EXISTS idx_restock_bills_sequence_number ON restock_bills(sequence_number);
CREATE INDEX IF NOT EXISTS idx_production_transactions_sequence_number ON production_transactions(sequence_number);

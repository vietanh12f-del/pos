-- Migration: Add bill_number to orders table
-- bill_number is an optional integer chosen by the user when creating an order
-- (e.g. table number, customer number, etc.)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS bill_number INTEGER;

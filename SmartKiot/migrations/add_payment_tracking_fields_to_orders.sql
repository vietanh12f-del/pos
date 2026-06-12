-- Add payment tracking fields to orders table
ALTER TABLE orders
ADD COLUMN IF NOT EXISTS paid_amount numeric,
ADD COLUMN IF NOT EXISTS debt_amount numeric,
ADD COLUMN IF NOT EXISTS expected_pay_date timestamptz;

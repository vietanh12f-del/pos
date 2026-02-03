-- Add cost_price column to order_items table
ALTER TABLE public.order_items 
ADD COLUMN IF NOT EXISTS cost_price DOUBLE PRECISION DEFAULT 0;

-- Update existing records to have cost_price = 0 (or we could try to backfill from products, but that's complex)
-- For now, default 0 is safe.

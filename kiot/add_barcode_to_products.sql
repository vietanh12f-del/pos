ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS barcode TEXT;

-- Add index for faster search
CREATE INDEX IF NOT EXISTS idx_products_barcode ON public.products(barcode);

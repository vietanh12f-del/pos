ALTER TABLE orders
ADD COLUMN IF NOT EXISTS receipt_image_url TEXT;

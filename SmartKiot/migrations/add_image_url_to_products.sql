-- Add image_url column to products table
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Create storage bucket for product images if not exists
-- Note: Bucket creation is usually done via Supabase Dashboard or API, but we can try to insert into storage.buckets if permissions allow
-- INSERT INTO storage.buckets (id, name, public) VALUES ('product-images', 'product-images', true) ON CONFLICT DO NOTHING;

-- Policy to allow public read access to product images
-- CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING ( bucket_id = 'product-images' );

-- Policy to allow authenticated users to upload product images
-- CREATE POLICY "Authenticated Upload" ON storage.objects FOR INSERT WITH CHECK ( bucket_id = 'product-images' AND auth.role() = 'authenticated' );

-- Policies for Supabase Storage bucket: payment-receipts
-- Fix 403 "row-level security policy" when uploading receipt images

begin;

-- Allow public read access (if bucket is intended to be public for viewing)
create policy if not exists "Public read payment-receipts"
on storage.objects
for select
using (bucket_id = 'payment-receipts');

-- Allow authenticated users to upload into this bucket
create policy if not exists "Authenticated upload payment-receipts"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'payment-receipts');

-- Optional: allow authenticated update if using upsert or need overwrites
create policy if not exists "Authenticated update payment-receipts"
on storage.objects
for update
to authenticated
using (bucket_id = 'payment-receipts')
with check (bucket_id = 'payment-receipts');

commit;

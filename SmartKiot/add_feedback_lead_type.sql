-- Migration: Cho phép lead_type = 'feedback' trong bảng website_leads
-- Chạy trong Supabase SQL Editor

-- Nếu có CHECK constraint trên lead_type, cập nhật để cho phép 'feedback'
ALTER TABLE website_leads
DROP CONSTRAINT IF EXISTS website_leads_lead_type_check;

ALTER TABLE website_leads
ADD CONSTRAINT website_leads_lead_type_check
CHECK (lead_type IN ('consultation', 'appointment', 'feedback', 'partner'));

-- Đảm bảo cột note có thể update được
ALTER TABLE website_leads
ALTER COLUMN note TYPE TEXT;

NOTIFY pgrst, 'reload config';

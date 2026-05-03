-- ============================================================
-- Enable Realtime for website_leads table
-- Chạy lệnh này trong Supabase SQL Editor để nhận thông báo
-- khi có khách hàng mới từ website
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE website_leads;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload config';

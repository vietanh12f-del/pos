-- Thêm cột import_batch_number vào bảng products để đánh dấu số đợt nhập
ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS import_batch_number INTEGER;

-- Comment
COMMENT ON COLUMN public.products.import_batch_number IS 'Số đợt nhập của sản phẩm (nếu bật tính năng đánh dấu nhiều đợt nhập)';

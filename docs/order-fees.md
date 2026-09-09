# Phí đơn hàng và hoàn ứng nhân viên

## Trước khi sử dụng

Áp dụng `supabase/migrations/20260910010000_order_fees.sql` vào đúng dự án Supabase trước khi chạy bản ứng dụng mới. Phiên phát triển này chưa có kết nối quản trị để áp dụng migration vào dữ liệu thật.

Migration thêm `orders.order_fees`, danh mục phí theo cửa hàng, trạng thái hoàn ứng và nhật ký hoàn/hoàn tác. Đơn cũ mặc định không có phí. Cần nâng cấp ứng dụng trên các thiết bị trước khi sửa đơn có phí để tránh phiên bản cũ tính lại tổng đơn mà bỏ phần phí thu hộ.

## Quy ước tính tiền

- Phí độc lập với hàng hoá, không thay đổi số lượng tồn kho hoặc giá vốn. Phí dịch vụ trong tính năng này là số tiền thu/chi hộ, không tự cộng VAT hay áp dụng giảm giá hàng hoá lên phí.
- Shop chịu: giữ nguyên tổng khách phải thanh toán, trừ phí một lần khi tính lợi nhuận.
- Khách chịu, công ty/nhân viên ứng: cộng vào tổng cần thu, loại phần thu hộ khỏi doanh thu bán hàng.
- Khách trả trực tiếp bên dịch vụ: không cộng vào tiền shop cần thu, không tính doanh thu.
- Thực thu vẫn là toàn bộ tiền đã nhận, bao gồm thu hộ. Với thanh toán một phần, phí thu hộ đã nhận phân bổ theo tỷ lệ tiền đã thu / tổng phải trả; phần này bị loại khỏi lợi nhuận theo thực thu. Bộ tính doanh thu không phụ thuộc trạng thái thu tiền.
- Hoàn ứng chỉ thay đổi khoản cần hoàn nhân viên, không ghi thêm chi phí vận hành và không thay đổi tổng đơn/doanh thu/lợi nhuận.

## Hoàn ứng

Chỉ chủ shop được đọc bảng tổng hợp và xác nhận hoàn/hoàn tác (kiểm tra cả phía máy chủ). Danh sách dùng ID đơn để liên kết, STT để hiển thị; nhóm theo `store_members.id`, giữ tên nhân viên tại thời điểm ứng.

Các khoản chưa hoàn tính toàn bộ lịch sử, bao gồm khoản liên quan đơn đã huỷ/xoá mềm. Chọn từng khoản hoặc toàn bộ khoản của một nhân viên, bấm “Đã hoàn …”. Chỉ bấm sau khi thực tế đã trả tiền. Phiên bản này hoàn trọn từng khoản, không chia nhỏ một khoản.

Một lần hoàn nhiều khoản được lưu trong một giao dịch DB. Lặp lại khoản đã hoàn bị từ chối. Hoàn tác áp dụng cho cả lần hoàn đó; nhật ký giữ tổng tiền, ID khoản phí, người xác nhận và thời điểm. Không thể thay đổi/xoá khoản đã hoàn trước khi hoàn tác.

## Kiểm tra

- `python3 scripts/verify_order_fees.py`: kiểm tra phép tính shop chịu/thu hộ/trả trực tiếp, phí hỗn hợp, thanh toán một phần, dữ liệu không hợp lệ, giữ ID nhân viên khi encode/decode.
- Build iOS Simulator bằng Xcode.
- Migration đã được kiểm tra cú pháp SQL và PL/pgSQL bằng pglast; chưa chạy giao dịch trên Supabase thật.

Sau khi áp dụng migration, kiểm tra bằng tài khoản chủ shop và nhân viên:
1. Đơn 500.000đ + phí 30.000đ: shop chịu → cần thu 500.000đ, doanh thu sau phí 470.000đ.
2. Khách chịu/nhân viên ứng → cần thu 530.000đ, doanh thu 500.000đ, cần hoàn nhân viên 30.000đ.
3. Khách trả trực tiếp → shop chỉ thu 500.000đ, không có khoản hoàn ứng.
4. Lưu/mở lại/sửa đơn, kiểm tra QR, phiếu in và thống kê.
5. Hoàn hai khoản cùng người, xác nhận ở thiết bị khác, thử xác nhận lại và hoàn tác. Tổng tiền đơn phải giữ nguyên.
6. Tài khoản nhân viên không được gọi các RPC hoàn ứng của chủ shop; không được truy cập cửa hàng khác.
7. Đổi bộ lọc ngày ở Tổng quan không làm mất khoản ứng cũ. Xoá mềm đơn còn ứng không làm mất nghĩa vụ hoàn.

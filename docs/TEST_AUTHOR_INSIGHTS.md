# Kiểm thử Studio tác giả, thống kê, bình luận và đánh giá

## 1. Cập nhật bản mới

1. Giữ nguyên PostgreSQL database `comic_db`.
2. Khởi động Backend bằng `run_backend_windows.bat`. Với `spring.jpa.hibernate.ddl-auto=update`, Hibernate tạo các bảng mới `comic_comments` và `comic_reviews`.
3. Chạy Frontend bằng Android Studio sau `flutter pub get`.
4. Nếu Studio trả HTTP 401 sau khi đổi `JWT_SECRET`, đăng xuất và đăng nhập lại. Bản này sẽ xóa phiên cache khi `GET /api/auth/me` trả 401; Studio cũng có nút **Đăng nhập lại** cho trường hợp lỗi phát hiện trong phiên.

## 2. Kiểm thử bình luận/đánh giá

1. Đăng nhập bằng tài khoản Reader đã xác minh email.
2. Mở chi tiết một truyện có thể đọc.
3. Trong khu vực **Đánh giá & bình luận**, chọn 1–5 sao và gửi một nhận xét; xác nhận điểm trung bình và số đánh giá cập nhật.
4. Gửi bình luận; xác nhận bình luận xuất hiện trong danh sách gần đây sau khi tải lại.
5. Gửi đánh giá lần thứ hai bằng cùng tài khoản; cần cập nhật đánh giá cũ thay vì tạo bản ghi đánh giá thứ hai cho cùng truyện.
6. Dùng tài khoản Reader khác; không được sửa danh tính người gửi bằng tham số trong request, vì Backend lấy user ID từ JWT.

## 3. Kiểm thử khu vực Author

1. Đăng nhập bằng tài khoản có role `AUTHOR` và có ít nhất một truyện được tạo từ tài khoản đó.
2. Mở tab **Tôi**. Không được hiển thị thẻ tổng hợp “Thống kê tác giả”; khu vực **Sáng tác & phát triển** phải có đúng bốn thẻ: Người theo dõi, Thống kê truyện, Studio tác giả và Trạng thái duyệt.
3. Mở **Thống kê truyện**; kiểm tra số lượt đọc, độc giả, bình luận, số đánh giá và điểm sao trung bình lấy từ `GET /api/author/dashboard`.
4. Dùng một tài khoản Reader khác theo dõi bút danh của tác giả, sau đó gửi bình luận và đánh giá cho một truyện do tác giả sở hữu.
5. Quay lại Author: chấm đỏ phải xuất hiện trên tab Tôi, thẻ Studio tác giả và bìa truyện có phản hồi mới. Mở truyện → **Quản lý truyện → Bình luận & đánh giá**; thấy phản hồi và điểm trung bình cập nhật, rồi chấm đỏ của phản hồi đã xem được xóa sau khi tải lại.
6. Nếu chưa có hoạt động độc giả, số liệu là 0 và hiển thị trạng thái chưa có bình luận/đánh giá; không có dữ liệu giả được sinh ra.

## 4. Kiểm thử 401/403

- Token hết hạn hoặc không khớp JWT secret hiện hành: Backend trả 401; khi khởi tạo phiên lại, Flutter xóa session cache và yêu cầu đăng nhập. Trong Studio, nút **Đăng nhập lại** cũng xóa phiên và trở về luồng đăng nhập.
- Token hợp lệ nhưng vai trò không đủ (ví dụ Reader gọi `/api/author/comics`): Backend phải trả 403, không phải 401. Đăng ký quyền Author qua luồng **Trở thành tác giả** hoặc kiểm tra role trong bảng `users`.
- Không gửi hoặc ghi token/JWT secret/mật khẩu vào log hoặc ảnh chụp màn hình.

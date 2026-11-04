# Kế hoạch kiểm thử phân quyền Smart Story (RBAC)

Tài liệu này là checklist kiểm thử thủ công sau khi khởi động Backend và Flutter. Các quyền phải được kiểm tra ở Backend; ẩn nút trên giao diện không được coi là kiểm thử phân quyền thành công.

## 1. Khởi tạo tài khoản Admin lần đầu

1. Trong pgAdmin, tạo database `comic_db` (nếu chưa có).
2. Trên Windows, mở PowerShell tại thư mục dự án và chạy `backend/tools/setup_backend_env_windows.ps1`. Nhập thông tin PostgreSQL. Script tạo `backend/.env.local` và JWT secret ngẫu nhiên.
3. Chạy `backend/tools/bootstrap_admin_windows.ps1`. Nhập email, username, tên hiển thị và mật khẩu Admin tối thiểu 16 ký tự.
4. Script khởi động Spring Boot và tạo tài khoản Admin bootstrap một lần. Giữ cửa sổ đó làm Backend đang chạy; không mở thêm một Backend khác cùng cổng 8080.
5. Các lần sau, chạy `backend/tools/run_backend_windows.ps1` hoặc `run_backend_windows.bat` ở thư mục gốc. Không lưu mật khẩu Admin vào source code hoặc `.env.local`.

Không có credential Admin dùng chung được ghi trong ZIP. Điều này có chủ đích: credential cố định trong dự án sẽ trở thành cửa hậu nếu ZIP bị chia sẻ.

## 2. Kiểm thử vai trò Reader và Author

1. Đăng ký tài khoản bình thường và cố tình gửi thêm trường JSON `"role":"ADMIN"`. Kết quả đăng ký vẫn phải trả về `READER`.
2. Xác minh email rồi đăng nhập; response `user.role` phải là `READER`.
3. Với JWT Reader, `GET /api/moderation/queue` và `GET /api/admin/users` phải trả về `403`.
4. Gọi `POST /api/auth/become-author` cùng Bearer token hợp lệ và JSON `{"penName":"Bút danh thử","experience":"","termsAccepted":true}`. Response phải trả role `AUTHOR` và token mới.
5. Với JWT Author, `POST /api/author/comics` được phép. Một truyện mới phải có `moderationStatus=PENDING` và trường chủ sở hữu nội bộ gắn với ID Author hiện tại.
6. Reader không được tạo/sửa/xóa truyện qua API Author. Author A không được sửa hoặc ẩn truyện của Author B; Backend phải trả `403`.
7. Đăng nhập tài khoản AUTHOR: ứng dụng vẫn mở giao diện đọc bình thường với đủ 5 tab; trong tab Tôi xuất hiện mục **Studio tác giả**. Tài khoản AUTHOR không còn thấy nút “Trở thành tác giả”.
8. Vào Studio tác giả, tạo truyện mới, chọn ảnh bìa, mở truyện, tạo chương và tải ảnh JPG/PNG/WebP. Kiểm tra dữ liệu trong PostgreSQL và file nằm trong `backend/uploads`; trạng thái truyện phải là `PENDING` sau thay đổi.
9. Đăng nhập Reader: không thấy Studio và gọi API `/api/author/comics` phải bị từ chối.

## 3. Kiểm thử Admin cấp Moderator

1. Đăng nhập tài khoản bootstrap Admin.
2. Gọi `GET /api/admin/users`; danh sách quản lý vai trò không trả thông tin tài khoản `ADMIN` bootstrap.
3. Với ID của một Reader, gọi `PATCH /api/admin/users/{id}/role` cùng JSON `{"role":"MODERATOR"}`.
4. Đăng xuất/đăng nhập tài khoản đó hoặc mở lại ứng dụng. `GET /api/auth/me` phải phản ánh role `MODERATOR`.
5. Moderator được gọi `GET /api/moderation/queue`, ra quyết định duyệt/giới hạn tuổi/ẩn/từ chối và cập nhật báo cáo. Moderator không được gọi `GET /api/admin/users` hoặc `PATCH /api/admin/users/{id}/role`.
6. Đăng nhập Moderator: trang đầu phải là Trung tâm Moderator, có tổng quan hàng chờ và báo cáo; không có tab Tôi hoặc nút mở trang đọc truyện. Nút đăng xuất trên thanh tiêu đề phải xóa phiên, đóng các trang con và trở về màn hình đăng nhập.
7. Đăng nhập Admin: trang đầu là Bảng điều khiển Admin, có Quản trị tài khoản và Trung tâm kiểm duyệt; không có lối tắt sang giao diện đọc. Đăng xuất từ dashboard, Trung tâm kiểm duyệt và Quản lý tài khoản đều phải trở về màn hình đăng nhập.
8. Mở Quản lý tài khoản, tìm bằng tên/username/email, lọc theo Reader/Author/Moderator, chuyển trang và đổi kích thước trang. Kiểm thử với nhiều tài khoản để xác nhận Backend chỉ trả về trang đã yêu cầu qua `/api/admin/users/search`.
9. Thử cấp role `AUTHOR` hoặc `ADMIN` qua endpoint đổi vai trò: Backend phải từ chối; AUTHOR chỉ kích hoạt qua `/api/auth/become-author`. Thử đổi role tài khoản Admin bootstrap: Backend cũng phải từ chối.

## 4. Kiểm thử kiểm duyệt và giới hạn độ tuổi

1. Truyện tạo mới hoặc được cập nhật phải chuyển về `PENDING`; Reader không được thấy truyện đó trong danh sách công khai hoặc đọc chương.
2. Đăng nhập Moderator/Admin, duyệt truyện bằng `APPROVE` hoặc gắn nhãn `13+`, `16+`, `18+` qua màn hình **Trung tâm kiểm duyệt**.
3. Truyện đã duyệt `ALL_AGES` đọc được công khai. Truyện có nhãn tuổi chỉ đọc được bởi tài khoản có ngày sinh đủ tuổi; người chưa đủ tuổi hoặc không có ngày sinh bị từ chối.
4. Trong **Trung tâm kiểm duyệt**, nhấn **Xem nội dung** ở truyện đang chờ/bị báo cáo. Bản xem trước gồm mô tả, chương và ảnh trang; chỉ Moderator/Admin được mở endpoint `GET /api/moderation/comics/{id}/preview`.
5. Thử mở trực tiếp URL `/uploads/...` của ảnh thuộc truyện đang `HIDDEN`/`PENDING` hoặc truyện có nhãn vượt tuổi: quyền kiểm tra ảnh phải trả về từ chối, không chỉ chặn API JSON.
6. Reader gửi `POST /api/comics/{id}/reports` với `reasonCode` là `COPYRIGHT`, `AGE_RESTRICTION`, `INAPPROPRIATE` hoặc `OTHER`. Báo cáo phải xuất hiện trong hàng chờ Moderator/Admin và có thể xử lý.
7. Xem `GET /api/admin/audit` để kiểm tra nhật ký thay đổi vai trò và quyết định kiểm duyệt.

## 5. Kiểm tra bảo vệ bí mật

- Mật khẩu Admin không xuất hiện trong source, `application.properties`, `.env.local`, log khởi động hoặc API quản lý tài khoản.
- PostgreSQL chỉ giữ `password_hash` (BCrypt), không lưu mật khẩu thô.
- `JWT_SECRET` lấy từ môi trường cục bộ và có tối thiểu 32 byte. Nếu thiếu, Backend phải dừng khởi động thay vì dùng khóa yếu mặc định.
- Không chia sẻ `.env.local` hoặc mở cổng PostgreSQL 5432 trực tiếp ra Internet.

# Comic Reading Backend

- Java 17 target (run with JDK 21 recommended) + Spring Boot 3.2.5 + Spring Data JPA + PostgreSQL.
- Port mặc định: `8080`.
- Tạo database `comic_db`, cập nhật password trong `src/main/resources/application.properties` hoặc cung cấp biến môi trường `DB_PASSWORD`, rồi chạy `mvn clean spring-boot:run`.
- API docs: `http://localhost:8080/swagger-ui.html`.
- Security note: backend requires a private `JWT_SECRET` of at least 32 bytes; use the Windows scripts below to generate/store local configuration.
- Các thao tác yêu thích/lịch sử/đã mở khóa được lưu trong PostgreSQL và dùng chung giữa các thiết bị cùng trỏ đến backend này.
- RBAC enforce ở Backend: `READER` mặc định khi đăng ký; chỉ thao tác đăng ký trở thành tác giả mới chuyển `READER` thành `AUTHOR`; `MODERATOR` chỉ do Admin cấp; `ADMIN` bootstrap không thể được tạo/đổi qua API thông thường.
- Các vai trò được kiểm tra từ tài khoản PostgreSQL mỗi request; token cũ không giữ quyền đã bị thu hồi. Người dùng chỉ được đọc/sửa dữ liệu cá nhân của mình. Tác giả chỉ quản lý truyện thuộc tài khoản mình; metadata và ảnh bìa được lưu ngay, còn chương mới/sửa đổi/bổ sung ảnh chuyển về `PENDING`.
- Moderator/Admin quản lý hàng chờ, báo cáo bản quyền/độ tuổi, duyệt, gắn nhãn `13+` / `16+` / `18+`, ẩn hoặc từ chối nội dung. API ảnh `/uploads/**` cũng kiểm tra trạng thái duyệt và tuổi để tránh bỏ qua gate bằng cách mở URL trực tiếp.
- Thanh toán hiện vẫn là mô phỏng, không phải cổng thanh toán thật. Trước khi triển khai Internet cần HTTPS, rate-limit/khóa đăng nhập, quy trình khôi phục mật khẩu, sao lưu, giám sát và kiểm thử bảo mật độc lập.

- Theo dõi tác giả: `GET /api/users/{userId}/authors`, `POST /api/authors/follow`, `DELETE /api/authors/follow?userId={id}&authorName={name}`. Bảng `followed_authors` sẽ được Hibernate tạo/cập nhật tự động.


## Công cụ nhập truyện tự động

Để nhập truyện từ thư mục, ZIP/CBZ hoặc PDF (PDF được chuyển thành ảnh), xem `tools/README_IMPORTER.md`. Trên Windows, chạy `tools/run_importer_windows.bat`. Công cụ ghi dữ liệu vào PostgreSQL và lưu ảnh trong `uploads/imported/`; PostgreSQL phải đang chạy và schema phải được tạo bởi lần khởi động Spring Boot đầu tiên. Khi chạy Spring Boot, đặt working directory là thư mục `backend` để đường dẫn `uploads` đúng với thư mục ảnh.


## Thiết lập bảo mật và tài khoản Admin bootstrap (Windows)

1. Mở PowerShell tại `backend/tools` và chạy `./setup_backend_env_windows.ps1`. Script hỏi mật khẩu PostgreSQL, tạo JWT secret ngẫu nhiên và lưu cấu hình cục bộ tại `backend/.env.local`; file này bị Git ignore và ACL được giới hạn cho tài khoản Windows hiện tại.
2. Lần đầu tạo Admin, chạy `./bootstrap_admin_windows.ps1`. Tự nhập email, username, tên hiển thị và một mật khẩu Admin tối thiểu 16 ký tự. Mật khẩu không được ghi vào code hay `.env.local`; Backend chỉ lưu hash BCrypt trong PostgreSQL. Không có mật khẩu Admin mặc định công khai.
3. Khởi động Backend các lần sau bằng `./run_backend_windows.ps1`. Khi chạy trực tiếp từ IntelliJ, hãy khai báo các biến môi trường từ `.env.local` trong Run Configuration; nếu thiếu `JWT_SECRET`, Backend sẽ dừng thay vì dùng khóa yếu mặc định.
4. Không chia sẻ `.env.local`, không commit file này, không gửi ảnh chứa bí mật. Tài khoản Admin bootstrap không thể bị hạ quyền qua API thông thường; API phân quyền không cho tạo thêm Admin.

## Vai trò và API quản trị

- `READER`: vai trò mặc định sau đăng ký và xác minh email.
- `AUTHOR`: người dùng tự chọn mục **Trở thành tác giả** trong hồ sơ; gửi bút danh và cam kết, Backend cấp quyền và phát JWT mới. Truyện mới/tác phẩm chỉnh sửa ở trạng thái `PENDING`.
- `MODERATOR`: chỉ Admin cấp tại **Quản trị tài khoản**. Có quyền xem hàng chờ và báo cáo, duyệt, phân loại độ tuổi, ẩn/từ chối; không quản lý vai trò.
- `ADMIN`: được bootstrap riêng từ `ADMIN_BOOTSTRAP_*` trong môi trường tiến trình. API thông thường không thể gán vai trò ADMIN.

Endpoints chính (cần `Authorization: Bearer <JWT>` trừ đăng ký/đăng nhập/xác minh):

- `POST /api/auth/become-author` — đăng ký quyền tác giả (`penName`, `experience`, `termsAccepted=true`).
- `POST/PUT /api/author/comics`, `POST /api/author/comics/{id}/chapters`, `PUT /api/author/chapters/{id}/content`, `POST /api/author/chapters/{id}/pages`, `POST /api/author/comics/{id}/import` — tác giả quản lý metadata và nội dung chương của mình; importer tích hợp hỗ trợ ảnh, ZIP/CBZ, PDF, TXT/MD và thư mục từ desktop.
- `POST /api/comics/{id}/reports` — báo cáo `COPYRIGHT`, `AGE_RESTRICTION`, `INAPPROPRIATE`, `OTHER`.
- `GET /api/moderation/queue`, `GET /api/moderation/chapters/{id}/preview`, `POST /api/moderation/chapters/{id}/decision`, các endpoint preview/decision cấp truyện và báo cáo — Moderator/Admin đọc toàn bộ chương chữ hoặc từng ảnh trang, gán giới hạn tuổi và xử lý báo cáo.
- `GET /api/admin/users`, `PATCH /api/admin/users/{id}/role` với role `READER`, `AUTHOR` hoặc `MODERATOR`; không thể tạo Admin qua endpoint này.
- `GET /api/admin/audit` — nhật ký thay đổi vai trò và quyết định kiểm duyệt gần nhất.

Câu lệnh bootstrap hỏi thông tin, không ghi sẵn username/password vào ZIP. Giữ thông tin đăng nhập Admin trong password manager riêng. Với dữ liệu cũ, metadata truyện được coi là `APPROVED` vì không duyệt ở cấp metadata; các chương cũ chưa có trạng thái kiểm duyệt được chuyển sang `PENDING` để Moderator/Admin xem lại. Importer tạo metadata `APPROVED` và chương `PENDING`.

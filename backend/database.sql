-- Chạy một lần bằng tài khoản PostgreSQL có quyền tạo database.
-- Nếu database comic_db đã tồn tại, bỏ qua câu lệnh CREATE DATABASE.
CREATE DATABASE comic_db;
-- Hibernate sẽ tự tạo/cập nhật các bảng khi ứng dụng Spring Boot khởi động.

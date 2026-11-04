# Kiểm tra dự án sau khi giải nén

## Frontend Flutter (PowerShell tại thư mục `frontend`)

```powershell
flutter doctor -v
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Nếu `flutter test` báo không có test, đây chưa phải lỗi build; cần bổ sung test tự động để kiểm thử chức năng. Cảnh báo Visual Studio về C++ không ảnh hưởng build Android.

## Backend Spring Boot (Terminal tại thư mục `backend`)

```powershell
java -version
mvn -version
mvn clean verify
mvn spring-boot:run
```

Backend dùng JDK 21 để chạy, trong khi mã được biên dịch với target Java 17. PostgreSQL phải chạy, database `comic_db` phải tồn tại, và `spring.datasource.password` hoặc biến môi trường `DB_PASSWORD` phải đúng với mật khẩu PostgreSQL trên máy.

## Kiểm tra API

Khi backend đã khởi động, mở PowerShell thứ hai:

```powershell
Invoke-RestMethod -Uri "http://localhost:8080/api/comics"
```

API phải trả về dữ liệu JSON. Android Emulator gọi API tại `http://10.0.2.2:8080/api`, không dùng `localhost` bên trong emulator.

## Các chỉnh sửa trong bản này

- Android Gradle Plugin đã nâng từ `8.7.3` lên `8.11.1`, đạt ngưỡng tối thiểu Flutter báo yêu cầu.
- Kotlin Gradle Plugin đã nâng từ `2.1.0` lên `2.2.20` để phù hợp với Flutter 3.47.x.
- Gradle Wrapper sử dụng `8.14.4`. JDK 21 phù hợp với Gradle 8.x của dự án.
- `settings.gradle` sử dụng `java.util.Properties()` đầy đủ để tránh IDE báo không nhận diện `Properties`.
- `WebConfig` dùng URI thư mục upload tuyệt đối để phục vụ file tốt hơn trên Windows.
- SQLite gộp vị trí đọc đang chờ đồng bộ của cùng người dùng/truyện/chương để tránh hàng đợi tăng không giới hạn khi offline.
- Script `setup_android_windows.bat` không chạy lại `flutter create` nếu Android scaffold đã tồn tại.

## Giới hạn xác minh

Trong môi trường tạo ZIP không có Flutter SDK và Maven để chạy `flutter analyze`, build APK hoặc `mvn clean verify`. Hãy chạy các lệnh trên máy phát triển; nếu có lỗi, dùng dòng `[ERROR]` của Maven hoặc phần bắt đầu từ `FAILURE: Build failed` của Gradle để xử lý tiếp.


## Kiểm thử luồng Studio tác giả và kiểm duyệt từng chương

1. Đăng nhập bằng tài khoản `AUTHOR`, mở **Studio tác giả** và tạo truyện với ảnh bìa cùng độ tuổi đề xuất. Thông tin truyện phải được lưu ngay; không tạo mục chờ duyệt truyện chỉ vì thêm/sửa metadata hoặc bìa.
2. Vào truyện → **Quản lý chương** → tạo chương `TEXT` có nội dung. Chương phải xuất hiện trong hàng chờ `PENDING`.
3. Tạo chương `IMAGE`, chọn nhiều ảnh theo tên `001.jpg`, `002.jpg`, `010.jpg`, hoặc dùng **Nhập truyện từ file / thư mục** với thư mục chương, ZIP/CBZ, PDF, TXT/MD. Xác minh thứ tự tự nhiên và số lượng trang.
4. Đăng nhập bằng `MODERATOR` hoặc `ADMIN`, mở Trung tâm kiểm duyệt → **Đọc / xem nội dung**. Chương chữ phải hiển thị toàn bộ văn bản có thể cuộn/chọn; chương hình phải hiển thị từng trang ảnh có số trang.
5. Duyệt chương với `ALL_AGES`, `13+`, `16+`, `18+`; với thao tác giới hạn tuổi/ẩn/từ chối phải nhập căn cứ. API phải ghi trạng thái và nhật ký kiểm duyệt.
6. Đăng nhập bằng `READER` và xác minh chương `PENDING`, `HIDDEN`, `REJECTED` hoặc chương không phù hợp ngày sinh không thể đọc qua API chương hay URL ảnh trực tiếp.
7. Sửa nội dung chương chữ hoặc thêm trang ảnh sau khi duyệt; chương phải chuyển lại `PENDING` và cần kiểm duyệt lại.
8. Từ giao diện đọc, xác minh chương `TEXT` mở được và TTS có thể đọc nội dung; chương `IMAGE` hiển thị trang ảnh như trước.

## Định dạng nhập tích hợp trong Studio

- Ảnh nhiều file: tạo một chương (sắp theo thứ tự tự nhiên).
- ZIP/CBZ: các thư mục như `Chapter 1`, `Chương 2` được tách thành nhiều chương.
- PDF: chế độ `AUTO` trích xuất văn bản có thể chọn; chọn `IMAGE` để chuyển từng trang PDF thành JPEG cho truyện hình; chọn `TEXT` cho PDF có lớp văn bản.
- TXT/MD: nội dung được đưa vào chương chữ để Moderator đọc và kiểm duyệt.
- Nguồn nhập không được chứa nội dung mà người tải lên không có quyền sử dụng hoặc phân phối.

# Công cụ nhập truyện tự động cho Smart Story

Công cụ `import_comics.py` thêm một bộ truyện vào **Backend Spring Boot + PostgreSQL hiện có**. Công cụ chỉ bổ sung file trong `backend/uploads/imported/` và bản ghi mới trong các bảng `comics`, `comic_tags`, `chapters`, `pages`; không sửa/xoá các truyện đang có hoặc thay đổi code Flutter/Backend đang chạy.

## Hỗ trợ

- Chọn một thư mục truyện đã giải nén.
- Chọn một file `.zip` hoặc `.cbz` (Comic Book ZIP). Có kiểm tra đường dẫn trong archive để tránh giải nén ra ngoài thư mục tạm.
- Chọn trực tiếp một file PDF.
- Ảnh JPG/JPEG, PNG, WebP, BMP, GIF, TIFF.
- PDF bên trong thư mục/ZIP/CBZ được chuyển từng trang sang JPEG. Ảnh đầu ra được thu nhỏ cạnh dài tối đa khoảng 2400 px và lưu ở chất lượng JPEG cao để giảm dung lượng.
- Phát hiện thứ tự tự nhiên của tên file (`1, 2, 10` thay vì `1, 10, 2`).
- Đọc các thư mục con như từng chương; PDF/ZIP/CBZ nằm trực tiếp ở thư mục gốc cũng được coi là từng chương.
- Tạo metadata JSON cho mỗi lần nhập trong thư mục ảnh để tiện kiểm tra.

## Cấu trúc nguồn nên dùng

Khuyến nghị một bộ truyện có dạng:

```text
Truyen-Mau/
├── cover.jpg
├── Chapter 1/
│   ├── 001.jpg
│   ├── 002.jpg
│   └── 003.jpg
├── Chapter 2.cbz
└── Chapter 3.pdf
```

Tên ảnh bìa nên là `cover.jpg`, `poster.png`, `thumbnail.jpg`, `thumb.png` hoặc `folder.jpg`. Nếu không tìm thấy, công cụ sẽ cho chọn bìa thủ công; nếu bỏ qua, trang đầu sẽ được dùng làm bìa và vẫn được giữ trong nội dung chương. Nếu các ảnh trang được đặt trực tiếp ở thư mục gốc, công cụ coi đó là Chương 1. Đối với nhiều chương, nên dùng thư mục riêng cho từng chương hoặc một file PDF/CBZ/ZIP cho mỗi chương.

## Cài đặt và chạy trên Windows

Yêu cầu:

- Python 3.10 trở lên và thêm Python vào `PATH`.
- PostgreSQL Server đang chạy, có database `comic_db`.
- Backend đã khởi động ít nhất một lần trên database đó để Hibernate tạo các bảng.
- Mật khẩu PostgreSQL đúng.

### Cách đơn giản (khuyên dùng)

1. Khởi động PostgreSQL.
2. Trên Windows, từ thư mục dự án chạy `run_backend_windows.bat` (hoặc `backend/tools/run_backend_windows.ps1`) để nạp `backend/.env.local`. Đợi ứng dụng khởi động thành công và giữ Backend chạy để ảnh mới có thể được tải qua `/uploads/...`.
3. Nhấp đúp `backend/tools/run_importer_windows.bat`.
4. Công cụ sẽ cài các thư viện cần thiết (Pillow, PyMuPDF, psycopg) rồi hỏi bạn chọn thư mục hay file ZIP/CBZ/PDF.
5. Nhập tên truyện, tác giả, mô tả, thể loại, trạng thái và thông tin kết nối PostgreSQL. Mật khẩu được nhập dạng ẩn.
6. Khi thấy `NHẬP TRUYỆN THÀNH CÔNG`, mở Smart Story và làm mới danh sách truyện.

### Cài thư viện thủ công

Mở PowerShell ở thư mục `backend/tools`:

```powershell
python -m pip install -r requirements-importer.txt
python import_comics.py
```

Bạn cũng có thể chỉ định nguồn rõ ràng:

```powershell
python import_comics.py --source "D:\Truyen\Truyen-Mau.cbz"
python import_comics.py --source "D:\Truyen\Truyen-Mau" --title "Truyện Mẫu" --author "Tác giả"
```

Các trường không truyền qua tham số vẫn được hỏi tương tác. Để tránh để lộ mật khẩu trong lịch sử lệnh, không nên dùng `--db-password`; có thể đặt biến môi trường `COMIC_DB_PASSWORD` trong phiên PowerShell hiện tại:

```powershell
$env:COMIC_DB_PASSWORD = "MAT_KHAU_POSTGRES"
python import_comics.py
```

Các biến tuỳ chọn khác: `COMIC_DB_HOST`, `COMIC_DB_PORT`, `COMIC_DB_NAME`, `COMIC_DB_USER`. Tránh truyền mật khẩu trong tham số dòng lệnh vì lịch sử shell có thể lưu giá trị đó; để công cụ hỏi mật khẩu dạng ẩn.

## Dữ liệu được tạo

- `comics`: tên, tác giả, mô tả, URL bìa, chủ sở hữu và thời điểm nhập. Metadata/ảnh bìa được lưu ngay với `moderation_status=APPROVED`; đây không phải quyết định duyệt nội dung chương. Độ tuổi đề xuất mặc định `ALL_AGES` trong script độc lập.
- Bắt buộc gán chủ sở hữu bằng `--owner-user-id <ID>` hoặc nhập ID khi công cụ hỏi. Tài khoản đó phải có vai trò `AUTHOR` hoặc `ADMIN`; không cho phép tạo truyện không có chủ sở hữu vì sẽ không thể kiểm soát quyền chỉnh sửa.
- `comic_tags`: mỗi thể loại một bản ghi.
- `chapters`: chương được đánh số theo thứ tự tự nhiên, không VIP, giá 0, `content_type=IMAGE` và `moderation_status=PENDING`; từng chương cần được Moderator/Admin xem toàn bộ trang ảnh và gán độ tuổi trước khi công khai.
- `pages`: từng ảnh trong chương có số trang liên tục từ 1.
- File ảnh lưu vào `backend/uploads/imported/<ten-truyen>-<thoi-gian>/`.

URL bìa và trang ảnh được lưu dạng tương đối, ví dụ:

```text
/uploads/imported/truyen-mau-20261015-150000/cover.jpg
```

Frontend Flutter đã ghép đường dẫn tương đối với host từ `COMIC_API_URL`, nên hoạt động với Android Emulator (`http://10.0.2.2:8080/api`) hoặc điện thoại thật (đặt `COMIC_API_URL` thành `http://IP_LAN_CỦA_MÁY_TÍNH:8080/api`) mà không phải nhập lại URL ảnh vào PostgreSQL.

**Chú ý:** chạy lại script sẽ tạo một truyện mới, không cập nhật truyện đã nhập. Chỉ nhập nội dung mà bạn tự sở hữu, được cấp phép hoặc có quyền phân phối.

## Kiểm tra sau khi nhập

1. Metadata truyện có thể xuất hiện ngay, nhưng các chương mới ở trạng thái `PENDING` nên độc giả thường chưa đọc được nội dung. Đăng nhập tài khoản có quyền kiểm duyệt và mở **Trung tâm kiểm duyệt** để xem từng chương và gán độ tuổi.
2. Sau khi duyệt, trong trình duyệt trên máy tính mở `http://localhost:8080/api/comics`, tìm truyện mới.
3. Lấy `id` trong kết quả và mở `http://localhost:8080/api/comics/ID_TRUYỆN` để kiểm tra chương.
3. Mở ảnh bìa tại `http://localhost:8080` cộng với đường dẫn tương đối đã lưu (ví dụ `http://localhost:8080/uploads/imported/.../cover.jpg`).
4. Mở chương thông qua API `http://localhost:8080/api/chapters/ID_CHƯƠNG` để kiểm tra `pages` và thứ tự ảnh.
5. Với điện thoại thật, đặt `COMIC_API_URL` thành `http://IP_LAN_CỦA_MÁY_TÍNH:8080/api`; máy tính và điện thoại phải cùng mạng, và Windows Firewall phải cho phép cổng 8080. Không cần đổi URL đã lưu trong PostgreSQL.

## Xử lý lỗi thường gặp

- **`connection refused` / không kết nối được PostgreSQL:** kiểm tra dịch vụ PostgreSQL, host/port và database `comic_db`.
- **`password authentication failed`:** nhập đúng mật khẩu của user PostgreSQL; đây là mật khẩu database, không phải mật khẩu pgAdmin.
- **`relation ... does not exist` / thiếu bảng:** chạy Backend thành công ít nhất một lần với `spring.jpa.hibernate.ddl-auto=update`, rồi chạy lại importer.
- **Thiếu thư viện Python:** vào `backend/tools`, chạy `python -m pip install -r requirements-importer.txt`.
- **Không mở được ảnh trên điện thoại:** kiểm tra `COMIC_API_URL`, IP LAN hiện tại, Windows Firewall và thư mục làm việc Backend. Khi chạy Spring Boot, thư mục làm việc nên là `backend` để `app.upload.dir=uploads` trỏ đến đúng `backend/uploads`.
- **PDF có mật khẩu hoặc lỗi:** mở khoá/lưu thành PDF không mã hoá rồi nhập lại.
- **Thứ tự chương/trang sai:** đổi tên thành dạng `Chapter 1`, `Chapter 2`, `001.jpg`, `002.jpg`; tên số có số 0 ở đầu được hỗ trợ.
- **Lỗi khi nhập database:** công cụ huỷ transaction PostgreSQL và dọn thư mục ảnh được tạo cho lần nhập lỗi; những truyện cũ không bị thay đổi.

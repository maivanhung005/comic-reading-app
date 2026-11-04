# Smart Comic Reader — Flutter MVVM + Clean Architecture + Spring Boot + PostgreSQL


## Cập nhật giao diện và quản trị tài khoản

- Reader và Author dùng cùng không gian đọc; Author có thêm Studio tác giả trong mục hồ sơ.
- Admin và Moderator chỉ vào khu vực điều khiển/kiểm duyệt, có nút đăng xuất trên thanh tiêu đề; không có lối tắt sang giao diện đọc.
- Quản lý tài khoản dùng tìm kiếm theo tên, username/email, lọc vai trò và phân trang phía máy chủ (`/api/admin/users/search`).
- Form đăng ký dùng ngày sinh dạng `dd/MM/yyyy`, có thể nhập bằng số hoặc chọn lịch; mật khẩu tối thiểu 12 ký tự.
- Khi đăng xuất, ứng dụng xóa phiên và quay về màn hình đăng nhập sau khi đóng các trang con đang mở.


Dự án demo Smart Story trên Android: đọc truyện tranh, thư viện, gợi ý, nháp tiểu thuyết/truyện chat và không gian tác giả. Frontend được tổ chức theo MVVM + Clean Architecture; backend là Java Spring Boot 3, lưu dữ liệu dùng chung trên PostgreSQL. SQLite trên điện thoại chỉ dùng làm cache, lưu thao tác đang chờ đồng bộ và lưu chương đọc offline.

## Cài đặt môi trường phát triển trên Windows (thực hiện một lần)

Phần này dành cho máy Windows mới cài đặt. Dự án cần Flutter để chạy ứng dụng Android và JDK/Maven để chạy Backend Spring Boot. Nên dùng **Flutter stable 3.47.x** và **JDK 21** để khớp với cấu hình dự án; Backend biên dịch mã nguồn ở mức Java 17 nhưng chạy bằng JDK 21 được.

### A. Tải và cài Android Studio

1. Tải Android Studio từ [trang chính thức](https://developer.android.com/studio) và cài bằng bộ cài `.exe`.
2. Mở Android Studio, hoàn tất Setup Wizard và chọn cài các thành phần Android SDK được đề xuất.
3. Vào **More Actions → SDK Manager** (hoặc **File → Settings → Languages & Frameworks → Android SDK**). Trong **SDK Tools**, đảm bảo có **Android SDK Platform-Tools**, **Android SDK Build-Tools**, **Android SDK Command-line Tools (latest)** và **Android Emulator**.
4. Trong **SDK Platforms**, cài Android SDK Platform mà Flutter/project yêu cầu. Nếu quá trình build báo thiếu NDK phiên bản cụ thể, mở **SDK Tools → NDK (Side by side)** và cài đúng phiên bản được nêu trong lỗi.
5. Vào **Device Manager**, tạo máy ảo Android (AVD) hoặc kết nối điện thoại Android đã bật Developer options/USB debugging.

Tải xuống: [Android Studio](https://developer.android.com/studio) · [Hướng dẫn cài đặt](https://developer.android.com/studio/install.html).

### B. Tải Flutter SDK và thêm vào PATH

> Cài plugin Flutter trong Android Studio **không đồng nghĩa** đã cài Flutter SDK. Cần có SDK riêng để lệnh `flutter` chạy được trong Terminal.

1. Mở [Flutter SDK archive](https://docs.flutter.dev/install/archive) và chọn bản **Stable** cho Windows x64. Với cấu hình dự án này, ưu tiên nhánh **3.47.x**; nếu đang dùng một bản 3.47.x ổn định và `flutter doctor` không báo lỗi tương thích, không cần đổi phiên bản chỉ vì có bản mới.
2. Giải nén SDK vào đường dẫn ngắn, không có dấu cách, ví dụ `C:\src\flutter`. Tránh giải nén thành `C:\src\flutter\flutter` do lồng thêm một cấp thư mục.
3. Trên Windows, mở Start và tìm **Edit environment variables for your account** → chọn biến `Path` trong **User variables** → **Edit → New**, thêm:

   ```text
   C:\src\flutter\bin
   ```

4. Nhấn OK để lưu tất cả cửa sổ. Đóng rồi mở lại Terminal và Android Studio để nạp PATH mới.
5. Trong Android Studio, mở **Settings → Plugins**, cài plugin **Flutter** (plugin Dart sẽ được yêu cầu/cài kèm), rồi khởi động lại IDE.

Tải xuống/hướng dẫn: [Cài Flutter thủ công trên Windows](https://docs.flutter.dev/install/manual) · [Thêm Flutter vào PATH](https://docs.flutter.dev/install/add-to-path).

### C. Tải JDK 21 và khai báo JAVA_HOME

Dự án dùng Spring Boot 3.2.5 và Maven; khuyến nghị **JDK 21 x64**, không cài JRE riêng. `pom.xml` đặt Java source/target ở 17, nhưng dùng JDK 21 để chạy Backend và Gradle phù hợp với cấu hình dự án.

1. Mở [Eclipse Temurin JDK 21](https://adoptium.net/temurin/releases/?version=21), chọn **Windows → x64 → JDK → MSI**, rồi cài đặt.
2. Ghi lại thư mục JDK thực tế, ví dụ `C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot`. Dùng đúng thư mục đã cài trên máy, không sao chép nguyên số phiên bản trong ví dụ.
3. Mở **Edit environment variables for your account** → **New** trong User variables:

   - Variable name: `JAVA_HOME`
   - Variable value: đường dẫn thư mục JDK, **không thêm `\\bin`**.

4. Chọn biến `Path` → **Edit → New** → thêm:

   ```text
   %JAVA_HOME%\bin
   ```

5. Mở Terminal mới và kiểm tra `java -version` và `javac -version`; cả hai phải chạy được. Kiểm tra `mvn -v` ở phần Maven bên dưới để chắc chắn Maven đang sử dụng đúng JDK.

Nếu `flutter doctor -v` cho biết Flutter đang dùng một JDK khác và quá trình build Gradle lỗi tương thích, có thể yêu cầu Flutter dùng JDK 21 bằng lệnh (thay đường dẫn bằng thư mục JDK thực tế):

```powershell
flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-21.x.x-hotspot"
```

Tải xuống: [Eclipse Temurin JDK 21](https://adoptium.net/temurin/releases/?version=21).

### D. Cài Apache Maven

Backend không kèm Maven Wrapper (`mvnw`), vì vậy lệnh `mvn` cần được cài và thêm vào PATH.

1. Tải binary distribution ZIP từ [Apache Maven Download](https://maven.apache.org/download.cgi). Dùng Maven **3.8+**; có thể dùng bản ổn định mới được trang chính thức cung cấp.
2. Giải nén vào ví dụ `C:\tools\apache-maven-3.10.0` (tên thư mục tuỳ file tải về).
3. Thêm biến User variable `MAVEN_HOME` trỏ tới thư mục Maven, ví dụ `C:\tools\apache-maven-3.10.0`.
4. Thêm `%MAVEN_HOME%\bin` vào `Path`.
5. Đóng/mở lại Terminal, chạy `mvn -v`. Kết quả cần hiện phiên bản Maven và Java 21.

Hướng dẫn chính thức: [Cài Apache Maven](https://maven.apache.org/install.html).

### E. Khai báo Android SDK và kiểm tra biến môi trường

Android Studio thường đặt SDK ở:

```text
%LOCALAPPDATA%\Android\Sdk
```

Nếu đúng với máy bạn, tạo User variable:

- `ANDROID_HOME` = `%LOCALAPPDATA%\Android\Sdk`

Thêm các mục sau vào `Path` nếu các thư mục tương ứng tồn tại:

```text
%ANDROID_HOME%\platform-tools
%ANDROID_HOME%\cmdline-tools\latest\bin
```

Không cần đặt `ANDROID_SDK_ROOT` nếu bạn đã dùng `ANDROID_HOME`; tránh để hai biến trỏ đến hai thư mục SDK khác nhau. Nếu Android Studio cài SDK ở vị trí khác, hãy dùng đúng đường dẫn trong **SDK Manager**.

Mở Terminal mới (nếu chưa có thể phải khởi động lại Android Studio), rồi chạy:

```powershell
java -version
javac -version
mvn -v
flutter --version
dart --version
flutter doctor -v
flutter doctor --android-licenses
flutter devices
```

Chấp nhận các điều khoản Android SDK khi được hỏi. Trước khi tiếp tục, cần xử lý các lỗi trong phần **Android toolchain** của `flutter doctor`; mục Visual Studio chỉ cần thiết nếu bạn định build ứng dụng Windows, không phải Android.

### F. Python (chỉ cần cho công cụ nhập truyện)

Nếu sử dụng `backend/tools/import_comics.py`, hãy cài [Python 3.10+ cho Windows](https://www.python.org/downloads/windows/) và bật lựa chọn thêm Python vào PATH. Kiểm tra bằng `python --version`. Công cụ nhập truyện sẽ cài các thư viện của nó trong lần chạy đầu tiên.

### G. Biến môi trường hệ thống và cấu hình bí mật của Smart Story là hai thứ khác nhau

- **Windows User variables / `Path`** giúp Terminal tìm thấy chương trình `flutter`, `java`, `mvn`, `adb`.
- **`backend/.env.local`** chứa cấu hình riêng của ứng dụng (mật khẩu PostgreSQL, `JWT_SECRET`, cấu hình Gmail). File này **không nằm sẵn trong ZIP** vì có thông tin nhạy cảm; tạo bằng script trong phần PostgreSQL bên dưới. Không cần tự tạo `DB_PASSWORD` hoặc `JWT_SECRET` trong Windows Environment Variables nếu bạn chạy Backend bằng script của dự án.
- **`frontend/android/local.properties`** chứa đường dẫn Flutter SDK và Android SDK trên máy cụ thể. Flutter/Gradle thường tự tạo khi chạy; nếu thiếu, sao chép `frontend/android/local.properties.example` thành `local.properties` và sửa hai đường dẫn theo máy của bạn. Không đưa file này lên Git.

Nếu cần hướng dẫn theo từng bước và xử lý lỗi cài đặt, xem thêm [`docs/SETUP_WINDOWS.md`](docs/SETUP_WINDOWS.md).

---

## 1. Mở dự án bằng Android Studio

1. Giải nén ZIP.
2. Cài Flutter SDK và cài plugin **Flutter** (plugin sẽ yêu cầu Dart) trong Android Studio.
3. Mở `frontend/pubspec.yaml` hoặc mở thư mục `frontend` bằng **File → Open**.
4. Mở Terminal tại `frontend`, chạy:

   ```bash
   flutter pub get
   flutter run
   ```

   Không chạy lại `flutter create --platforms=android .` nếu thư mục `android/` đã tồn tại: lệnh đó có thể thay đổi cấu hình Gradle của dự án. Chỉ dùng `setup_android_windows.bat` khi Android scaffold/Gradle wrapper còn thiếu.
5. Chọn Android Emulator. URL mặc định là `http://10.0.2.2:8080/api`, dùng khi backend chạy trên chính máy tính của bạn.

## 2. Cấu hình và chạy PostgreSQL

1. Mở pgAdmin, kết nối PostgreSQL và tạo database `comic_db`.
2. Cách khuyên dùng trên Windows: chạy `backend/tools/setup_backend_env_windows.ps1`. Script hỏi mật khẩu PostgreSQL, tạo JWT secret ngẫu nhiên và lưu cấu hình cục bộ vào `backend/.env.local`; mật khẩu database không được ghi vào source code. Không commit hoặc gửi file `.env.local`.
3. Nếu cấu hình bằng IntelliJ thay vì script, đặt `DB_PASSWORD` và `JWT_SECRET` trong Run Configuration. `JWT_SECRET` phải có tối thiểu 32 byte; nếu thiếu, Backend sẽ dừng thay vì dùng khóa yếu.
4. Lần đầu thiết lập quyền quản trị, chạy `backend/tools/bootstrap_admin_windows.ps1` thay vì chạy launcher Backend thông thường. Script yêu cầu bạn tự đặt email, username và mật khẩu Admin tối thiểu 16 ký tự, rồi khởi động Backend và tạo tài khoản một lần. Không có username/mật khẩu Admin mặc định dùng chung trong ZIP. Giữ cửa sổ đó mở; không khởi động thêm Backend ở cổng 8080.
5. Những lần chạy sau, dùng `run_backend_windows.bat` hoặc `backend/tools/run_backend_windows.ps1`. Backend tự tạo/cập nhật bảng qua Hibernate (`ddl-auto=update`) và có thể thêm truyện mẫu đã duyệt để phục vụ kiểm tra khi database còn trống. Thông tin truyện/ảnh bìa của tác giả được lưu ngay; các chương cũ từ database chưa có trạng thái kiểm duyệt sẽ được chuyển sang `PENDING` để Moderator/Admin xem lại.

### Bắt buộc cấu hình Gmail để đăng ký gửi mã xác minh

Đăng ký mới yêu cầu mã xác minh 6 chữ số gửi qua email (hiệu lực 10 phút). Vì lý do bảo mật, ứng dụng **không gửi mật khẩu thật qua email**; người dùng tự đặt mật khẩu và email chỉ nhận mã xác minh.

1. Bật xác minh 2 bước cho tài khoản Google của bạn và tạo **App Password** cho ứng dụng. Không dùng mật khẩu đăng nhập Gmail thông thường.
2. Cấu hình `MAIL_USERNAME` và `MAIL_PASSWORD` trong `backend/.env.local` hoặc Run Configuration. Nếu dùng script launcher, nó sẽ nạp `DB_PASSWORD` và `JWT_SECRET` từ cấu hình riêng. Chỉ dùng Gmail App Password; không ghi mật khẩu thật vào file project.
3. Nếu chưa cấu hình SMTP, đăng ký sẽ không thể gửi mã xác minh. Kiểm tra cả thư mục Spam khi chờ mã.
4. Mã endpoint: `POST /api/auth/register` → gửi mã; `POST /api/auth/verify-email` → xác minh; chỉ tài khoản đã xác minh mới đăng nhập được.

## 3. Chạy Java Spring Boot

Yêu cầu JDK 21 (khuyến nghị cho môi trường Android hiện tại; backend biên dịch target Java 17) và Maven 3.8+. Android Studio chủ yếu dùng cho Flutter; backend có thể mở cùng cửa sổ dưới dạng Maven project, hoặc mở riêng bằng IntelliJ IDEA.

Trên Windows, khuyên dùng `run_backend_windows.bat` ở thư mục gốc hoặc chạy `backend/tools/run_backend_windows.ps1`. Các script nạp cấu hình bí mật cục bộ trước khi gọi Maven. Nếu khởi động trực tiếp từ IntelliJ, khai báo `DB_PASSWORD`, `JWT_SECRET` và các biến SMTP cần thiết trong Run Configuration. Kiểm tra API tại `http://localhost:8080/api/comics`; Swagger UI tại `http://localhost:8080/swagger-ui.html`.

## 4. Chạy đồng thời

- Cửa sổ/Terminal 1: chạy PostgreSQL.
- Terminal 2: trên Windows chạy `run_backend_windows.bat` ở thư mục gốc (hoặc `backend/tools/run_backend_windows.ps1`) để nạp `backend/.env.local` trước khi chạy Maven. Trên hệ điều hành khác, đặt các biến `DB_PASSWORD`, `JWT_SECRET` (ít nhất 32 ký tự), cùng các biến cấu hình cần thiết rồi chạy `mvn spring-boot:run` trong `backend`.
- Terminal 3, tại `frontend`: `flutter run`.

Tắt backend thì app chỉ có thể xem danh sách truyện nếu đã có cache trước đó; các thao tác tài khoản/thanh toán cần server. Các yêu thích và lịch sử đọc mới được ghi vào SQLite trước, sau đó gửi lên backend khi có kết nối lại và khi người dùng bấm Đồng bộ/kéo để làm mới thư viện.

## 5. Đồng bộ giữa các thiết bị

PostgreSQL trên máy chủ là nguồn dữ liệu dùng chung. Mỗi ứng dụng Flutter gọi REST API Spring Boot; không kết nối trực tiếp tới PostgreSQL.

- **Android Emulator trên máy phát triển:** `http://10.0.2.2:8080/api`.
- **Điện thoại thật cùng Wi-Fi:** chạy Spring Boot trên máy tính, lấy IP LAN của máy tính (ví dụ `192.168.1.20`), rồi chạy Flutter với `--dart-define=COMIC_API_URL=http://192.168.1.20:8080/api`. Cần cho phép cổng 8080 qua Windows Firewall và giữ hai thiết bị cùng mạng.
- **Thiết bị ở mạng khác:** triển khai Spring Boot lên VPS/cloud, dùng HTTPS và đặt `COMIC_API_URL` thành URL công khai. Không mở cổng PostgreSQL 5432 công khai.

Ví dụ chạy trên Android Emulator:

```bash
flutter run --dart-define=COMIC_API_URL=http://10.0.2.2:8080/api
```

Ví dụ với điện thoại thật (thay IP bằng IP của máy bạn):

```bash
flutter run --dart-define=COMIC_API_URL=http://192.168.1.20:8080/api
```

## 6. Trải nghiệm theo vai trò

- **READER**: giao diện đọc truyện tiêu chuẩn.
- **AUTHOR**: dùng nguyên giao diện Reader (khám phá, phân loại, theo dõi, tủ sách, hồ sơ) và có thêm mục **Studio tác giả** trong tab Tôi. Studio cho phép tạo/sửa thông tin truyện, đề xuất độ tuổi, quản lý chương và nhập nội dung từ nhiều ảnh, thư mục, ZIP/CBZ, PDF, TXT hoặc MD. Thông tin truyện và ảnh bìa được lưu ngay; chương mới, chương sửa đổi hoặc chương được bổ sung trang sẽ chuyển về `PENDING`.
- **MODERATOR**: mở đầu tại Trung tâm Moderator để xử lý hàng chờ và báo cáo. Có thể mở xem trước toàn bộ nội dung chương chữ hoặc từng trang ảnh trước khi duyệt/gán tuổi; có nút đăng xuất trên thanh tiêu đề và không có tab Tôi/chuyển sang giao diện đọc thông thường.
- **ADMIN**: mở đầu tại Bảng điều khiển Admin, có quản trị tài khoản và công cụ kiểm duyệt. Có nút đăng xuất trong dashboard và các màn hình quản trị; tài khoản bootstrap bị loại khỏi danh sách phân quyền thông thường. Giao diện Admin chỉ dành cho tác vụ quản trị, không có lối tắt sang giao diện đọc.

Giao diện chỉ điều hướng theo vai trò; Backend vẫn là nơi thực thi phân quyền. Studio tác giả gọi `/api/author/**`; quản trị tài khoản hỗ trợ tìm kiếm, lọc vai trò và phân trang phía máy chủ qua `/api/admin/users/search`. Sau khi cập nhật `pubspec.yaml`, luôn chạy `flutter pub get` trước khi chạy ứng dụng để cài các phụ thuộc của Studio.

## 7. Kiến trúc Flutter

- `core/`: API constants, Dio client, lỗi API.
- `domain/entities/`: entity nghiệp vụ.
- `domain/repositories/`: interface repository.
- `domain/usecases/`: use case xác thực, danh mục truyện, thư viện, thanh toán và offline.
- `data/models/`: ánh xạ JSON ↔ entity.
- `data/datasources/remote/`: gọi REST API Spring Boot.
- `data/datasources/local/`: SQLite cache, queue đồng bộ, tải chương offline.
- `data/repositories/`: repository triển khai quy tắc chọn dữ liệu server/cache và đồng bộ.
- `presentation/viewmodels/`: `AuthViewModel`, `HomeViewModel`, `ReaderViewModel`, `PaymentViewModel`, `ProfileOfflineViewModel`.
- `presentation/screens/`: giao diện đăng nhập, khám phá, chi tiết, đọc, thanh toán.
- `presentation/screens/profile/author_studio_screen.dart`: Studio tác giả dùng API thật để tạo/sửa truyện, quản lý chương, nhập nhiều ảnh/ZIP/CBZ/PDF/TXT và tải ảnh từng trang; yêu cầu vai trò AUTHOR ở Backend.
- `presentation/screens/profile/author_workspace_screens.dart`: các màn hình Người theo dõi, Thống kê truyện và Trạng thái duyệt.
- `presentation/screens/profile/author_comic_feedback_screen.dart`: bình luận, đánh giá và điểm sao trung bình của từng truyện.
- `presentation/screens/profile/author_feedback_read_state.dart`: lưu mốc phản hồi đã xem theo tài khoản/truyện trên thiết bị để hiển thị chấm đỏ khi có bình luận/đánh giá mới.
- `presentation/screens/profile/role_workspace_screen.dart`: trang đích riêng cho MODERATOR và ADMIN, có đăng xuất trực tiếp trên thanh tiêu đề và không điều hướng sang giao diện đọc.

## 8. API chính

| Method | Endpoint | Mục đích |
|---|---|---|
| POST | `/api/auth/register` | Đăng ký hồ sơ và gửi mã xác minh email (không tự đăng nhập) |
| POST | `/api/auth/verify-email` | Xác minh email bằng mã 6 chữ số |
| POST | `/api/auth/login` | Đăng nhập tài khoản đã xác minh và nhận JWT |
| GET | `/api/auth/me` | Đồng bộ hồ sơ/vai trò hiện tại theo server |
| POST | `/api/auth/become-author` | Chủ động đăng ký quyền tác giả |
| GET | `/api/moderation/queue` | Hàng chờ kiểm duyệt (Moderator/Admin) |
| GET | `/api/moderation/comics/{id}/preview` | Xem trước chương và ảnh của nội dung đang kiểm duyệt |
| POST | `/api/comics/{id}/reports` | Báo cáo bản quyền/độ tuổi/nội dung |
| GET/PATCH | `/api/admin/users`, `/api/admin/users/{id}/role` | Admin quản lý vai trò Reader/Moderator |
| GET | `/api/comics` | Danh sách truyện |
| GET | `/api/comics/search?q=conan` | Tìm kiếm truyện |
| GET | `/api/comics/{id}` | Chi tiết và các chương |
| GET | `/api/chapters/{id}` | Nội dung chương/trang ảnh |
| GET | `/api/recommendations?userId=1` | Gợi ý truyện |
| GET/POST | `/api/users/{id}/favorites`, `/api/favorites` | Tải/thêm yêu thích |
| DELETE | `/api/favorites?userId=1&comicId=1` | Bỏ yêu thích |
| GET | `/api/users/{id}/authors` | Danh sách tác giả đang theo dõi |
| POST | `/api/authors/follow` | Theo dõi tác giả theo tên |
| DELETE | `/api/authors/follow?userId=1&authorName=...` | Bỏ theo dõi tác giả |
| GET/POST | `/api/users/{id}/history`, `/api/history` | Lịch sử đọc |
| GET | `/api/users/{id}/unlocked-chapters` | Các chương đã mở khóa |
| POST | `/api/payment/create` | Ghi giao dịch mô phỏng |
| POST | `/api/upload/cover` | Tải ảnh bìa lên backend |
| GET | `/api/author/comics` | Danh sách truyện thuộc tài khoản Author hiện tại |
| GET | `/api/author/dashboard` | Thống kê tổng quan và từng truyện, gồm lượt đọc, bình luận, điểm sao trung bình và mốc phản hồi mới nhất |
| GET | `/api/author/followers` | Danh sách độc giả đang theo dõi bút danh của tác giả |
| GET | `/api/author/comics/{comicId}/feedback` | Bình luận/đánh giá của truyện do tài khoản hiện tại sở hữu, cùng số lượng và điểm sao trung bình |
| GET/POST | `/api/comics/{id}/comments` | Đọc/gửi bình luận trên truyện đã được phép đọc |
| GET/POST | `/api/comics/{id}/reviews` | Xem đánh giá, chấm 1–5 sao và cập nhật nhận xét của độc giả |
| GET | `/api/author/comics/{id}` | Chi tiết truyện và chương cho Studio (kể cả truyện đang chờ duyệt, chỉ chủ sở hữu/Admin) |
| POST/PUT | `/api/author/comics` và `/api/author/comics/{id}` | Tạo/cập nhật metadata và ảnh bìa; không tạo hàng chờ kiểm duyệt chương |
| POST | `/api/author/comics/{id}/chapters` | Thêm chương chữ hoặc chương hình đang chờ kiểm duyệt |
| PUT | `/api/author/chapters/{id}/content` | Sửa nội dung chương chữ; gửi duyệt lại |
| POST | `/api/author/comics/{id}/import` | Nhập chương từ nhiều ảnh, thư mục, ZIP/CBZ, PDF, TXT/MD |
| GET | `/api/author/chapters/{id}` | Chi tiết chương và các trang ảnh của chủ sở hữu/Admin |
| POST | `/api/author/chapters/{id}/pages` | Tải trang ảnh lên chương của tác giả |

## 9. Thêm dữ liệu truyện

Dữ liệu mẫu được thêm tự động khi PostgreSQL chưa có truyện. Để thêm truyện phục vụ kiểm thử, mở pgAdmin → database `comic_db` → Query Tool. Xem ví dụ trong `docs/add-comic-example.sql`. Sau khi thêm truyện/chương/trang ở database dùng chung, các thiết bị tải lại danh sách từ API sẽ đọc dữ liệu mới; không cần cài lại ứng dụng.

### 8.1. Nhập truyện từ Studio tác giả hoặc công cụ Python độc lập

**Cách khuyên dùng — ngay trong ứng dụng Flutter:**

1. Đăng nhập bằng tài khoản có vai trò `AUTHOR`.
2. Mở **Tôi → Studio tác giả** và tạo thông tin truyện, bút danh, mô tả, thể loại, ảnh bìa cùng độ tuổi đề xuất. Metadata/ảnh bìa được lưu ngay, không phải qua duyệt.
3. Mở truyện vừa tạo → **Quản lý chương** → **Nhập truyện từ file / thư mục**.
4. Chọn nhiều ảnh để tạo một chương; chọn một ZIP/CBZ (có các thư mục `Chapter 1`, `Chapter 2`...) để tạo nhiều chương; hoặc chọn PDF, TXT/MD, hay một thư mục truyện đã giải nén trên desktop. Với PDF có thể chọn tự nhận diện, chuyển thành ảnh, hoặc trích xuất văn bản.
5. Chọn số chương bắt đầu và độ tuổi đề xuất. Hệ thống tạo các chương ở trạng thái `PENDING`; Moderator/Admin phải xem toàn bộ văn bản hoặc từng ảnh trang, rồi mới quyết định duyệt và gán độ tuổi.

Giới hạn cho một lần nhập qua Studio: tổng dung lượng tối đa 250 MB, tối đa 1.500 tệp và 500 chương. ZIP/CBZ được đọc an toàn trong bộ nhớ; các đường dẫn archive không được giải nén trực tiếp ra đĩa theo tên bên trong archive.

**Cách dành cho quản trị viên — công cụ Python độc lập:**

Dự án vẫn kèm công cụ Python có thể ghi trực tiếp vào PostgreSQL, hữu ích khi quản trị viên nạp dữ liệu ban đầu:

1. Bật PostgreSQL và chạy Backend thành công ít nhất một lần để Hibernate tạo bảng.
2. Chạy `backend/tools/run_importer_windows.bat`. Lần đầu script cài Pillow, PyMuPDF và psycopg.
3. Chọn thư mục hoặc ZIP/CBZ/PDF; nhập metadata, ID tài khoản chủ sở hữu (`AUTHOR` hoặc `ADMIN`) và thông tin PostgreSQL.
4. Metadata/ảnh bìa được lưu ở trạng thái công khai; mỗi chương ảnh nhập mới có trạng thái `PENDING` và cần được Moderator/Admin duyệt.

Công cụ Python hỗ trợ ảnh JPG/PNG/WebP/BMP/GIF/TIFF, chuyển trang PDF thành JPEG, sắp xếp thứ tự chương/trang và tạo các bản ghi `comics`, `comic_tags`, `chapters`, `pages`. Xem [`backend/tools/README_IMPORTER.md`](backend/tools/README_IMPORTER.md). Chỉ nhập nội dung mà tài khoản có quyền sử dụng hoặc phân phối hợp pháp.

## 10. Giao diện mới và ý tưởng tham khảo

Giao diện và nhóm tính năng được thiết kế lại theo các mô hình phổ biến trong ứng dụng đọc truyện, không sao chép nguyên giao diện/nhãn hiệu của sản phẩm khác:

- WEBTOON: trang khám phá có đề xuất cá nhân hóa, tìm kiếm, lịch sử đọc, đăng ký theo dõi series và khu vực quản lý tải/bình luận; tham khảo [trang trợ giúp quản lý hoạt động](https://webtoon.zendesk.com/hc/en-us/articles/360051601031-How-do-I-manage-my-WEBTOON-activity) và [giới thiệu cá nhân hóa khám phá](https://about.webtoon.com/press-release/183).
- MangaToon: mô hình trang “Tôi” dẫn đến “Trở thành tác giả”, kèm luồng tạo tiểu thuyết hoặc truyện đối thoại; tham khảo [Hỏi đáp tác giả chính thức](https://mangatoon.mobi/authorquestion/vi).
- NovelToon: hỗ trợ ý tưởng đọc offline và truyện chat; tham khảo [trang ứng dụng Google Play](https://play.google.com/store/apps/details?id=mobi.mangatoon.novel).

Thanh điều hướng gồm **Đề xuất, Phân loại, Theo dõi, Tủ sách, Tôi**. Màn hình Tôi có hồ sơ, hộp tin nhắn, cài đặt, khu vực tác giả, phúc lợi, sáng tác tiểu thuyết/truyện chat, phiếu đọc, avatar, danh hiệu fan, bình luận, level, phản hồi và giới thiệu. Avatar đã được lưu trên thiết bị và phản ánh lại trong hồ sơ; avatar, bản nháp sáng tác, điểm danh và phản hồi hiện vẫn là dữ liệu cục bộ. Muốn dùng chung giữa các máy cần bổ sung API tương ứng.


Thanh điều hướng gồm **Đề xuất, Phân loại, Theo dõi, Tủ sách, Tôi**. Màn hình Tôi có hồ sơ, hộp tin nhắn, cài đặt, khu vực tác giả, phúc lợi, sáng tác tiểu thuyết/truyện chat, phiếu đọc, avatar, danh hiệu fan, bình luận, level, phản hồi và giới thiệu. Các bản nháp sáng tác, avatar, điểm danh và phản hồi hiện lưu cục bộ; muốn dùng chung giữa các máy cần bổ sung API tương ứng.

Google/Facebook hiện chỉ có nút giao diện báo trạng thái chưa cấu hình; chưa phải luồng OAuth thực sự. Để bật cần thiết lập ứng dụng OAuth/Firebase và xác minh token ở backend. Backend hiện vẫn quản lý tài khoản email/mật khẩu riêng. Mô hình truyện đã xuất bản hiện vẫn là Comic/Chapter/Page; danh sách công khai cho tiểu thuyết và truyện chat cần mở rộng schema backend sang Story/Episode/ChatMessage.

## 11. Bảo mật, vai trò và giới hạn cần biết

- Các bước khởi tạo Admin và checklist kiểm thử từng vai trò nằm trong [`docs/RBAC_TEST_PLAN.md`](docs/RBAC_TEST_PLAN.md).
- RBAC đã được áp dụng ở Backend: `READER` mặc định; người dùng chủ động đăng ký trở thành `AUTHOR`; `MODERATOR` chỉ do Admin cấp; `AUTHOR` chỉ được kích hoạt qua luồng “Trở thành tác giả”; `ADMIN` được bootstrap bằng script riêng. Các request đọc/sửa/quản lý bị kiểm tra ở Spring Security và controller/service, không chỉ dựa vào giao diện Flutter.
- Vai trò được đọc lại từ PostgreSQL theo JWT mỗi request; khi Admin hạ quyền hoặc thu hồi vai trò, token cũ không giữ lại quyền nâng cao. Khi mở lại app online, Flutter làm mới vai trò từ `GET /api/auth/me`.
- Metadata truyện/ảnh bìa được lưu ngay; chương mới, chương đã sửa hoặc bổ sung ảnh chuyển về `PENDING`. Độc giả có thể báo cáo dấu hiệu vi phạm độ tuổi/bản quyền; Moderator/Admin xem trọn nội dung chữ hoặc từng ảnh trang, rồi duyệt, giới hạn `13+` / `16+` / `18+`, ẩn hoặc từ chối. URL ảnh chương cũng tuân theo trạng thái duyệt/độ tuổi.
- Giao diện theo vai trò: `READER` và `AUTHOR` cùng sử dụng đầy đủ trải nghiệm đọc (Đề xuất, Phân loại, Theo dõi, Tủ sách, Tôi). `AUTHOR` có thêm **Studio tác giả** để tạo/sửa metadata, đề xuất độ tuổi và nhập nội dung chương từ nhiều ảnh, thư mục, ZIP/CBZ, PDF, TXT/MD; chỉ nội dung chương mới/sửa đổi phải qua kiểm duyệt. `MODERATOR` và `ADMIN` vào trang điều khiển/kiểm duyệt riêng, có đăng xuất trực tiếp và không có đường tắt tới giao diện đọc thông thường.
- Không có mật khẩu Admin công khai hoặc được nhúng trong ZIP. Lần đầu, chủ hệ thống chạy `backend/tools/bootstrap_admin_windows.ps1` và tự đặt mật khẩu mạnh (tối thiểu 16 ký tự); database chỉ lưu hash BCrypt. API thông thường không thể tạo tài khoản ADMIN.
- MoMo/ZaloPay vẫn là mô phỏng, chưa phải cổng thanh toán thật. Trước khi triển khai công khai vẫn cần HTTPS, rate-limit/chống dò mật khẩu, quy trình khôi phục tài khoản, sao lưu, giám sát và kiểm thử bảo mật độc lập.
- Chỉ đăng nội dung truyện mà tài khoản có quyền sở hữu hoặc quyền phân phối hợp pháp.
- Cấu hình Android hiện dùng Android Gradle Plugin 8.11.1, Kotlin Gradle Plugin 2.2.20 và Gradle 8.14.4 để đáp ứng ngưỡng tối thiểu của Flutter 3.47.x. `settings.gradle` dùng `java.util.Properties()` đầy đủ để IDE nhận diện lớp rõ ràng.
- `android/local.properties` chứa đường dẫn SDK trên máy phát triển hiện tại; nếu chuyển sang máy khác, hãy dùng `android/local.properties.example` để cập nhật `sdk.dir` và `flutter.sdk`.
- Phân quyền truyện và kiểm duyệt hoạt động ở Backend; thanh toán vẫn mô phỏng và chưa sẵn sàng cho production. Hệ thống vẫn cần các biện pháp vận hành an toàn bổ sung trước khi đưa lên Internet công khai.

## Kiểm duyệt nội dung theo từng chương

- Tạo truyện, cập nhật tên/mô tả/thể loại và ảnh bìa sẽ lưu ngay, không tạo hàng chờ kiểm duyệt truyện. Tác giả có thể đề xuất giới hạn tuổi ở cấp truyện.
- Mỗi chương có `contentType=TEXT` hoặc `IMAGE`, `suggestedAgeRating`, `moderationStatus`, `ageRating` và ghi chú kiểm duyệt riêng. Chương mới, chương được chỉnh sửa hoặc thêm trang ảnh sẽ chuyển về `PENDING`.
- Moderator/Admin vào Trung tâm kiểm duyệt → đọc toàn bộ nội dung chữ hoặc mở từng trang ảnh → chọn duyệt mọi lứa tuổi/13+/16+/18+, ẩn hoặc từ chối. Khi giới hạn tuổi, cần ghi căn cứ. Hệ thống tính độ tuổi truyện từ các chương đã duyệt, còn việc truy cập từng chương được kiểm tra riêng ở Backend.
- Trong Studio tác giả, chọn truyện → `Nhập truyện từ file / thư mục`. Có thể chọn nhiều ảnh để tạo một chương, ZIP/CBZ chứa thư mục chương, PDF (AUTO/TEXT/IMAGE), TXT/MD, hoặc thư mục đã giải nén trên desktop. Chương được tạo theo thứ tự tự nhiên và luôn chờ kiểm duyệt. Giới hạn một lượt: 250 MB, tối đa 1.500 tệp và 500 chương.

## Xử lý đăng ký/đăng nhập

Đăng ký tạo tài khoản trên backend và gửi mã xác minh email. Sau khi API đăng ký phản hồi thành công, Flutter chuyển sang màn hình nhập mã. Xác minh đúng sẽ thông báo thành công rồi quay về biểu mẫu đăng nhập; người dùng tự đăng nhập để tạo phiên.


## Theo dõi truyện và tác giả

Tab **Theo dõi** tách thành hai danh sách: truyện yêu thích (dùng API favorites) và tác giả đang theo dõi (API `/api/users/{userId}/authors`, `POST /api/authors/follow`, `DELETE /api/authors/follow`). Theo dõi tác giả được lưu lên PostgreSQL và cache/hàng đợi offline ở SQLite, đồng bộ lại khi có kết nối. Tên tác giả dựa trên trường `author` hiện có trong truyện; hiện đây là theo dõi theo tên hiển thị chứ chưa phải hồ sơ tác giả độc lập có ID.

### Đăng nhập

Ô đăng nhập chấp nhận **tên đăng nhập hoặc email** cùng mật khẩu. Khi đăng ký, trường email chỉ dùng để nhận mã xác minh và thông báo tài khoản. Tên đăng nhập được so sánh không phân biệt chữ hoa/chữ thường; tên đăng nhập trùng nhau theo kiểu này sẽ bị từ chối khi đăng ký.

### Luồng đăng ký và xác minh email

Sau khi API đăng ký trả về thành công, Flutter chuyển sang màn hình nhập mã xác minh 6 chữ số. Request đăng ký có timeout riêng 60 giây vì Backend gửi email SMTP đồng bộ. Nếu email đã đến nhưng client vẫn báo lỗi do phản hồi chậm, dùng nút **Đã nhận mã? Nhập mã xác minh** để tiếp tục bằng mã đã nhận thay vì gửi lại cùng biểu mẫu. Sau khi mã hợp lệ, ứng dụng hiển thị thông báo đăng ký thành công và quay về màn hình đăng nhập; người dùng tự đăng nhập bằng tên đăng nhập hoặc email.


### Thống kê truyện, bình luận và đánh giá

- Tab **Tôi** của tài khoản `AUTHOR` không nhúng khối thống kê tổng hợp. Thay vào đó, khu vực **Sáng tác & phát triển** có đúng bốn mục: **Người theo dõi**, **Thống kê truyện**, **Studio tác giả** và **Trạng thái duyệt**.
- **Thống kê truyện** lấy dữ liệu từ Backend theo từng tác phẩm: lượt đọc, độc giả, bình luận, số đánh giá và điểm sao trung bình thực tế. Điểm trung bình được tính từ các đánh giá của Reader trong PostgreSQL; không dùng số liệu giả.
- Bình luận/đánh giá được xem theo từng truyện trong **Studio tác giả → Quản lý truyện → Bình luận & đánh giá**, giúp tác giả kiểm tra phản hồi theo đúng tác phẩm.
- Tại trang chi tiết truyện, người dùng đã đăng nhập có thể chấm 1–5 sao, thêm nhận xét và gửi bình luận. Mỗi tài khoản có một đánh giá cho mỗi truyện; gửi lại sẽ cập nhật đánh giá đó. Các bình luận/đánh giá gắn với tài khoản đã xác thực, không nhận userId từ client để xác định người đăng.
- Bảng `comic_comments` và `comic_reviews` được Hibernate tạo/cập nhật khi Backend khởi động (`ddl-auto=update`). Dữ liệu thống kê bắt đầu từ khi các API này được sử dụng; hệ thống không tự sinh bình luận, đánh giá hoặc lượt đọc giả.
- Nếu Studio trả về HTTP 401, đó là phiên JWT không hợp lệ/hết hạn hoặc JWT secret của Backend đã thay đổi. Hãy đăng xuất/đăng nhập lại bằng Backend đang chạy; phiên lỗi giờ sẽ được xóa khi `GET /api/auth/me` trả 401. Nếu trả về 403, hãy xác nhận tài khoản thực sự có vai trò `AUTHOR` trong PostgreSQL.


## Phản hồi mới trong Studio tác giả

- Trang Tôi không nhúng khối “Thống kê tác giả”; thống kê nằm trong màn hình **Thống kê truyện**.
- Danh sách truyện trong Studio hiển thị điểm sao trung bình tính trực tiếp từ các đánh giá của độc giả. Mở **Quản lý truyện → Bình luận & đánh giá** để xem phản hồi theo từng tác phẩm.
- Chấm đỏ xuất hiện trên tab Tôi, thẻ Studio tác giả và truyện có phản hồi mới. Khi mở màn hình Bình luận & đánh giá của truyện, mốc đã xem được lưu trên thiết bị đó.

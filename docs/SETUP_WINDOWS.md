# Smart Story — Cài đặt môi trường Windows từ đầu

Hướng dẫn này dành cho Windows 10/11 64-bit, Android Studio, Flutter, Java Spring Boot và PostgreSQL. Làm theo đúng thứ tự. Bạn có thể chạy Flutter và Backend trong các tab Terminal của Android Studio; PostgreSQL là dịch vụ chạy nền của Windows.

## 1. Các công cụ cần cài

| Công cụ | Phiên bản khuyến nghị | Tải từ |
|---|---|---|
| Android Studio | Bản stable hiện tại | <https://developer.android.com/studio> |
| Flutter SDK | Stable 3.47.x cho cấu hình dự án này | <https://docs.flutter.dev/install/archive> |
| JDK | JDK 21 x64 | <https://adoptium.net/temurin/releases/?version=21> |
| Apache Maven | 3.8 trở lên; nên dùng stable mà trang chính thức cung cấp | <https://maven.apache.org/download.cgi> |
| PostgreSQL | Bản Windows được dự án/máy bạn hỗ trợ | <https://www.postgresql.org/download/windows/> |
| Git for Windows | Bản stable hiện tại | <https://git-scm.com/download/win> |
| Python (chỉ cho Comic Importer) | Python 3.10+ | <https://www.python.org/downloads/windows/> |

Dự án dùng Spring Boot 3.2.5, `pom.xml` biên dịch mã nguồn ở mức Java 17, và nên chạy Maven bằng JDK 21. Cấu hình Android dùng Android Gradle Plugin 8.11.1 và Gradle 8.14.4. Không tự đổi phiên bản Gradle/AGP nếu không có yêu cầu cụ thể từ lỗi build.

## 2. Cài Android Studio và Android SDK

1. Tải Android Studio từ <https://developer.android.com/studio>, chạy bộ cài `.exe` và hoàn tất Setup Wizard.
2. Mở **More Actions → SDK Manager** hoặc **File → Settings → Languages & Frameworks → Android SDK**.
3. Trong **SDK Platforms**, cài Android SDK Platform được đề xuất trong SDK Manager hoặc được thông báo khi build.
4. Trong **SDK Tools**, cài tối thiểu:
   - Android SDK Platform-Tools
   - Android SDK Build-Tools
   - Android SDK Command-line Tools (latest)
   - Android Emulator (nếu chạy máy ảo)
5. Nếu build báo thiếu NDK phiên bản cụ thể, vào **SDK Tools → NDK (Side by side)**, đánh dấu đúng phiên bản trong thông báo lỗi, rồi Apply.
6. Vào **Device Manager** để tạo Android Emulator. Máy ảo cần VT-x/AMD-V bật trong BIOS; nếu máy có RAM hạn chế, có thể dùng điện thoại Android thật đã bật Developer options và USB debugging.

Đường dẫn SDK mặc định thường là `%LOCALAPPDATA%\Android\Sdk`, nhưng hãy xác nhận đường dẫn thực tế trong SDK Manager.

## 3. Tải Flutter SDK và cài plugin Android Studio

1. Mở <https://docs.flutter.dev/install/archive>, chọn kênh **Stable** và gói **Windows x64**. Dùng nhánh Flutter 3.47.x cho dự án này, nếu phù hợp với các package mà dự án đang dùng.
2. Giải nén vào thư mục ngắn, ví dụ `C:\src\flutter`. Sau khi giải nén, file phải nằm tại `C:\src\flutter\bin\flutter.bat`; tránh cấu trúc lồng `C:\src\flutter\flutter\bin`.
3. Mở Windows Search → **Edit environment variables for your account**. Trong **User variables**, chọn `Path` → **Edit → New** rồi thêm:

   ```text
   C:\src\flutter\bin
   ```

4. Nhấn OK để lưu, đóng rồi mở lại Terminal và Android Studio.
5. Trong Android Studio, mở **Settings → Plugins**, tìm plugin **Flutter**, bấm Install và chấp nhận cài plugin Dart nếu được yêu cầu. Khởi động lại Android Studio.

Plugin Flutter là plugin của IDE; riêng Flutter SDK vẫn phải được tải và thêm vào `Path`. Hướng dẫn chính thức: <https://docs.flutter.dev/install/manual> và <https://docs.flutter.dev/install/add-to-path>.

## 4. Cài JDK 21 và thiết lập JAVA_HOME

1. Mở <https://adoptium.net/temurin/releases/?version=21>, chọn Windows x64, loại **JDK**, gói cài **MSI**.
2. Cài đặt và ghi lại thư mục JDK thật, ví dụ `C:\Program Files\Eclipse Adoptium\jdk-21.0.x.x-hotspot`. Tên thư mục phụ thuộc phiên bản cài.
3. Mở **Edit environment variables for your account** → **New** trong User variables:
   - Variable name: `JAVA_HOME`
   - Variable value: đường dẫn thư mục JDK, không thêm `\bin`.
4. Trong `Path`, thêm:

   ```text
   %JAVA_HOME%\bin
   ```

5. Đóng và mở lại Terminal. Kiểm tra:

   ```powershell
   java -version
   javac -version
   ```

Cả hai lệnh phải chạy và hiển thị JDK 21. Không đặt `JAVA_HOME` vào thư mục JRE hoặc thư mục `bin`.

Nếu `flutter doctor -v` cho thấy Flutter đang sử dụng một Java khác gây lỗi Gradle, có thể chỉ định JDK 21 rõ ràng (đổi đường dẫn thành đường dẫn thực tế):

```powershell
flutter config --jdk-dir="C:\Program Files\Eclipse Adoptium\jdk-21.0.x.x-hotspot"
```

Android Studio cũng có JBR riêng. Nếu cần, mở **Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK** để kiểm tra JDK Gradle được chọn. Xác nhận lần cuối bằng `flutter doctor -v`.

## 5. Cài Apache Maven

Backend không kèm Maven Wrapper, vì vậy cần lệnh `mvn` trong PATH.

1. Mở <https://maven.apache.org/download.cgi> và tải **Binary zip archive** của Maven 3.8+.
2. Giải nén ví dụ vào `C:\tools\apache-maven-3.10.0`.
3. Trong User variables, tạo:
   - `MAVEN_HOME` = `C:\tools\apache-maven-3.10.0` (dùng đúng thư mục bạn đã giải nén).
4. Trong `Path`, thêm:

   ```text
   %MAVEN_HOME%\bin
   ```

5. Đóng/mở lại Terminal và kiểm tra:

   ```powershell
   mvn -v
   ```

Kết quả cần có Maven được nhận diện và Java version 21. Nếu `mvn -v` cho Java khác, kiểm tra `JAVA_HOME`, `Path` và khởi động Terminal mới.

## 6. Các biến môi trường Windows nên có

Trong Windows Search, mở **Edit environment variables for your account**. Dùng User variables (không bắt buộc dùng System variables). Các giá trị mẫu:

| Tên biến | Giá trị mẫu | Ghi chú |
|---|---|---|
| `JAVA_HOME` | `C:\Program Files\Eclipse Adoptium\jdk-21...` | Thư mục JDK, không có `\bin` |
| `MAVEN_HOME` | `C:\tools\apache-maven-3.10.0` | Thư mục Maven giải nén |
| `ANDROID_HOME` | `%LOCALAPPDATA%\Android\Sdk` | Dùng đường dẫn thật trong SDK Manager |

Các mục cần có trong `Path`:

```text
%JAVA_HOME%\bin
%MAVEN_HOME%\bin
C:\src\flutter\bin
%ANDROID_HOME%\platform-tools
%ANDROID_HOME%\cmdline-tools\latest\bin
```

Nếu thư mục `cmdline-tools\latest\bin` chưa tồn tại, hãy cài Android SDK Command-line Tools (latest) trong SDK Manager trước. Không cần đặt `ANDROID_SDK_ROOT` nếu đã cấu hình `ANDROID_HOME`; nếu máy đang có cả hai, phải đảm bảo chúng trỏ đến cùng SDK.

## 7. Kiểm tra công cụ đã được cài

Mở Terminal mới (PowerShell hoặc Terminal trong Android Studio) và chạy:

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

- Nếu `flutter`, `java` hoặc `mvn` không được nhận diện, hãy kiểm tra `Path`, lưu biến môi trường và mở Terminal mới.
- Chạy `flutter doctor --android-licenses`, đọc và chấp nhận license khi được hỏi.
- Tiếp tục khi `flutter doctor -v` không còn lỗi chặn Android toolchain.
- Nếu thiếu NDK, cài đúng phiên bản ghi trong lỗi bằng SDK Manager.

## 8. PostgreSQL và cấu hình riêng của Backend

1. Cài PostgreSQL từ <https://www.postgresql.org/download/windows/> (nếu chưa cài) và đảm bảo dịch vụ PostgreSQL đang chạy.
2. Mở pgAdmin một lần để kết nối máy chủ. Tạo database `comic_db` nếu chưa tồn tại. Nếu tài khoản đăng nhập database là `postgres`, dùng `postgres` làm **username** của database; `comic_db` là **tên database**, không phải username.
3. Mở Terminal tại thư mục gốc `comic-reading-app`, chạy:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\backend\tools\setup_backend_env_windows.ps1
   ```

   Nhập username PostgreSQL (nhấn Enter để dùng mặc định `postgres`) và mật khẩu PostgreSQL. Script tạo `backend/.env.local`, sinh JWT secret ngẫu nhiên và không ghi mật khẩu vào source code. File `.env.local` không được đóng gói cùng dự án vì chứa bí mật.
4. Mở file cấu hình bằng:

   ```powershell
   notepad .\backend\.env.local
   ```

   Để gửi mã xác minh đăng ký, điền `MAIL_USERNAME` bằng Gmail dùng để gửi thư và `MAIL_PASSWORD` bằng **Google App Password**. Không dùng mật khẩu đăng nhập Gmail thông thường. Tạo App Password tại <https://myaccount.google.com/apppasswords> sau khi bật xác minh 2 bước cho tài khoản Google.
5. Tạo Admin lần đầu bằng:

   ```powershell
   .\backend\tools\bootstrap_admin_windows.ps1
   ```

   Nhập email và username chưa tồn tại trong bảng `users`, tên hiển thị và mật khẩu riêng tối thiểu 16 ký tự. Không có Admin mặc định được nhúng trong ZIP. Nếu bootstrap báo email đã tồn tại nhưng không phải ADMIN, dùng email/username chưa được đăng ký; đừng xóa database chỉ để bỏ qua lỗi đó.
6. Khi bootstrap thành công, giữ tiến trình Backend chạy trong Terminal. Các lần tiếp theo dùng `run_backend_windows.bat` từ thư mục gốc `comic-reading-app`.

**Phân biệt:** `JAVA_HOME`, `MAVEN_HOME`, `ANDROID_HOME`, `Path` là biến môi trường Windows giúp tìm công cụ. `backend/.env.local` là file cấu hình riêng của ứng dụng lưu database password, JWT secret và các biến SMTP. Nếu chạy Backend bằng script của dự án, không cần tự tạo các bí mật này trong Windows Environment Variables. Không gửi, commit hoặc đóng gói `.env.local`.

## 9. Chạy Flutter và Backend trong Android Studio

Có thể dùng một cửa sổ Android Studio với nhiều tab Terminal.

### Terminal Backend

Từ thư mục gốc `comic-reading-app`:

```powershell
.\run_backend_windows.bat
```

Giữ Terminal mở. Backend mặc định ở `http://localhost:8080`. Kiểm tra nhanh bằng `http://localhost:8080/api/comics`.

### Terminal Frontend

Mở tab Terminal mới, tại thư mục gốc dự án chạy:

```powershell
cd frontend
flutter pub get
flutter run --dart-define=COMIC_API_URL=http://10.0.2.2:8080/api
```

Chọn Android Emulator khi Flutter hỏi thiết bị. `10.0.2.2` là cách Android Emulator truy cập máy chủ trên máy tính phát triển.

Nếu vừa thêm plugin hoặc sửa biến môi trường mà lệnh chưa nhận ra, khởi động lại Android Studio. Không chạy `flutter create --platforms=android .` trên dự án này khi `frontend/android/` đã tồn tại; lệnh đó có thể ghi đè thiết lập Gradle.

## 10. Lỗi thường gặp

- **`flutter`/`mvn`/`java` không được nhận diện:** thêm đúng thư mục vào `Path`, nhấn OK lưu lại và mở Terminal mới.
- **Gradle chạy bằng Java không tương thích:** chạy `flutter doctor -v`; dùng JDK 21 cho dự án hoặc đặt `flutter config --jdk-dir` tới thư mục JDK 21 thực tế.
- **Thiếu Android SDK/NDK:** cài qua Android Studio SDK Manager đúng phiên bản trong lỗi build.
- **`password authentication failed for user postgres`:** dùng đúng mật khẩu PostgreSQL trong `backend/.env.local`; đó không phải mật khẩu pgAdmin riêng nếu bạn cấu hình khác.
- **`JWT_SECRET` thiếu hoặc quá ngắn:** tạo lại cấu hình bằng script một cách có chủ đích; nếu đã có `.env.local`, chọn ghi đè chỉ khi bạn hiểu token hiện tại có thể mất hiệu lực.
- **Đăng ký không gửi mã email:** kiểm tra `MAIL_USERNAME`, `MAIL_PASSWORD` (Gmail App Password), kết nối Internet và thư mục Spam.
- **`Port 8080 already in use`:** dừng Backend instance cũ bằng `Ctrl+C` trước khi chạy bản khác.
- **Không kết nối được từ Android Emulator:** dùng `http://10.0.2.2:8080/api`, không dùng `localhost` trong cấu hình Flutter chạy trên Emulator.
- **Dùng điện thoại thật:** đặt URL theo IP LAN máy tính, ví dụ `flutter run --dart-define=COMIC_API_URL=http://192.168.1.20:8080/api`; hai thiết bị cùng Wi-Fi và Windows Firewall cần cho phép cổng 8080.

## Tài liệu chính thức

- Flutter: <https://docs.flutter.dev/install/manual>, <https://docs.flutter.dev/install/add-to-path>, <https://docs.flutter.dev/platform-integration/android/setup>
- Android Studio: <https://developer.android.com/studio>, <https://developer.android.com/tools/variables>
- JDK 21: <https://adoptium.net/temurin/releases/?version=21>
- Apache Maven: <https://maven.apache.org/install.html>
- PostgreSQL for Windows: <https://www.postgresql.org/download/windows/>

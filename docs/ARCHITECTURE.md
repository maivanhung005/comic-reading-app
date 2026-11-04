# Kiến trúc Flutter MVVM + Clean Architecture

## Presentation / MVVM
- `presentation/screens/`: chỉ dựng giao diện, nhận thao tác người dùng và quan sát state bằng Provider.
- `presentation/viewmodels/`: `AuthViewModel`, `HomeViewModel`, `ReaderViewModel`, `PaymentViewModel`, `ProfileOfflineViewModel`.

## Domain
- `domain/entities/`: mô hình nghiệp vụ không phụ thuộc Flutter UI, Dio hay SQLite.
- `domain/repositories/comic_repository.dart`: hợp đồng dữ liệu.
- `domain/usecases/`: các hành động nghiệp vụ mà ViewModel gọi.

## Data
- `data/models/`: ánh xạ JSON API và entity.
- `data/datasources/remote/remote_data_source.dart`: REST API Spring Boot thông qua Dio.
- `data/datasources/local/local_data_source.dart`: SQLite cache, hàng đợi thao tác offline, lịch sử cục bộ và chương tải offline.
- `data/repositories/comic_repository_impl.dart`: triển khai hợp đồng domain, đồng bộ server/local.

## Nguồn dữ liệu và đồng bộ
- PostgreSQL phía máy chủ là nguồn dữ liệu chia sẻ giữa các thiết bị.
- Flutter gọi REST API; không kết nối PostgreSQL trực tiếp.
- SQLite giữ cache/truyện tải offline và các thao tác yêu thích/lịch sử đang chờ đồng bộ.
- Khi có mạng, ứng dụng gửi các thao tác còn chờ lên Spring Boot; các màn hình thư viện có nút Đồng bộ/kéo để làm mới.


## Smart Story UI extensions (prototype)

- Main navigation: Đề xuất, Phân loại, Theo dõi, Tủ sách, Tôi.
- Profile shortcuts: Hộp tin nhắn, Cài đặt, Trở thành tác giả, Phúc lợi, Sáng tác tiểu thuyết, Sáng tác truyện chat, Phiếu đọc truyện, Trung tâm Avatar, Danh hiệu fan, Bình luận của tôi, Level của tôi, Phản hồi ý kiến, Giới thiệu chúng tôi.
- Email registration is username + display name + date of birth + salutation/gender + user-chosen password, with a 6-digit email verification code. Passwords are never sent via email.
- Google/Facebook login buttons are UI placeholders until OAuth/Firebase provider credentials and server-side token validation are configured.
- Published novels/chat stories are not yet server-backed. Drafts currently live locally in SharedPreferences; production needs Story, Episode, ChatMessage, AuthorApplication and moderation APIs.

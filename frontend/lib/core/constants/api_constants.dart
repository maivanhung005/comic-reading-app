class ApiConstants {
  // Android Emulator: 10.0.2.2 trỏ về localhost của máy tính chạy Spring Boot.
  // Điện thoại thật: thay bằng IP LAN của máy tính hoặc URL server đã triển khai.
  static const String baseUrl = String.fromEnvironment(
    'COMIC_API_URL',
    defaultValue: 'http://10.0.2.2:8080/api',
  );

  /// Converts relative image paths returned by the backend (for example
  /// /uploads/imported/.../cover.jpg) to an absolute URL on the configured
  /// backend host. Existing absolute image URLs remain unchanged.
  static String resolveMediaUrl(String rawUrl) {
    final value = rawUrl.trim();
    if (value.isEmpty) return value;
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) return value;

    final apiUri = Uri.parse(baseUrl);
    final origin = Uri(
      scheme: apiUri.scheme,
      userInfo: apiUri.userInfo,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
    );
    return origin.resolve(value.startsWith('/') ? value : '/$value').toString();
  }

}

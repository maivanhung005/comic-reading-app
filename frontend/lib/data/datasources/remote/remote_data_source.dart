import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/network/dio_client.dart';

class RemoteDataSource {
  final DioClient client;
  RemoteDataSource(this.client);

  Future<dynamic> _call(Future<Response<dynamic>> request) async {
    try {
      final response = await request;
      final body = response.data;
      if (body is Map && body['success'] == false) {
        throw ApiException((body['message'] ?? 'Yêu cầu không thành công').toString(), statusCode: response.statusCode);
      }
      if (body is Map && body.containsKey('data')) return body['data'];
      return body;
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? data['message'].toString()
          : (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError
              ? 'Không kết nối được máy chủ. Hãy kiểm tra Spring Boot, PostgreSQL và địa chỉ API.'
              : 'Lỗi gọi API: ${e.message ?? 'không rõ nguyên nhân'}');
      throw ApiException(message, statusCode: e.response?.statusCode);
    }
  }

  Map<String, dynamic> _map(dynamic value) => Map<String, dynamic>.from(value as Map);
  List<Map<String, dynamic>> _list(dynamic value) => (value as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();

  Future<Map<String, dynamic>> login(String identifier, String password) async => _map(await _call(client.dio.post('auth/login', data: {'identifier': identifier, 'password': password})));
  Future<Map<String, dynamic>> getCurrentUser() async => _map(await _call(client.dio.get('auth/me')));
  Future<void> register({required String name, required String username, required String email, required String password, required String birthDate, required String gender}) async {
    // SMTP email delivery happens synchronously in the registration endpoint.
    // Use a longer per-request timeout so the email can be sent and the API
    // success response can reach Flutter before we decide whether to show the
    // verification-code screen.
    await _call(client.dio.post(
      'auth/register',
      data: {'name': name, 'username': username, 'email': email, 'password': password, 'birthDate': birthDate, 'gender': gender},
      options: Options(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ),
    ));
  }
  Future<void> verifyEmail(String email, String code) async {
    await _call(client.dio.post('auth/verify-email', data: {'email': email, 'code': code}));
  }
  Future<Map<String, dynamic>> becomeAuthor({required String penName, required String experience, required bool termsAccepted}) async => _map(await _call(client.dio.post('auth/become-author', data: {'penName': penName, 'experience': experience, 'termsAccepted': termsAccepted})));
  Future<List<Map<String, dynamic>>> getComics({String? query}) async {
    final q = query?.trim() ?? '';
    return _list(await _call(q.isEmpty ? client.dio.get('comics') : client.dio.get('comics/search', queryParameters: {'q': q})));
  }
  Future<Map<String, dynamic>> getComicDetail(int comicId) async => _map(await _call(client.dio.get('comics/$comicId')));
  Future<Map<String, dynamic>> getChapter(int chapterId) async => _map(await _call(client.dio.get('chapters/$chapterId')));
  Future<List<Map<String, dynamic>>> getRecommendations(int? userId) async => _list(await _call(client.dio.get('recommendations', queryParameters: userId == null ? null : {'userId': userId})));
  Future<List<Map<String, dynamic>>> getFavorites(int userId) async => _list(await _call(client.dio.get('users/$userId/favorites')));
  Future<void> addFavorite(int userId, int comicId) async { await _call(client.dio.post('favorites', data: {'userId': userId, 'comicId': comicId})); }
  Future<void> removeFavorite(int userId, int comicId) async { await _call(client.dio.delete('favorites', queryParameters: {'userId': userId, 'comicId': comicId})); }
  Future<List<Map<String, dynamic>>> getFollowedAuthors(int userId) async => _list(await _call(client.dio.get('users/$userId/authors')));
  Future<void> followAuthor(int userId, String authorName) async { await _call(client.dio.post('authors/follow', data: {'userId': userId, 'authorName': authorName})); }
  Future<void> unfollowAuthor(int userId, String authorName) async { await _call(client.dio.delete('authors/follow', queryParameters: {'userId': userId, 'authorName': authorName})); }
  Future<List<Map<String, dynamic>>> getHistory(int userId) async => _list(await _call(client.dio.get('users/$userId/history')));
  Future<Map<String, dynamic>> recordHistory(Map<String, dynamic> body) async => _map(await _call(client.dio.post('history', data: body)));
  Future<List<int>> getUnlockedChapterIds(int userId) async {
    final data = await _call(client.dio.get('users/$userId/unlocked-chapters'));
    return (data as List).map((value) => value is int ? value : int.tryParse('$value') ?? 0).where((id) => id > 0).toList();
  }
  Future<Map<String, dynamic>> createPayment({required int userId, required int chapterId, required int amount, required String method}) async => _map(await _call(client.dio.post('payment/create', data: {'userId': userId, 'chapterId': chapterId, 'amount': amount, 'method': method})));
  Future<void> reportComic({required int comicId, required String reasonCode, required String description}) async { await _call(client.dio.post('comics/$comicId/reports', data: {'reasonCode': reasonCode, 'description': description})); }
  Future<Map<String, dynamic>> getModerationQueue() async => _map(await _call(client.dio.get('moderation/queue')));
  Future<Map<String, dynamic>> getModerationPreview(int comicId) async => _map(await _call(client.dio.get('moderation/comics/$comicId/preview')));
  Future<void> decideComic({required int comicId, required String action, String ageRating = 'ALL_AGES', String reason = ''}) async { await _call(client.dio.post('moderation/comics/$comicId/decision', data: {'action': action, 'ageRating': ageRating, 'reason': reason})); }
  Future<Map<String, dynamic>> getModerationChapterPreview(int chapterId) async => _map(await _call(client.dio.get('moderation/chapters/$chapterId/preview')));
  Future<void> decideChapter({required int chapterId, required String action, required String ageRating, String reason = ''}) async { await _call(client.dio.post('moderation/chapters/$chapterId/decision', data: {'action': action, 'ageRating': ageRating, 'reason': reason})); }
  Future<void> decideReport({required int reportId, required String action, String note = ''}) async { await _call(client.dio.post('moderation/reports/$reportId/decision', data: {'action': action, 'note': note})); }
  // Author Studio APIs. Backend checks the authenticated user and ownership on every endpoint.
  Future<List<Map<String, dynamic>>> getAuthorComics() async => _list(await _call(client.dio.get('author/comics')));
  Future<Map<String, dynamic>> getAuthorDashboard() async => _map(await _call(client.dio.get('author/dashboard')));
  Future<Map<String, dynamic>> getAuthorFollowers() async => _map(await _call(client.dio.get('author/followers')));
  Future<Map<String, dynamic>> getAuthorComicFeedback(int comicId) async => _map(await _call(client.dio.get('author/comics/$comicId/feedback')));
  Future<List<Map<String, dynamic>>> getComicComments(int comicId) async => _list(await _call(client.dio.get('comics/$comicId/comments')));
  Future<Map<String, dynamic>> getComicReviews(int comicId) async => _map(await _call(client.dio.get('comics/$comicId/reviews')));
  Future<void> addComicComment({required int comicId, required String content}) async { await _call(client.dio.post('comics/$comicId/comments', data: {'content': content})); }
  Future<void> submitComicReview({required int comicId, required int rating, required String reviewText}) async { await _call(client.dio.post('comics/$comicId/reviews', data: {'rating': rating, 'reviewText': reviewText})); }
  Future<Map<String, dynamic>> getAuthorComicDetail(int comicId) async => _map(await _call(client.dio.get('author/comics/$comicId')));
  Future<Map<String, dynamic>> getAuthorChapterDetail(int chapterId) async => _map(await _call(client.dio.get('author/chapters/$chapterId')));
  Future<Map<String, dynamic>> updateAuthorTextChapter({required int chapterId, required String contentText}) async => _map(await _call(client.dio.put('author/chapters/$chapterId/content', data: {'contentText': contentText})));
  Future<Map<String, dynamic>> createAuthorComic({required String title, required String author, required String description, required String coverUrl, required List<String> tags, String suggestedAgeRating = 'ALL_AGES'}) async => _map(await _call(client.dio.post('author/comics', data: {'title': title, 'author': author, 'description': description, 'coverUrl': coverUrl, 'tags': tags, 'suggestedAgeRating': suggestedAgeRating})));
  Future<Map<String, dynamic>> updateAuthorComic({required int comicId, required String title, required String author, required String description, required String coverUrl, required List<String> tags, String suggestedAgeRating = 'ALL_AGES'}) async => _map(await _call(client.dio.put('author/comics/$comicId', data: {'title': title, 'author': author, 'description': description, 'coverUrl': coverUrl, 'tags': tags, 'suggestedAgeRating': suggestedAgeRating})));
  Future<Map<String, dynamic>> createAuthorChapter({required int comicId, required int chapterNumber, required String title, String contentType = 'IMAGE', String contentText = '', String suggestedAgeRating = 'ALL_AGES'}) async => _map(await _call(client.dio.post('author/comics/$comicId/chapters', data: {'chapterNumber': chapterNumber, 'title': title, 'contentType': contentType, 'contentText': contentText, 'suggestedAgeRating': suggestedAgeRating})));

  Future<Map<String, dynamic>> importAuthorChapters({required int comicId, required int startingChapterNumber, required String title, required String mode, required String suggestedAgeRating, required List<Map<String, dynamic>> files}) async {
    final form = FormData();
    form.fields.add(MapEntry('startingChapterNumber', '$startingChapterNumber'));
    form.fields.add(MapEntry('title', title));
    form.fields.add(MapEntry('mode', mode));
    form.fields.add(MapEntry('suggestedAgeRating', suggestedAgeRating));
    if (files.any((f) => (f['relativePath'] ?? '').toString().isNotEmpty)) {
      form.fields.add(MapEntry('relativePaths', jsonEncode(files.map((f) => (f['relativePath'] ?? f['name']).toString()).toList())));
    }
    for (final file in files) {
      final name = (file['name'] ?? 'upload.bin').toString();
      final bytes = List<int>.from(file['bytes'] as List);
      final lower = name.toLowerCase();
      String mediaType = 'application/octet-stream';
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) mediaType = 'image/jpeg';
      else if (lower.endsWith('.png')) mediaType = 'image/png';
      else if (lower.endsWith('.webp')) mediaType = 'image/webp';
      else if (lower.endsWith('.pdf')) mediaType = 'application/pdf';
      else if (lower.endsWith('.zip') || lower.endsWith('.cbz')) mediaType = 'application/zip';
      else if (lower.endsWith('.txt') || lower.endsWith('.md')) mediaType = 'text/plain';
      form.files.add(MapEntry('files', MultipartFile.fromBytes(bytes, filename: name.split('\\').last, contentType: MediaType.parse(mediaType))));
    }
    return _map(await _call(client.dio.post('author/comics/$comicId/import', data: form, options: Options(sendTimeout: const Duration(minutes: 5), receiveTimeout: const Duration(minutes: 5)))));
  }
  Future<Map<String, dynamic>> uploadCoverBytes({required List<int> bytes, required String filename}) async {
    final lower = filename.toLowerCase();
    final subtype = lower.endsWith('.png') ? 'png' : lower.endsWith('.webp') ? 'webp' : lower.endsWith('.gif') ? 'gif' : 'jpeg';
    final multipart = MultipartFile.fromBytes(bytes, filename: filename, contentType: MediaType('image', subtype));
    final result = _map(await _call(client.dio.post('upload/cover', data: FormData.fromMap({'file': multipart}))));
    return result;
  }
  Future<Map<String, dynamic>> uploadAuthorPage({required int chapterId, required int pageNumber, required List<int> bytes, required String filename}) async {
    final lower = filename.toLowerCase();
    final subtype = lower.endsWith('.png') ? 'png' : lower.endsWith('.webp') ? 'webp' : 'jpeg';
    final multipart = MultipartFile.fromBytes(bytes, filename: filename, contentType: MediaType('image', subtype));
    return _map(await _call(client.dio.post('author/chapters/$chapterId/pages', data: FormData.fromMap({'file': multipart, 'pageNumber': pageNumber}))));
  }
  Future<void> deleteAuthorComic(int comicId) async { await _call(client.dio.delete('author/comics/$comicId')); }
  Future<List<Map<String, dynamic>>> getAdminUsers() async => _list(await _call(client.dio.get('admin/users')));
  Future<Map<String, dynamic>> getAdminSummary() async => _map(await _call(client.dio.get('admin/summary')));
  Future<Map<String, dynamic>> getAdminUsersPage({required String search, required String role, required int page, required int size}) async => _map(await _call(client.dio.get('admin/users/search', queryParameters: {'q': search, 'role': role, 'page': page, 'size': size})));
  Future<void> changeUserRole({required int userId, required String role}) async { await _call(client.dio.patch('admin/users/$userId/role', data: {'role': role})); }
}

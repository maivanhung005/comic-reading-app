import 'dart:convert';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/comic_entity.dart';
import '../../domain/entities/downloaded_chapter_entity.dart';
import '../../domain/entities/reading_history_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/comic_repository.dart';
import '../../domain/services/recommendation_engine.dart';
import '../datasources/local/local_data_source.dart';
import '../datasources/remote/remote_data_source.dart';
import '../models/chapter_model.dart';
import '../models/comic_model.dart';
import '../models/reading_history_model.dart';
import '../models/user_model.dart';

class ComicRepositoryImpl implements ComicRepository {
  final RemoteDataSource remote;
  final LocalDataSource local;
  ComicRepositoryImpl({required this.remote, required this.local});

  @override
  Future<UserEntity> login(String identifier, String password) async => UserModel.fromAuthResponse(await remote.login(identifier.trim(), password));

  @override
  Future<UserEntity> refreshCurrentUser() async => UserModel.fromAuthResponse(await remote.getCurrentUser());

  @override
  Future<void> register({required String name, required String username, required String email, required String password, required String birthDate, required String gender}) => remote.register(
    name: name.trim(), username: username.trim(), email: email.trim(), password: password, birthDate: birthDate, gender: gender,
  );

  @override
  Future<void> verifyEmail(String email, String code) => remote.verifyEmail(email.trim(), code.trim());

  @override
  Future<UserEntity> becomeAuthor({required String penName, required String experience, required bool termsAccepted}) async => UserModel.fromAuthResponse(await remote.becomeAuthor(penName: penName.trim(), experience: experience.trim(), termsAccepted: termsAccepted));

  @override
  Future<List<ComicEntity>> getComics({String? query}) async {
    try {
      final rows = await remote.getComics(query: query);
      final comics = rows.map(ComicModel.fromJson).toList();
      if ((query ?? '').trim().isEmpty) await local.cacheComics(comics.map((c) => ComicModel.fromEntity(c).toJson()).toList());
      return comics;
    } catch (error) {
      if ((query ?? '').trim().isNotEmpty) {
        final cached = await local.getCachedComics();
        final q = query!.toLowerCase();
        return cached.map(ComicModel.fromJson).where((c) => c.title.toLowerCase().contains(q) || c.author.toLowerCase().contains(q)).toList();
      }
      final cached = await local.getCachedComics();
      if (cached.isNotEmpty) return cached.map(ComicModel.fromJson).toList();
      if (error is ApiException) rethrow;
      throw const ApiException('Không tải được danh sách truyện.');
    }
  }

  @override
  Future<List<ComicEntity>> getRecommendations(int? userId, List<int> interactedComicIds) async {
    try {
      final serverRanked = (await remote.getRecommendations(userId)).map(ComicModel.fromJson).toList();
      if (interactedComicIds.isEmpty) {
        return serverRanked.map((comic) => comic.copyWith(similarityScore: 0.5)).toList();
      }
      // API xếp hạng theo lịch sử server; tính điểm tag ở client để UI hiển thị độ phù hợp.
      return RecommendationEngine.recommend(serverRanked, interactedComicIds);
    } catch (_) {
      final comics = await getComics();
      return RecommendationEngine.recommend(comics, interactedComicIds);
    }
  }

  @override
  Future<ComicEntity> getComicDetail(int comicId) async {
    final response = await remote.getComicDetail(comicId);
    final comic = ComicModel.fromJson(Map<String, dynamic>.from(response['comic'] as Map));
    final chapters = (response['chapters'] as List? ?? const [])
        .map((row) => ChapterModel.fromJson(Map<String, dynamic>.from(row as Map), comicId: comicId)).toList();
    return comic.copyWith(chapters: chapters);
  }

  @override
  Future<ChapterEntity> getChapter(int comicId, int chapterId) async {
    try {
      final response = await remote.getChapter(chapterId);
      final chapterJson = Map<String, dynamic>.from(response['chapter'] as Map);
      chapterJson['pages'] = response['pages'] ?? const [];
      return ChapterModel.fromJson(chapterJson, comicId: comicId);
    } catch (error) {
      final cached = await getDownloadedChapter(chapterId);
      if (cached != null) return cached;
      if (error is ApiException) rethrow;
      throw const ApiException('Không tải được chương truyện và không có bản offline.');
    }
  }

  @override
  Future<Set<int>> getFavoriteIds(int userId) async {
    await _syncFavoriteQueue(userId);
    try {
      final rows = await remote.getFavorites(userId);
      final ids = rows.map((row) => _int(row['comicId'] ?? row['comic_id'])).where((id) => id > 0).toList();
      await local.replaceFavoritesFromServer(userId, ids);
    } catch (_) {
      // Giữ bản local và các thao tác đang chờ nếu máy chủ tạm thời mất kết nối.
    }
    return local.getFavoriteIds(userId);
  }

  @override
  Future<void> setFavorite(int userId, int comicId, bool isFavorite) async {
    await local.setFavoriteLocal(userId, comicId, isFavorite);
    await _syncFavoriteQueue(userId);
  }

  @override
  Future<Set<String>> getFollowedAuthors(int userId) async {
    await _syncAuthorFollowQueue(userId);
    try {
      final rows = await remote.getFollowedAuthors(userId);
      final names = rows.map((row) => (row['authorName'] ?? row['author_name'] ?? '').toString().trim()).where((name) => name.isNotEmpty).toList();
      await local.replaceFollowedAuthorsFromServer(userId, names);
    } catch (_) {
      // Use the local cache when offline; pending changes are retained.
    }
    return local.getFollowedAuthors(userId);
  }

  @override
  Future<void> setFollowedAuthor(int userId, String authorName, bool isFollowing) async {
    final cleanName = authorName.trim();
    if (cleanName.isEmpty) return;
    await local.setFollowedAuthorLocal(userId, cleanName, isFollowing);
    await _syncAuthorFollowQueue(userId);
  }

  Future<void> _syncAuthorFollowQueue(int userId) async {
    final queue = await local.getAuthorFollowQueue(userId);
    for (final operation in queue) {
      final name = (operation['author_name'] ?? '').toString().trim();
      final shouldFollow = _int(operation['is_following']) == 1;
      if (name.isEmpty) {
        await local.clearAuthorFollowQueue(userId, name);
        continue;
      }
      try {
        if (shouldFollow) {
          await remote.followAuthor(userId, name);
        } else {
          await remote.unfollowAuthor(userId, name);
        }
        await local.clearAuthorFollowQueue(userId, name);
      } catch (_) {
        // Keep the queued change for the next refresh or connectivity recovery.
      }
    }
  }

  Future<void> _syncFavoriteQueue(int userId) async {
    final queue = await local.getFavoriteQueue(userId);
    for (final operation in queue) {
      final comicId = _int(operation['comic_id']);
      final shouldFavorite = _int(operation['is_favorite']) == 1;
      try {
        if (shouldFavorite) {
          await remote.addFavorite(userId, comicId);
        } else {
          await remote.removeFavorite(userId, comicId);
        }
        await local.clearFavoriteQueue(userId, comicId);
      } catch (_) {
        // Không xóa hàng đợi; lần tải lại hoặc kéo để làm mới tiếp theo sẽ thử đồng bộ lại.
      }
    }
  }

  @override
  Future<List<ReadingHistoryEntity>> getReadingHistory(int userId) async {
    await syncPendingChanges(userId);
    try {
      final remoteRows = await remote.getHistory(userId);
      await local.mergeHistoryFromServer(userId, remoteRows);
    } catch (_) {
      // Trả về lịch sử đã cache nếu offline.
    }
    final rows = await local.getHistoryRows(userId);
    return rows.map((row) => ReadingHistoryModel.fromJson(row, fallbackUserId: userId)).toList();
  }

  @override
  Future<void> recordReading(ReadingHistoryEntity entry) async {
    await local.addHistoryPending(
      userId: entry.userId, comicId: entry.comicId, chapterId: entry.chapterId,
      chapterNumber: entry.chapterNumber, pageNumber: entry.pageNumber,
    );
    await syncPendingChanges(entry.userId);
  }

  @override
  Future<void> syncPendingChanges(int userId) async {
    await _syncFavoriteQueue(userId);
    await _syncAuthorFollowQueue(userId);
    final pending = await local.getPendingHistory(userId);
    for (final row in pending) {
      final localId = _int(row['local_id']);
      try {
        final response = await remote.recordHistory({
          'userId': userId, 'comicId': _int(row['comic_id']), 'chapterId': _int(row['chapter_id']),
          'chapterNumber': _int(row['chapter_number']), 'pageNumber': _int(row['page_number']),
        });
        await local.markHistorySynced(localId, _int(response['id']));
      } catch (_) {
        // Dữ liệu lịch sử còn ở SQLite, lần đồng bộ kế tiếp sẽ gửi lại.
      }
    }
  }

  @override
  Future<Set<int>> getUnlockedChapterIds(int userId) async {
    try {
      final ids = await remote.getUnlockedChapterIds(userId);
      await local.replaceUnlocked(userId, ids);
      return ids.toSet();
    } catch (_) {
      return local.getUnlockedIds(userId);
    }
  }

  @override
  Future<bool> createPayment({required int userId, required int chapterId, required int amount, required String method}) async {
    try {
      await remote.createPayment(userId: userId, chapterId: chapterId, amount: amount, method: method);
      await local.saveUnlockedLocal(userId, chapterId, method);
      return true;
    } catch (_) {
      // Không tự báo thanh toán thành công khi máy chủ chưa xác nhận.
      return false;
    }
  }

  @override
  Future<void> downloadChapter(ComicEntity comic, ChapterEntity chapter) async {
    final payload = jsonEncode(ChapterModel.fromEntity(chapter).toJson());
    await local.saveDownloadedChapter(comic, chapter, payload);
  }

  @override
  Future<ChapterEntity?> getDownloadedChapter(int chapterId) async {
    final payload = await local.getDownloadedChapterPayload(chapterId);
    if (payload == null) return null;
    final json = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    final comicId = _int(json['comicId']);
    return ChapterModel.fromJson(json, comicId: comicId);
  }

  @override
  Future<List<DownloadedChapterEntity>> getDownloadedChapters() async {
    final rows = await local.getDownloadedChapters();
    return rows.map((row) => DownloadedChapterEntity(
      chapterId: _int(row['chapter_id']),
      comicId: _int(row['comic_id']),
      comicTitle: (row['comic_title'] ?? '').toString(),
      chapterTitle: (row['chapter_title'] ?? '').toString(),
      chapterNumber: _int(row['chapter_number']),
      downloadedAt: DateTime.tryParse((row['downloaded_at'] ?? '').toString()) ?? DateTime.now(),
    )).toList();
  }

  @override
  Future<bool> isChapterDownloaded(int chapterId) => local.isChapterDownloaded(chapterId);

  static int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
}

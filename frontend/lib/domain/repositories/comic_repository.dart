import '../entities/comic_entity.dart';
import '../entities/downloaded_chapter_entity.dart';
import '../entities/reading_history_entity.dart';
import '../entities/user_entity.dart';

abstract class ComicRepository {
  Future<UserEntity> login(String identifier, String password);
  Future<UserEntity> refreshCurrentUser();
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String birthDate,
    required String gender,
  });
  Future<void> verifyEmail(String email, String code);
  Future<UserEntity> becomeAuthor({required String penName, required String experience, required bool termsAccepted});
  Future<List<ComicEntity>> getComics({String? query});
  Future<List<ComicEntity>> getRecommendations(int? userId, List<int> interactedComicIds);
  Future<ComicEntity> getComicDetail(int comicId);
  Future<ChapterEntity> getChapter(int comicId, int chapterId);
  Future<Set<int>> getFavoriteIds(int userId);
  Future<void> setFavorite(int userId, int comicId, bool isFavorite);
  Future<Set<String>> getFollowedAuthors(int userId);
  Future<void> setFollowedAuthor(int userId, String authorName, bool isFollowing);
  Future<List<ReadingHistoryEntity>> getReadingHistory(int userId);
  Future<void> recordReading(ReadingHistoryEntity entry);
  Future<void> syncPendingChanges(int userId);
  Future<Set<int>> getUnlockedChapterIds(int userId);
  Future<bool> createPayment({required int userId, required int chapterId, required int amount, required String method});
  Future<void> downloadChapter(ComicEntity comic, ChapterEntity chapter);
  Future<ChapterEntity?> getDownloadedChapter(int chapterId);
  Future<List<DownloadedChapterEntity>> getDownloadedChapters();
  Future<bool> isChapterDownloaded(int chapterId);
}

import '../entities/reading_history_entity.dart';
import '../repositories/comic_repository.dart';

class GetFavoritesUseCase { final ComicRepository repository; GetFavoritesUseCase(this.repository); Future<Set<int>> call(int userId) => repository.getFavoriteIds(userId); }
class ToggleFavoriteUseCase { final ComicRepository repository; ToggleFavoriteUseCase(this.repository); Future<void> call(int userId, int comicId, bool value) => repository.setFavorite(userId, comicId, value); }
class GetFollowedAuthorsUseCase { final ComicRepository repository; GetFollowedAuthorsUseCase(this.repository); Future<Set<String>> call(int userId) => repository.getFollowedAuthors(userId); }
class ToggleFollowAuthorUseCase { final ComicRepository repository; ToggleFollowAuthorUseCase(this.repository); Future<void> call(int userId, String authorName, bool value) => repository.setFollowedAuthor(userId, authorName, value); }
class GetHistoryUseCase { final ComicRepository repository; GetHistoryUseCase(this.repository); Future<List<ReadingHistoryEntity>> call(int userId) => repository.getReadingHistory(userId); }
class RecordReadingUseCase { final ComicRepository repository; RecordReadingUseCase(this.repository); Future<void> call(ReadingHistoryEntity entry) => repository.recordReading(entry); }
class SyncPendingChangesUseCase { final ComicRepository repository; SyncPendingChangesUseCase(this.repository); Future<void> call(int userId) => repository.syncPendingChanges(userId); }

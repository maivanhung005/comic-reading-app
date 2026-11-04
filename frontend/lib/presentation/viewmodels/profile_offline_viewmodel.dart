import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/reading_history_entity.dart';
import '../../domain/entities/downloaded_chapter_entity.dart';
import '../../domain/usecases/library_usecases.dart';
import '../../domain/usecases/offline_usecases.dart';

class ProfileOfflineViewModel extends ChangeNotifier {
  final GetFavoritesUseCase getFavoritesUseCase;
  final ToggleFavoriteUseCase toggleFavoriteUseCase;
  final GetFollowedAuthorsUseCase getFollowedAuthorsUseCase;
  final ToggleFollowAuthorUseCase toggleFollowAuthorUseCase;
  final GetHistoryUseCase getHistoryUseCase;
  final GetDownloadedChaptersUseCase getDownloadsUseCase;
  final SyncPendingChangesUseCase syncPendingChangesUseCase;

  ProfileOfflineViewModel({required this.getFavoritesUseCase, required this.toggleFavoriteUseCase, required this.getFollowedAuthorsUseCase, required this.toggleFollowAuthorUseCase, required this.getHistoryUseCase, required this.getDownloadsUseCase, required this.syncPendingChangesUseCase});

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  String _avatarEmoji = '🌙';
  String get avatarEmoji => _avatarEmoji;
  Set<int> _favoriteIds = {};
  Set<int> get favoriteIds => _favoriteIds;
  Set<String> _followedAuthors = {};
  Set<String> get followedAuthors => _followedAuthors;
  List<ReadingHistoryEntity> _history = [];
  List<ReadingHistoryEntity> get history => _history;
  List<DownloadedChapterEntity> _downloads = [];
  List<DownloadedChapterEntity> get downloads => _downloads;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  String? _error;
  String? get error => _error;

  Future<void> initializeTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    _avatarEmoji = prefs.getString('demo_avatar') ?? '🌙';
    notifyListeners();
  }

  Future<void> loadUserData(int userId) async {
    _isSyncing = true; _error = null; notifyListeners();
    try {
      await syncPendingChangesUseCase(userId);
      _favoriteIds = await getFavoritesUseCase(userId);
      _followedAuthors = await getFollowedAuthorsUseCase(userId);
      _history = await getHistoryUseCase(userId);
      _downloads = await getDownloadsUseCase();
    } catch (e) {
      _error = 'Không thể tải đầy đủ thư viện: $e';
    } finally { _isSyncing = false; notifyListeners(); }
  }

  Future<void> toggleFavorite(int userId, int comicId) async {
    final next = !_favoriteIds.contains(comicId);
    await toggleFavoriteUseCase(userId, comicId, next);
    _favoriteIds = {..._favoriteIds};
    if (next) { _favoriteIds.add(comicId); } else { _favoriteIds.remove(comicId); }
    notifyListeners();
  }

  bool isFavorite(int comicId) => _favoriteIds.contains(comicId);

  bool isFollowingAuthor(String authorName) => _followedAuthors.any((name) => name.trim().toLowerCase() == authorName.trim().toLowerCase());

  Future<void> toggleFollowAuthor(int userId, String authorName) async {
    final cleanName = authorName.trim();
    if (cleanName.isEmpty) return;
    final isFollowing = isFollowingAuthor(cleanName);
    await toggleFollowAuthorUseCase(userId, cleanName, !isFollowing);
    _followedAuthors = {..._followedAuthors.where((name) => name.trim().toLowerCase() != cleanName.toLowerCase())};
    if (!isFollowing) _followedAuthors.add(cleanName);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    notifyListeners();
  }

  Future<void> setAvatar(String value) async {
    _avatarEmoji = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('demo_avatar', value);
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/comic_entity.dart';
import '../../domain/usecases/offline_usecases.dart';
import '../../domain/usecases/comic_usecases.dart';

class HomeViewModel extends ChangeNotifier {
  final GetComicsUseCase getComicsUseCase;
  final GetRecommendationsUseCase getRecommendationsUseCase;
  final GetComicDetailUseCase getComicDetailUseCase;
  final GetChapterUseCase getChapterUseCase;
  final GetDownloadedChapterUseCase getDownloadedChapterUseCase;
  final DownloadChapterUseCase downloadChapterUseCase;

  HomeViewModel({required this.getComicsUseCase, required this.getRecommendationsUseCase, required this.getComicDetailUseCase, required this.getChapterUseCase, required this.getDownloadedChapterUseCase, required this.downloadChapterUseCase});

  List<ComicEntity> _comics = [];
  List<ComicEntity> get comics => _comics;
  List<ComicEntity> _recommendations = [];
  List<ComicEntity> get recommendations => _recommendations;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;
  String _query = '';
  String get query => _query;

  List<ComicEntity> get filteredComics {
    if (_query.trim().isEmpty) return _comics;
    final q = _query.toLowerCase().trim();
    return _comics.where((c) => c.title.toLowerCase().contains(q) || c.author.toLowerCase().contains(q) || c.tags.any((t) => t.toLowerCase().contains(q))).toList();
  }

  Future<void> loadHomeData({required int? userId, List<int> interactedIds = const []}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _comics = await getComicsUseCase();
      _recommendations = await getRecommendationsUseCase(userId, interactedIds);
    } catch (e) {
      _error = e is ApiException ? e.message : 'Không tải được dữ liệu: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ComicEntity> loadComicDetail(int comicId) => getComicDetailUseCase(comicId);

  Future<ChapterEntity?> loadDownloadedChapter(int chapterId) => getDownloadedChapterUseCase(chapterId);

  Future<void> downloadChapter(ComicEntity comic, ChapterEntity chapter) async {
    final fullChapter = await getChapterUseCase(comic.id, chapter.id);
    await downloadChapterUseCase(comic, fullChapter);
  }
  void updateQuery(String value) { _query = value; notifyListeners(); }
}

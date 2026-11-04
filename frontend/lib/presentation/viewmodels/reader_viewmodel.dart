import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/comic_entity.dart';
import '../../domain/entities/reading_history_entity.dart';
import '../../domain/usecases/comic_usecases.dart';
import '../../domain/usecases/library_usecases.dart';

class ReaderViewModel extends ChangeNotifier {
  final GetChapterUseCase getChapterUseCase;
  final RecordReadingUseCase recordReadingUseCase;
  final FlutterTts _tts = FlutterTts();

  ReaderViewModel({required this.getChapterUseCase, required this.recordReadingUseCase}) {
    _tts.setLanguage('vi-VN');
    _tts.setCompletionHandler(() { _isSpeaking = false; notifyListeners(); });
  }

  ChapterEntity? _chapter;
  ChapterEntity? get chapter => _chapter;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;
  int _currentPage = 0;
  int get currentPage => _currentPage;
  bool _verticalMode = false;
  bool get verticalMode => _verticalMode;
  double _brightness = 1;
  double get brightness => _brightness;
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;
  double _speechSpeed = 1;
  double get speechSpeed => _speechSpeed;
  int _userId = 0;
  int _comicId = 0;

  Future<void> loadChapter(ComicEntity comic, ChapterEntity chapter, int userId) async {
    _isLoading = true; _error = null; _currentPage = 0; _comicId = comic.id; _userId = userId;
    _chapter = chapter;
    notifyListeners();
    try {
      _chapter = await getChapterUseCase(comic.id, chapter.id);
      final isText = _chapter!.contentType.toUpperCase() == 'TEXT';
      if (isText) {
        if (_chapter!.contentText.trim().isEmpty) _error = 'Chương chữ chưa có nội dung.';
        else await _recordReadingStart();
      } else if (_chapter!.pages.isEmpty) {
        _error = 'Chương này chưa có trang ảnh trong dữ liệu máy chủ.';
      } else {
        await _recordPage(0);
      }
    } catch (e) {
      _error = e is ApiException ? e.message : 'Không mở được chương truyện: $e';
    } finally { _isLoading = false; notifyListeners(); }
  }

  Future<void> setPage(int index) async {
    if (_chapter == null || index < 0 || index >= _chapter!.pages.length) return;
    _currentPage = index;
    notifyListeners();
    await _recordPage(index);
  }

  Future<void> _recordReadingStart() async {
    if (_chapter == null || _userId <= 0) return;
    try {
      await recordReadingUseCase(ReadingHistoryEntity(
        id: 0, userId: _userId, comicId: _comicId, chapterId: _chapter!.id,
        chapterNumber: _chapter!.chapterNumber, pageNumber: 1, readAt: DateTime.now(),
      ));
    } catch (_) {
      // Repository lưu bản pending trong SQLite nếu chưa thể đồng bộ.
    }
  }

  Future<void> _recordPage(int index) async {
    if (_chapter == null || _userId <= 0 || _chapter!.pages.isEmpty) return;
    try {
      await recordReadingUseCase(ReadingHistoryEntity(
        id: 0, userId: _userId, comicId: _comicId, chapterId: _chapter!.id,
        chapterNumber: _chapter!.chapterNumber, pageNumber: _chapter!.pages[index].pageNumber,
        readAt: DateTime.now(),
      ));
    } catch (_) {
      // Repository đã lưu bản pending trong SQLite trước khi thử đồng bộ.
    }
  }

  void toggleReadingMode(bool vertical) { _verticalMode = vertical; notifyListeners(); }
  void setBrightness(double value) { _brightness = value.clamp(0.35, 1.0).toDouble(); notifyListeners(); }

  Future<void> toggleSpeak() async {
    final current = _chapter;
    if (current == null) return;
    final isText = current.contentType.toUpperCase() == 'TEXT';
    if (isText && current.contentText.trim().isEmpty) return;
    if (!isText && current.pages.isEmpty) return;
    if (_isSpeaking) {
      await _tts.stop(); _isSpeaking = false;
    } else {
      _isSpeaking = true;
      final text = isText
          ? current.contentText
          : (current.pages[_currentPage].dialogue.isNotEmpty
              ? current.pages[_currentPage].dialogue
              : 'Chương ${current.chapterNumber}, trang ${current.pages[_currentPage].pageNumber}, ${current.title}');
      await _tts.setSpeechRate(_speechSpeed * 0.5);
      await _tts.speak(text);
    }
    notifyListeners();
  }

  Future<void> changeSpeed(double speed) async {
    _speechSpeed = speed; notifyListeners();
    if (_isSpeaking) { await _tts.stop(); _isSpeaking = false; await toggleSpeak(); }
  }

  @override
  void dispose() { _tts.stop(); super.dispose(); }
}

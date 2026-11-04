import '../entities/comic_entity.dart';
import '../entities/downloaded_chapter_entity.dart';
import '../repositories/comic_repository.dart';

class DownloadChapterUseCase {
  final ComicRepository repository;
  DownloadChapterUseCase(this.repository);
  Future<void> call(ComicEntity comic, ChapterEntity chapter) => repository.downloadChapter(comic, chapter);
}

class GetDownloadedChaptersUseCase {
  final ComicRepository repository;
  GetDownloadedChaptersUseCase(this.repository);
  Future<List<DownloadedChapterEntity>> call() => repository.getDownloadedChapters();
}

class GetDownloadedChapterUseCase {
  final ComicRepository repository;
  GetDownloadedChapterUseCase(this.repository);
  Future<ChapterEntity?> call(int chapterId) => repository.getDownloadedChapter(chapterId);
}

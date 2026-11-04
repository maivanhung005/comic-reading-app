import '../entities/comic_entity.dart';
import '../repositories/comic_repository.dart';

class GetComicsUseCase { final ComicRepository repository; GetComicsUseCase(this.repository); Future<List<ComicEntity>> call({String? query}) => repository.getComics(query: query); }
class GetRecommendationsUseCase { final ComicRepository repository; GetRecommendationsUseCase(this.repository); Future<List<ComicEntity>> call(int? userId, List<int> interactedIds) => repository.getRecommendations(userId, interactedIds); }
class GetComicDetailUseCase { final ComicRepository repository; GetComicDetailUseCase(this.repository); Future<ComicEntity> call(int comicId) => repository.getComicDetail(comicId); }
class GetChapterUseCase { final ComicRepository repository; GetChapterUseCase(this.repository); Future<ChapterEntity> call(int comicId, int chapterId) => repository.getChapter(comicId, chapterId); }

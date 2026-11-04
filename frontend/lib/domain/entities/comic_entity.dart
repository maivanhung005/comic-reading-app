class PageEntity {
  final int id;
  final int pageNumber;
  final String imageUrl;
  final String dialogue;

  const PageEntity({
    this.id = 0,
    required this.pageNumber,
    required this.imageUrl,
    this.dialogue = '',
  });
}

class ChapterEntity {
  final int id;
  final int comicId;
  final int chapterNumber;
  final String title;
  final bool isVip;
  final int price;
  final List<PageEntity> pages;
  /// TEXT chapters render readable prose; IMAGE chapters render page images.
  final String contentType;
  final String contentText;

  const ChapterEntity({
    required this.id,
    required this.comicId,
    required this.chapterNumber,
    required this.title,
    this.isVip = false,
    this.price = 0,
    this.pages = const [],
    this.contentType = 'IMAGE',
    this.contentText = '',
  });

  ChapterEntity copyWith({List<PageEntity>? pages, String? contentType, String? contentText}) => ChapterEntity(
        id: id,
        comicId: comicId,
        chapterNumber: chapterNumber,
        title: title,
        isVip: isVip,
        price: price,
        pages: pages ?? this.pages,
        contentType: contentType ?? this.contentType,
        contentText: contentText ?? this.contentText,
      );
}

class ComicEntity {
  final int id;
  final String title;
  final String author;
  final String description;
  final String coverUrl;
  final List<String> tags;
  final String status;
  final int views;
  final List<ChapterEntity> chapters;
  final double similarityScore;

  const ComicEntity({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverUrl,
    this.tags = const [],
    this.status = 'Đang tiến hành',
    this.views = 0,
    this.chapters = const [],
    this.similarityScore = 0,
  });

  ComicEntity copyWith({List<ChapterEntity>? chapters, double? similarityScore}) => ComicEntity(
        id: id,
        title: title,
        author: author,
        description: description,
        coverUrl: coverUrl,
        tags: tags,
        status: status,
        views: views,
        chapters: chapters ?? this.chapters,
        similarityScore: similarityScore ?? this.similarityScore,
      );
}

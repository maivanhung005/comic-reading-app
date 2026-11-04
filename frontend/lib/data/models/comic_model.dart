import '../../core/constants/api_constants.dart';
import '../../domain/entities/comic_entity.dart';
import 'chapter_model.dart';

class ComicModel extends ComicEntity {
  const ComicModel({
    required super.id,
    required super.title,
    required super.author,
    required super.description,
    required super.coverUrl,
    super.tags,
    super.status,
    super.views,
    super.chapters,
    super.similarityScore,
  });

  factory ComicModel.fromJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    final chapters = (json['chapters'] as List? ?? const [])
        .map((item) => ChapterModel.fromJson(Map<String, dynamic>.from(item as Map), comicId: id))
        .toList();
    return ComicModel(
      id: id,
      title: (json['title'] ?? 'Untitled comic').toString(),
      author: (json['author'] ?? 'Đang cập nhật').toString(),
      description: (json['description'] ?? '').toString(),
      coverUrl: ApiConstants.resolveMediaUrl((json['coverUrl'] ?? json['cover_url'] ?? '').toString()),
      tags: (json['tags'] as List? ?? const []).map((e) => e.toString()).toList(),
      status: (json['status'] ?? 'Đang tiến hành').toString(),
      views: _int(json['views']),
      chapters: chapters,
      similarityScore: (json['similarityScore'] as num?)?.toDouble() ?? 0,
    );
  }

  factory ComicModel.fromEntity(ComicEntity entity) => ComicModel(
        id: entity.id, title: entity.title, author: entity.author, description: entity.description,
        coverUrl: entity.coverUrl, tags: entity.tags, status: entity.status, views: entity.views,
        chapters: entity.chapters, similarityScore: entity.similarityScore,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'title': title, 'author': author, 'description': description,
        'coverUrl': coverUrl, 'tags': tags, 'status': status, 'views': views,
        'chapters': chapters.map((c) => ChapterModel.fromEntity(c).toJson()).toList(),
        'similarityScore': similarityScore,
      };

  static int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
}

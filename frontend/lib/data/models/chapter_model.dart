import '../../domain/entities/comic_entity.dart';
import 'page_model.dart';

class ChapterModel extends ChapterEntity {
  const ChapterModel({required super.id, required super.comicId, required super.chapterNumber, required super.title, super.isVip, super.price, super.pages, super.contentType, super.contentText});

  factory ChapterModel.fromJson(Map<String, dynamic> json, {required int comicId}) {
    final vip = json['isVip'] ?? json['is_vip'] ?? false;
    return ChapterModel(
      id: _int(json['id']),
      comicId: _int(json['comicId'] ?? json['comic_id']) == 0 ? comicId : _int(json['comicId'] ?? json['comic_id']),
      chapterNumber: _int(json['chapterNumber'] ?? json['chapter_number']),
      title: (json['title'] ?? 'Chương truyện').toString(),
      isVip: vip == true || vip.toString().toLowerCase() == 'true',
      price: _int(json['price']),
      contentType: (json['contentType'] ?? json['content_type'] ?? 'IMAGE').toString().toUpperCase(),
      contentText: (json['contentText'] ?? json['content_text'] ?? '').toString(),
      pages: (json['pages'] as List? ?? const []).map((item) => PageModel.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
    );
  }

  factory ChapterModel.fromEntity(ChapterEntity entity) => ChapterModel(
        id: entity.id, comicId: entity.comicId, chapterNumber: entity.chapterNumber,
        title: entity.title, isVip: entity.isVip, price: entity.price, pages: entity.pages,
        contentType: entity.contentType, contentText: entity.contentText,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'comicId': comicId, 'chapterNumber': chapterNumber, 'title': title,
        'isVip': isVip, 'price': price, 'contentType': contentType, 'contentText': contentText,
        'pages': pages.map((p) => PageModel.fromEntity(p).toJson()).toList(),
      };

  static int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
}

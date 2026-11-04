import '../../core/constants/api_constants.dart';
import '../../domain/entities/comic_entity.dart';

class PageModel extends PageEntity {
  const PageModel({super.id, required super.pageNumber, required super.imageUrl, super.dialogue});

  factory PageModel.fromJson(Map<String, dynamic> json) => PageModel(
        id: _int(json['id']),
        pageNumber: _int(json['pageNumber'] ?? json['page_number']),
        imageUrl: ApiConstants.resolveMediaUrl((json['imageUrl'] ?? json['image_url'] ?? '').toString()),
        dialogue: (json['dialogue'] ?? '').toString(),
      );

  factory PageModel.fromEntity(PageEntity entity) => PageModel(
        id: entity.id, pageNumber: entity.pageNumber, imageUrl: entity.imageUrl, dialogue: entity.dialogue,
      );

  Map<String, dynamic> toJson() => {'id': id, 'pageNumber': pageNumber, 'imageUrl': imageUrl, 'dialogue': dialogue};

  static int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
}

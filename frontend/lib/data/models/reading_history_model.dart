import '../../domain/entities/reading_history_entity.dart';

class ReadingHistoryModel extends ReadingHistoryEntity {
  const ReadingHistoryModel({required super.id, required super.userId, required super.comicId, required super.chapterId, required super.chapterNumber, required super.pageNumber, required super.readAt});

  factory ReadingHistoryModel.fromJson(Map<String, dynamic> json, {int? fallbackUserId}) => ReadingHistoryModel(
        id: _int(json['id'] ?? json['local_id']),
        userId: _int(json['userId'] ?? json['user_id'] ?? fallbackUserId),
        comicId: _int(json['comicId'] ?? json['comic_id']),
        chapterId: _int(json['chapterId'] ?? json['chapter_id']),
        chapterNumber: _int(json['chapterNumber'] ?? json['chapter_number']),
        pageNumber: _int(json['pageNumber'] ?? json['page_number']),
        readAt: DateTime.tryParse((json['readAt'] ?? json['read_at'] ?? '').toString()) ?? DateTime.now(),
      );

  static int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
}

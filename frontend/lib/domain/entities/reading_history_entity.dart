class ReadingHistoryEntity {
  final int id;
  final int userId;
  final int comicId;
  final int chapterId;
  final int chapterNumber;
  final int pageNumber;
  final DateTime readAt;

  const ReadingHistoryEntity({
    required this.id,
    required this.userId,
    required this.comicId,
    required this.chapterId,
    required this.chapterNumber,
    required this.pageNumber,
    required this.readAt,
  });
}

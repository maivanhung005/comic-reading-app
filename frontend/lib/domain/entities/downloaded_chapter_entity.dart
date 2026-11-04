class DownloadedChapterEntity {
  final int chapterId;
  final int comicId;
  final String comicTitle;
  final String chapterTitle;
  final int chapterNumber;
  final DateTime downloadedAt;

  const DownloadedChapterEntity({
    required this.chapterId,
    required this.comicId,
    required this.comicTitle,
    required this.chapterTitle,
    required this.chapterNumber,
    required this.downloadedAt,
  });
}

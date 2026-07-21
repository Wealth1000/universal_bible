/// Book metadata for the reader: number, display name, and per-chapter
/// verse counts (from the translation's precomputed bookChapterCountsJson).
class BookInfo {
  final int number;
  final String name;
  final Map<int, int> chapterCounts;

  BookInfo({
    required this.number,
    required this.name,
    required this.chapterCounts,
  });
}

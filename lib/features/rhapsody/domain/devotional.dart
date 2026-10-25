import 'package:universal_bible/features/rhapsody/application/devotional_body_parser.dart';

/// A single day's Rhapsody devotional, as stored in the Supabase `devotionals`
/// table. This is the clean domain model — the raw `body` HTML is parsed into
/// [bodyParagraphs] once at construction, and the `;`-separated reading lists
/// are split into reference lists. `audio_url` is retained but intentionally
/// not surfaced in the UI.
class Devotional {
  Devotional({
    required this.id,
    required this.date,
    required this.title,
    required this.bodyParagraphs,
    required this.confession,
    required this.imageUrl,
    required this.audioUrl,
    required this.furtherStudy,
    required this.oneYearBible,
    required this.twoYearBible,
  });

  final int id;

  /// Calendar date the devotional is for (date-only; time is meaningless).
  final DateTime date;

  final String title;

  /// Rich body, parsed from the source HTML into paragraphs of styled spans.
  final List<DevotionalParagraph> bodyParagraphs;

  final String confession;

  /// Illustration URL. May be null/empty; the UI reserves space and lazy-loads.
  final String? imageUrl;

  /// Narration URL — kept for future use, never shown.
  final String? audioUrl;

  /// Scripture references for extra reading, in source order.
  final List<String> furtherStudy;
  final List<String> oneYearBible;
  final List<String> twoYearBible;

  bool get hasReadingPlan =>
      furtherStudy.isNotEmpty ||
      oneYearBible.isNotEmpty ||
      twoYearBible.isNotEmpty;

  factory Devotional.fromRow(Map<String, dynamic> row) {
    final rawImage = (row['image'] as String?)?.trim();
    final rawAudio = (row['audio_url'] as String?)?.trim();
    return Devotional(
      id: (row['id'] as num).toInt(),
      date: DateTime.parse(row['date'] as String),
      title: (row['title'] as String? ?? '').trim(),
      bodyParagraphs: parseDevotionalBody(row['body'] as String? ?? ''),
      confession: (row['confession'] as String? ?? '').trim(),
      imageUrl: (rawImage == null || rawImage.isEmpty) ? null : rawImage,
      audioUrl: (rawAudio == null || rawAudio.isEmpty) ? null : rawAudio,
      furtherStudy: parseReferenceList(row['further_study'] as String?),
      oneYearBible: parseReferenceList(row['one_year_bible'] as String?),
      twoYearBible: parseReferenceList(row['two_year_bible'] as String?),
    );
  }
}

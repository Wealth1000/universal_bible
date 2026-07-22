import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canonical daily devotional schema used by all ingestion/display paths.
class DayEntry {
  const DayEntry({
    required this.dateIso,
    required this.title,
    required this.scripture,
    required this.bodyParagraphs,
    required this.confession,
    this.furtherStudy = const <ScriptureRef>[],
    this.scriptureRefs = const <DetectedScriptureRef>[],
    required this.metadata,
  });

  final String dateIso; // YYYY-MM-DD
  final String title;
  final ScriptureBlock scripture;
  final List<String> bodyParagraphs;
  final String confession;
  final List<ScriptureRef> furtherStudy;
  final List<DetectedScriptureRef> scriptureRefs;
  final DayEntryMetadata metadata;
}

class ScriptureBlock {
  const ScriptureBlock({
    required this.reference,
    required this.text,
  });

  final String reference;
  final String text;
}

class ScriptureRef {
  const ScriptureRef({
    required this.reference,
    this.translation,
  });

  final String reference;
  final String? translation;
}

class DetectedScriptureRef {
  const DetectedScriptureRef({
    required this.reference,
    required this.normalized,
    required this.paragraphIndex,
    required this.start,
    required this.end,
    this.text,
  });

  final String reference;
  final String normalized;
  final int paragraphIndex;
  final int start;
  final int end;
  final String? text;
}

class DayEntryMetadata {
  const DayEntryMetadata({
    required this.source,
    required this.hash,
    required this.normalized,
  });

  final String source; // "pdf" or "web"
  final String hash;
  final bool normalized;
}

/// UI-facing adapter over canonical [DayEntry].
class RhapsodyDailyContent {
  const RhapsodyDailyContent(this.entry);

  final DayEntry entry;

  String get dateLabel => entry.dateIso;
  String get title => entry.title;
  String get verseReference => entry.scripture.reference;
  String get verseText => entry.scripture.text;
  String get body => entry.bodyParagraphs.join('\n\n');
  String get confession => entry.confession;
}

/// Placeholder provider. Replace with repository-backed fetch later.
final rhapsodyDailyEntryProvider = Provider<DayEntry>((ref) {
  return const DayEntry(
    dateIso: '2023-10-24',
    title: 'The Power Of His Spoken Word',
    scripture: ScriptureBlock(
      reference: 'Matthew 12:37',
      text:
          'For by thy words thou shalt be justified, and by thy words thou shalt be condemned.',
    ),
    bodyParagraphs: <String>[
      'Every time you speak, you are charting the course of your life. Your words are not just sounds; '
          'they are spiritual vehicles that carry creative or destructive power. In the kingdom of God, we function by speaking.',
      'The Bible says the worlds were framed by the Word of God. The same creative ability resides in your spirit. '
          'When you consistently align your confessions with the truth of God\'s Word, you calibrate your environment '
          'to match His divine purpose for your life.',
      'Refuse to speak words of lack, fear, or defeat. Even when circumstances seem contrary, maintain your confession. '
          'You are what God says you are, and you have what He says you have.',
    ],
    confession:
        'I am a creator of my world. My words are filled with power and life. I walk in divine health, supernatural prosperity, '
        'and unending victory today and always.',
    metadata: DayEntryMetadata(
      source: 'pdf',
      hash: 'placeholder',
      normalized: true,
    ),
  );
});

final rhapsodyDailyContentProvider = Provider<RhapsodyDailyContent>((ref) {
  return RhapsodyDailyContent(ref.watch(rhapsodyDailyEntryProvider));
});


import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/features/bible/data/bible_data_module.dart';

/// Resolves a human scripture reference (e.g. "Proverbs 22:6",
/// "2 Timothy 3:14-15", "Psalm 83") into the actual verse text held in the
/// local Drift database. Used by the Rhapsody devotional's scripture reveal
/// sheet so references become readable passages offline.

/// A parsed reference. [startVerse] null means the whole chapter; [endVerse]
/// null (with a non-null [startVerse]) means a single verse.
class ParsedReference {
  const ParsedReference({
    required this.bookName,
    required this.chapter,
    this.startVerse,
    this.endVerse,
  });

  final String bookName;
  final int chapter;
  final int? startVerse;
  final int? endVerse;
}

/// Trailing translation code (e.g. NIV, KJV, AMPC) tacked onto reading-plan
/// references. Stripped before parsing so it doesn't confuse the book name.
final _trailingCode = RegExp(r'\s+[A-Z]{2,6}$');

/// book (may carry a leading ordinal like "2 Timothy") + chapter, with an
/// optional `:verse` and optional `-endVerse`.
final _refPattern = RegExp(r'^(.+?)\s+(\d+)(?::(\d+)(?:\s*[-–]\s*(\d+))?)?$');

/// Parses [raw] into a [ParsedReference], or null if it doesn't look like a
/// `Book Chapter[:Verse[-Verse]]` reference.
ParsedReference? parseScriptureReference(String raw) {
  final cleaned = raw.trim().replaceFirst(_trailingCode, '').trim();
  final m = _refPattern.firstMatch(cleaned);
  if (m == null) return null;

  final book = m.group(1)!.trim();
  final chapter = int.tryParse(m.group(2)!);
  if (book.isEmpty || chapter == null) return null;

  final start = m.group(3) != null ? int.tryParse(m.group(3)!) : null;
  final end = m.group(4) != null ? int.tryParse(m.group(4)!) : null;

  return ParsedReference(
    bookName: book,
    chapter: chapter,
    startVerse: start,
    endVerse: end,
  );
}

/// Canonicalises a book name/title to a comparison key. Runs the same
/// [cleanBookName] the reader uses (so "2 Timothy", "Psalm"→"Psalms", the
/// "galations" typo etc. all agree), then strips to lowercase alphanumerics so
/// a reference and a raw `bookMapJson` title map to the same key.
String normalizeBookKey(String name) =>
    cleanBookName(name).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

enum PassageStatus { ok, unparseable, bookNotFound, noVerses, noTranslation }

class PassageVerse {
  const PassageVerse({required this.verse, required this.text});

  final int verse;
  final String text;
}

/// The outcome of resolving a reference. [bookNumber]/[chapter] are populated
/// when the reference parsed and matched a book, so callers can offer an
/// "open in reader" action even if the chapter has no verses.
class ResolvedPassage {
  const ResolvedPassage({
    required this.reference,
    required this.status,
    this.translationId,
    this.translationName,
    this.bookNumber,
    this.chapter,
    this.verses = const [],
  });

  final String reference;
  final PassageStatus status;
  final String? translationId;
  final String? translationName;
  final int? bookNumber;
  final int? chapter;
  final List<PassageVerse> verses;
}

/// Deep module that resolves a scripture reference to its passage text.
/// Accepts a [BibleDataModule] adapter so the resolution pipeline is
/// unit-testable without Flutter bindings.
class ScriptureResolver {
  ScriptureResolver({required this.bibleData});

  final BibleDataModule bibleData;

  /// Resolves [reference] to its passage text. Uses [forcedTranslationId]
  /// when provided; otherwise falls back to the first installed translation.
  Future<ResolvedPassage> resolve(
    String reference, {
    String? forcedTranslationId,
  }) async {
    // 1. Determine translation ID
    String? translationId = forcedTranslationId;
    if (translationId == null) {
      final installed = await bibleData.getInstalledTranslations();
      if (installed.isEmpty) {
        return ResolvedPassage(
          reference: reference,
          status: PassageStatus.noTranslation,
        );
      }
      translationId = installed.first.id;
    }

    // 2. Parse the reference
    final parsed = parseScriptureReference(reference);
    if (parsed == null) {
      return ResolvedPassage(
        reference: reference,
        status: PassageStatus.unparseable,
        translationId: translationId,
      );
    }

    // 3. Get the translation
    final translation = await bibleData.getTranslation(translationId);
    if (translation == null) {
      return ResolvedPassage(
        reference: reference,
        status: PassageStatus.noTranslation,
      );
    }

    // 4. Build canonical book-index
    final bookInfo = await bibleData.getBookInfo(translationId);
    final index = <String, int>{};
    bookInfo.bookMap.forEach((rawKey, number) {
      index[normalizeBookKey(rawKey)] = number;
    });

    // 5. Look up the book number
    final bookNumber = index[normalizeBookKey(parsed.bookName)];
    if (bookNumber == null) {
      return ResolvedPassage(
        reference: reference,
        status: PassageStatus.bookNotFound,
        translationId: translationId,
        translationName: translation.name,
      );
    }

    // 6. Fetch chapter verses
    final chapterData = await bibleData.getChapterData(
      translationId,
      bookNumber,
      parsed.chapter,
    );

    // 7. Narrow to the requested verse range
    final selected = chapterData.verses.where((v) {
      if (parsed.startVerse == null) return true; // whole chapter
      final end = parsed.endVerse ?? parsed.startVerse!;
      return v.verse >= parsed.startVerse! && v.verse <= end;
    }).toList()
      ..sort((a, b) => a.verse - b.verse);

    if (selected.isEmpty) {
      return ResolvedPassage(
        reference: reference,
        status: PassageStatus.noVerses,
        translationId: translationId,
        translationName: translation.name,
        bookNumber: bookNumber,
        chapter: parsed.chapter,
      );
    }

    return ResolvedPassage(
      reference: reference,
      status: PassageStatus.ok,
      translationId: translationId,
      translationName: translation.name,
      bookNumber: bookNumber,
      chapter: parsed.chapter,
      verses: [
        for (final v in selected) PassageVerse(verse: v.verse, text: v.verseText),
      ],
    );
  }
}

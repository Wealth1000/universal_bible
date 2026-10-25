/// Utility for cleaning book names from various Bible translation formats.
///
/// Raw .bdat book keys are often fully concatenated title strings, e.g.:
/// - "thefirstbookofmosescalledgenesis"
/// - "thegospelaccordingtomatthew"
/// - "thefirstepistleofpaultheapostletothecorinthians"
///
/// Instead of stripping an ever-growing list of prefixes, the key is first
/// *segmented* into words using a dictionary (ordinals, structural words,
/// and all book names). From the segmented tokens we can produce either:
/// - a clean canonical name:  [cleanBookName]    → "1 Corinthians"
/// - the original title:      [preserveBookName] → "The First Epistle of
///   Paul the Apostle to the Corinthians"
library;

/// Format a raw book key for display.
///
/// [preserveOriginal] keeps the translation's full original title (spaced
/// and capitalized); otherwise the short canonical name is returned.
String formatBookName(String rawKey, {bool preserveOriginal = false}) {
  return preserveOriginal ? preserveBookName(rawKey) : cleanBookName(rawKey);
}

/// Clean a raw book key into a short canonical display name.
String cleanBookName(String rawKey) {
  final tokens = segmentBookKey(rawKey);
  if (tokens.isEmpty) return rawKey;

  // Ordinal ("first", "second", …) anywhere in the title.
  int? ordinal;
  for (final t in tokens) {
    if (_ordinals.containsKey(t)) {
      ordinal = _ordinals[t];
      break;
    }
  }

  // Special case: Song of Solomon / Song of Songs.
  if (tokens.contains('song') || tokens.contains('songs')) {
    return tokens.contains('solomon') ? 'Song of Solomon' : 'Song of Songs';
  }

  // First token that names an actual book wins ("lamentations of jeremiah"
  // → Lamentations, "revelation of jesus christ" → Revelation).
  for (final t in tokens) {
    final canonical = _canonicalBooks[t];
    if (canonical != null) {
      // Only prepend the ordinal for genuinely numbered books, so
      // "the FIRST book of moses called genesis" stays "Genesis".
      if (ordinal != null && _numberedBooks.contains(t)) {
        return '$ordinal $canonical';
      }
      return canonical;
    }
  }

  // Unknown book: fall back to the nicely formatted original title.
  return preserveBookName(rawKey);
}

/// Format the raw key as its full original title: segmented into words,
/// title-cased, with minor words kept lowercase.
String preserveBookName(String rawKey) {
  final tokens = segmentBookKey(rawKey);
  if (tokens.isEmpty) return rawKey;

  const minorWords = {'of', 'the', 'to', 'and', 'according', 'called'};
  final out = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    out.add(i > 0 && minorWords.contains(t) ? t : _capitalizeFirst(t));
  }
  return out.join(' ');
}

/// Split a raw book key into lowercase word tokens using greedy
/// longest-match against [_dictionary]. Runs of characters that match no
/// dictionary word are kept together as a single unknown token (so typos
/// like "galations" survive intact rather than being shredded).
List<String> segmentBookKey(String rawKey) {
  final lower = rawKey.toLowerCase();
  final tokens = <String>[];
  final unknown = StringBuffer();

  void flushUnknown() {
    if (unknown.isNotEmpty) {
      tokens.add(unknown.toString());
      unknown.clear();
    }
  }

  var i = 0;
  var inUnknownRun = false;
  while (i < lower.length) {
    final code = lower.codeUnitAt(i);
    final isAlnum =
        (code >= 0x61 && code <= 0x7a) || (code >= 0x30 && code <= 0x39);
    if (!isAlnum) {
      // Space / punctuation: hard word boundary.
      flushUnknown();
      inUnknownRun = false;
      i++;
      continue;
    }

    // Greedy longest dictionary match at this position.
    String? match;
    final maxEnd =
        (i + _maxWordLength) < lower.length ? i + _maxWordLength : lower.length;
    for (var end = maxEnd; end > i; end--) {
      final candidate = lower.substring(i, end);
      if (_dictionary.contains(candidate)) {
        match = candidate;
        break;
      }
    }

    // Inside an unknown run, only long matches (>= 4 chars) may interrupt
    // it — prevents "of"/"to" splitting unrecognized words apart.
    final minLength = inUnknownRun ? 4 : 1;
    if (match != null && match.length >= minLength) {
      flushUnknown();
      tokens.add(match);
      i += match.length;
      inUnknownRun = false;
    } else {
      unknown.write(lower[i]);
      i++;
      inUnknownRun = true;
    }
  }
  flushUnknown();
  return tokens;
}

/// Capitalizes the first letter of a string.
String _capitalizeFirst(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

// --- Vocabulary ---

/// Ordinal words (and bare digits) → book number.
const _ordinals = <String, int>{
  'first': 1,
  'second': 2,
  'third': 3,
  'fourth': 4,
  'fifth': 5,
  '1': 1,
  '2': 2,
  '3': 3,
  '4': 4,
  '5': 5,
};

/// Structural words that appear in full titles but never name a book.
const _structuralWords = <String>{
  'the',
  'book',
  'of',
  'moses',
  'called',
  'gospel',
  'according',
  'to',
  'epistle',
  'general',
  'paul',
  'apostle',
  'apostles',
  'saint',
  'jesus',
  'christ',
  'prophet',
  'and',
};

/// Token → canonical display name for every book (plus common variants
/// and known data typos like "galations").
const _canonicalBooks = <String, String>{
  'genesis': 'Genesis',
  'exodus': 'Exodus',
  'leviticus': 'Leviticus',
  'numbers': 'Numbers',
  'deuteronomy': 'Deuteronomy',
  'joshua': 'Joshua',
  'judges': 'Judges',
  'ruth': 'Ruth',
  'samuel': 'Samuel',
  'kings': 'Kings',
  'chronicles': 'Chronicles',
  'ezra': 'Ezra',
  'nehemiah': 'Nehemiah',
  'esther': 'Esther',
  'job': 'Job',
  'psalms': 'Psalms',
  'psalm': 'Psalms',
  'proverbs': 'Proverbs',
  'ecclesiastes': 'Ecclesiastes',
  'song': 'Song of Solomon',
  'songs': 'Song of Songs',
  'solomon': 'Song of Solomon',
  'isaiah': 'Isaiah',
  'jeremiah': 'Jeremiah',
  'lamentations': 'Lamentations',
  'ezekiel': 'Ezekiel',
  'daniel': 'Daniel',
  'hosea': 'Hosea',
  'joel': 'Joel',
  'amos': 'Amos',
  'obadiah': 'Obadiah',
  'jonah': 'Jonah',
  'micah': 'Micah',
  'nahum': 'Nahum',
  'habakkuk': 'Habakkuk',
  'zephaniah': 'Zephaniah',
  'haggai': 'Haggai',
  'zechariah': 'Zechariah',
  'malachi': 'Malachi',
  'matthew': 'Matthew',
  'mark': 'Mark',
  'luke': 'Luke',
  'john': 'John',
  'acts': 'Acts',
  'romans': 'Romans',
  'corinthians': 'Corinthians',
  'galatians': 'Galatians',
  'galations': 'Galatians', // common source-data typo
  'ephesians': 'Ephesians',
  'philippians': 'Philippians',
  'colossians': 'Colossians',
  'thessalonians': 'Thessalonians',
  'timothy': 'Timothy',
  'titus': 'Titus',
  'philemon': 'Philemon',
  'hebrews': 'Hebrews',
  'james': 'James',
  'peter': 'Peter',
  'jude': 'Jude',
  'revelation': 'Revelation',
};

/// Books that legitimately take an ordinal prefix ("1 Kings", "2 Peter").
const _numberedBooks = <String>{
  'samuel',
  'kings',
  'chronicles',
  'corinthians',
  'thessalonians',
  'timothy',
  'peter',
  'john',
};

/// Full segmentation dictionary.
final Set<String> _dictionary = {
  ..._ordinals.keys,
  ..._structuralWords,
  ..._canonicalBooks.keys,
};

/// Longest word in [_dictionary]; bounds the greedy match window.
final int _maxWordLength =
    _dictionary.fold(0, (max, w) => w.length > max ? w.length : max);

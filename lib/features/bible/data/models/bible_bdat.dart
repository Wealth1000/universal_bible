class BibleBdat {
  final Map<String, String> text;
  final Map<String, List<String>> footnotes;
  final Map<String, String> titles;
  final Map<String, int> bookMap;
  final Map<String, String> info;

  BibleBdat({
    required this.text,
    required this.footnotes,
    required this.titles,
    required this.bookMap,
    required this.info,
  });

  factory BibleBdat.fromJson(Map<String, dynamic> json) {
    // Reuse your existing implementation
    final text = Map<String, String>.from(
      (json['text'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
    );
    final footnotes = <String, List<String>>{};
    final rawFootnotes = json['footnotes'];
    if (rawFootnotes is Map) {
      rawFootnotes.forEach((k, v) {
        footnotes['$k'] = (v as List? ?? const []).map((e) => '$e').toList();
      });
    }
    final titles = Map<String, String>.from(
      (json['titles'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
    );
    final bookMap = <String, int>{};
    final rawBookMap = json['bookMap'];
    if (rawBookMap is Map) {
      rawBookMap.forEach((k, v) {
        final n = int.tryParse('$v');
        if (n != null) bookMap['$k'] = n;
      });
    }
    final info = Map<String, String>.from(
      (json['info'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? const {},
    );
    return BibleBdat(
      text: text,
      footnotes: footnotes,
      titles: titles,
      bookMap: bookMap,
      info: info,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

class CurrentTranslationNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

class CurrentBookNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? book) => state = book;
}

class CurrentChapterNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void set(int? chapter) => state = chapter;
}


final currentTranslationProvider =
    NotifierProvider<CurrentTranslationNotifier, String?>(CurrentTranslationNotifier.new);
final currentBookProvider =
    NotifierProvider<CurrentBookNotifier, int?>(CurrentBookNotifier.new);
final currentChapterProvider =
    NotifierProvider<CurrentChapterNotifier, int?>(CurrentChapterNotifier.new);

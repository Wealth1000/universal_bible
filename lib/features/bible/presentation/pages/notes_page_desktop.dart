import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_bible/core/providers/database_provider.dart';
import 'package:universal_bible/core/providers/translation_repo_provider.dart';
import 'package:universal_bible/core/utils/book_name_utils.dart';
import 'package:universal_bible/database/app_database.dart'
    hide ReadingPosition;
import 'package:universal_bible/features/bible/domain/reader_provider.dart';
import 'package:universal_bible/features/settings/domain/book_name_settings_provider.dart';

/// Notes for the active translation, most recently updated first. Tapping
/// a note's reference jumps the reader there; notes can be edited in place
/// or deleted (with confirmation — notes carry user-written content).
class NotesPageDesktop extends ConsumerStatefulWidget {
  const NotesPageDesktop({super.key});

  @override
  ConsumerState<NotesPageDesktop> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPageDesktop> {
  Map<int, String> _bookNames = const {};
  List<Note>? _notes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var translationId = ref.read(currentTranslationProvider);
    final repo = ref.read(translationRepoProvider);
    if (translationId == null) {
      final installed = await repo.getInstalled();
      if (installed.isEmpty) {
        if (mounted) setState(() => _notes = const []);
        return;
      }
      translationId = installed.first.id;
    }
    final trans = await repo.get(translationId);
    final names = <int, String>{};
    if (trans != null) {
      final bookMap = jsonDecode(trans.bookMapJson) as Map<String, dynamic>;
      final preserveOriginal = ref.read(preserveOriginalBookNamesProvider);
      bookMap.forEach((name, number) {
        names[number as int] =
            formatBookName(name, preserveOriginal: preserveOriginal);
      });
    }
    final rows =
        await ref.read(databaseProvider).getNotesForTranslation(translationId);
    if (!mounted) return;
    setState(() {
      _bookNames = names;
      _notes = rows;
    });
  }

  String _referenceFor(Note n) =>
      '${_bookNames[n.bookNumber] ?? 'Book ${n.bookNumber}'} '
      '${n.chapter}:${n.verse}';

  void _openNoteReference(Note n) {
    ref.read(currentTranslationProvider.notifier).set(n.translationId);
    ref.read(currentBookProvider.notifier).set(n.bookNumber);
    ref.read(currentChapterProvider.notifier).set(n.chapter);
    ref.read(readingPositionProvider.notifier).save(
          ReadingPosition(
            translationId: n.translationId,
            book: n.bookNumber,
            chapter: n.chapter,
          ),
        );
    context.go('/reader');
  }

  Future<void> _editNote(Note n) async {
    final controller = TextEditingController(text: n.content);
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit note — ${_referenceFor(n)}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 8,
            minLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (content == null || content.isEmpty || content == n.content) return;
    await ref
        .read(databaseProvider)
        .updateNoteContent(n.id, content, DateTime.now());
    _load();
  }

  Future<void> _deleteNote(Note n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          'The note on ${_referenceFor(n)} will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(databaseProvider).deleteNote(n.id);
    if (!mounted) return;
    setState(() {
      _notes?.remove(n);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          'Notes',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      ),
      body: _notes == null
          ? const Center(child: CircularProgressIndicator())
          : _notes!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sticky_note_2_outlined,
                          size: 48, color: colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        'No notes yet.\nSelect verses in the reader and tap Note.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _notes!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final n = _notes![index];
                        return _NoteCard(
                          reference: _referenceFor(n),
                          content: n.content,
                          updatedAt: n.updatedAt,
                          onOpen: () => _openNoteReference(n),
                          onEdit: () => _editNote(n),
                          onDelete: () => _deleteNote(n),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String reference;
  final String content;
  final DateTime updatedAt;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.reference,
    required this.content,
    required this.updatedAt,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final date =
        '${updatedAt.year}-${updatedAt.month.toString().padLeft(2, '0')}-'
        '${updatedAt.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onOpen,
                child: Text(
                  reference,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Edit note',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Delete note',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

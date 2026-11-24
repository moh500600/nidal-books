import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'core.dart';
import 'reader.dart';
import 'ui.dart';

Future<void> noteDialog(BuildContext context, Book b, int page, {String quote = '', Note? edit}) async {
  final c = TextEditingController(text: edit?.body ?? '');
  final ok = await showModalBottomSheet<bool>(
    context: context, isScrollControlled: true, backgroundColor: kCard,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(18, 18, 18, MediaQuery.of(ctx).viewInsets.bottom + 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(edit == null ? 'ملاحظة جديدة' : 'تعديل الملاحظة', style: kufi(16)),
        Text('${b.title} · ص ${page + 1}', style: sans(11.5, c: kInk2)),
        if ((edit?.quote ?? quote).isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kHi.withValues(alpha: .4), borderRadius: BorderRadius.circular(10)),
            child: Text(edit?.quote ?? quote, maxLines: 4, overflow: TextOverflow.ellipsis, style: naskh(15, h: 1.5)),
          ),
        const SizedBox(height: 10),
        Field(c, 'اكتب ملاحظتك...', lines: 4),
        const SizedBox(height: 12),
        Btn('حفظ', onTap: () => Navigator.pop(ctx, true)),
      ]),
    ),
  );
  if (ok == true && c.text.trim().isNotEmpty) {
    if (edit != null) {
      edit.body = c.text.trim();
      await app.updateNote(edit);
    } else {
      await app.addNote(Note(bookId: b.id, page: page, kind: 'note', quote: quote, body: c.text.trim()));
    }
  }
}

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});
  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  int tab = 0; // 0 all 1 notes 2 highlights 3 bookmarks
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final kinds = [null, 'note', 'highlight', 'bookmark'];
          final l = app.notes.where((n) => kinds[tab] == null || n.kind == kinds[tab]).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(children: [
                Expanded(child: Text('ملاحظاتي', style: kufi(24))),
                IconButton(icon: const Icon(Icons.ios_share, color: kInk), tooltip: 'تصدير', onPressed: () => go(context, const ExportNotes())),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                for (final e in const [(0, 'الكل'), (1, 'ملاحظات'), (2, 'تمييزات'), (3, 'إشارات')]) Chip2(e.$2, on: tab == e.$1, onTap: () => setState(() => tab = e.$1)),
              ])),
            ),
            Expanded(
              child: l.isEmpty
                  ? const Empty(Icons.sticky_note_2_outlined, 'لا شيء هنا. حدّد نصًا أثناء القراءة لتمييزه أو كتابة ملاحظة.')
                  : ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 18), children: [for (final n in l) NoteCard(n)]),
            ),
          ]);
        },
      );
}

class NoteCard extends StatelessWidget {
  const NoteCard(this.n, {super.key});
  final Note n;
  @override
  Widget build(BuildContext context) {
    final b = app.bookById(n.bookId);
    if (b == null) return const SizedBox();
    final icon = {'note': Icons.edit_note, 'highlight': Icons.highlight, 'bookmark': Icons.bookmark}[n.kind]!;
    return PaperCard(
      onTap: () => go(context, ReaderOpen(b.id, page: n.page)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: kRed),
          const SizedBox(width: 6),
          Expanded(child: Text('${b.title} · ص ${n.page + 1}', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, c: kInk2, w: FontWeight.w700))),
          if (n.kind == 'note') IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => noteDialog(context, b, n.page, edit: n)),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => app.deleteNote(n)),
        ]),
        if (n.quote.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.all(8), width: double.infinity,
            decoration: BoxDecoration(color: kHi.withValues(alpha: .35), borderRadius: BorderRadius.circular(8)),
            child: Text(n.quote, style: naskh(15, h: 1.5)),
          ),
        if (n.body.isNotEmpty && n.kind != 'highlight') Padding(padding: const EdgeInsets.only(top: 6), child: Text(n.body, style: sans(13.5))),
      ]),
    );
  }
}

class ExportNotes extends StatefulWidget {
  const ExportNotes({super.key});
  @override
  State<ExportNotes> createState() => _ExportNotesState();
}

class _ExportNotesState extends State<ExportNotes> {
  int? bookId;
  String makeText() {
    final sb = StringBuffer('# ملاحظات Nidal Books\n\n');
    final byBook = <int, List<Note>>{};
    for (final n in app.notes.where((n) => n.kind != 'bookmark' && (bookId == null || n.bookId == bookId))) {
      (byBook[n.bookId] ??= []).add(n);
    }
    for (final e in byBook.entries) {
      final b = app.bookById(e.key);
      if (b == null) continue;
      sb.writeln('## ${b.title}${b.author.isEmpty ? '' : ' - ${b.author}'}\n');
      for (final n in e.value.reversed) {
        if (n.quote.isNotEmpty) sb.writeln('> ${n.quote.replaceAll('\n', ' ')}');
        if (n.body.isNotEmpty) sb.writeln(n.body);
        sb.writeln('(ص ${n.page + 1})\n');
      }
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final text = makeText();
    return Scaffold(
      appBar: AppBar(title: const Text('تصدير الملاحظات')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Text('اختر الكتاب', style: kufi(14)),
        const SizedBox(height: 8),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          Chip2('كل الكتب', on: bookId == null, onTap: () => setState(() => bookId = null)),
          for (final b in app.books) Chip2(b.title, on: bookId == b.id, onTap: () => setState(() => bookId = b.id)),
        ])),
        const SizedBox(height: 12),
        PaperCard(child: SelectableText(text, style: sans(12.5))),
        Btn('مشاركة كملف Markdown', icon: Icons.ios_share, onTap: () async {
          final f = File(p.join((await getTemporaryDirectory()).path, 'nidal-books-notes.md'));
          await f.writeAsString(text);
          await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'ملاحظاتي من Nidal Books'));
        }),
        const SizedBox(height: 10),
        Btn('مشاركة كنص', outline: true, icon: Icons.text_snippet_outlined, onTap: () => SharePlus.instance.share(ShareParams(text: text))),
      ]),
    );
  }
}

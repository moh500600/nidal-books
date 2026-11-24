import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import 'ai.dart';
import 'core.dart';
import 'notes.dart';
import 'ui.dart';

class ReaderOpen extends StatefulWidget {
  const ReaderOpen(this.id, {super.key, this.page});
  final int id;
  final int? page;
  @override
  State<ReaderOpen> createState() => _ReaderOpenState();
}

class _ReaderOpenState extends State<ReaderOpen> {
  late final Book b = app.bookById(widget.id)!;
  late int page = (widget.page ?? b.lastPage).clamp(0, b.pages - 1);
  late final PageController pc = PageController(initialPage: page);
  bool chrome = true;

  Color get bg => app.darkReader ? const Color(0xFF14161F) : kPaper;
  Color get fg => app.darkReader ? const Color(0xFFE9E1D0) : kInk;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Column(children: [
              if (chrome)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(children: [
                    IconButton(icon: Icon(Icons.arrow_forward, color: fg), onPressed: () => Navigator.pop(context)),
                    Expanded(child: Column(children: [
                      Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: kufi(14, c: fg)),
                      Text('ص ${page + 1} من ${b.pages}', style: sans(11, c: app.darkReader ? Colors.white54 : kInk2)),
                    ])),
                    IconButton(
                      icon: Icon(Icons.bookmark_add_outlined, color: fg),
                      tooltip: 'إشارة مرجعية',
                      onPressed: () async {
                        await app.addNote(Note(bookId: b.id, page: page, kind: 'bookmark', body: 'إشارة في ص ${page + 1}'));
                        if (context.mounted) snack(context, 'أضيفت إشارة مرجعية');
                      },
                    ),
                  ]),
                ),
              Expanded(
                child: PageView.builder(
                  controller: pc, itemCount: b.pages,
                  onPageChanged: (i) { page = i; setState(() {}); app.setProgress(b, i); },
                  itemBuilder: (_, i) => PageText(b, i, fg: fg, onTap: () => setState(() => chrome = !chrome)),
                ),
              ),
              if (chrome) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Text('${b.pages}', style: sans(10.5, c: fg)),
                    Expanded(
                      child: Slider(
                        value: page.toDouble(), min: 0, max: (b.pages - 1).clamp(1, 100000).toDouble(),
                        activeColor: kRed, inactiveColor: kLine,
                        onChanged: b.pages <= 1 ? null : (v) => setState(() => page = v.round()),
                        onChangeEnd: (v) => pc.jumpToPage(v.round()),
                      ),
                    ),
                    Text('1', style: sans(10.5, c: fg)),
                  ]),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  decoration: BoxDecoration(color: app.darkReader ? const Color(0xFF232636) : kCard, borderRadius: BorderRadius.circular(24), border: Border.all(color: app.darkReader ? Colors.white12 : kLine)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _t(Icons.dark_mode_outlined, () => app.setPref('dark', !app.darkReader)),
                    _t(Icons.text_fields, () => settingsSheet(context)),
                    _t(Icons.search, () => _search(context)),
                    _t(Icons.format_list_bulleted, () async {
                      final r = await go<int>(context, Contents(b.id));
                      if (r != null) pc.jumpToPage(r);
                    }),
                    _t(Icons.volume_up_outlined, () => _speak(context)),
                    if (b.kind == 'pdf') _t(Icons.picture_as_pdf_outlined, () => go(context, PdfOriginal(b, page))),
                    _t(Icons.auto_awesome, () => go(context, AiChat(b.id, page: page))),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      );

  Widget _t(IconData i, VoidCallback f) => IconButton(icon: Icon(i, color: app.darkReader ? const Color(0xFFE9E1D0) : kInk2), onPressed: f);

  Future<void> _speak(BuildContext context) async {
    final t = await app.pageText(b, page);
    if (t.isEmpty) return snack(context, 'لا نص في هذه الصفحة');
    await Speaker.speak(t);
    if (context.mounted) snack(context, 'تشغيل القراءة الصوتية (صوت الجهاز)');
  }

  Future<void> _search(BuildContext context) async {
    final q = TextEditingController();
    List<(int, String)> res = [];
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: kCard,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SizedBox(
          height: 420,
          child: Column(children: [
            Field(q, 'ابحث في هذا الكتاب', icon: Icons.search, onSubmit: (v) async { res = await app.searchBook(b, v); set(() {}); }),
            Expanded(child: ListView(children: [
              for (final r in res)
                ListTile(
                  title: Text('ص ${r.$1 + 1}', style: kufi(13)), subtitle: Text(r.$2, maxLines: 2, style: naskh(14, h: 1.5)),
                  onTap: () { Navigator.pop(ctx); pc.jumpToPage(r.$1); },
                ),
            ])),
          ]),
        ),
      )),
    );
  }
}

void settingsSheet(BuildContext context) => showModalBottomSheet(
      context: context, backgroundColor: kCard,
      builder: (_) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إعدادات القراءة', style: kufi(16)),
            const SizedBox(height: 14),
            Text('حجم الخط: ${app.fontSize.round()}', style: sans(13)),
            Slider(value: app.fontSize, min: 14, max: 32, divisions: 18, activeColor: kRed, onChanged: (v) => app.setPref('font', v)),
            Row(children: [
              Expanded(child: Btn('فاتح', outline: app.darkReader, onTap: () => app.setPref('dark', false))),
              const SizedBox(width: 10),
              Expanded(child: Btn('داكن', outline: !app.darkReader, onTap: () => app.setPref('dark', true))),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: app.darkReader ? const Color(0xFF14161F) : kPaper, borderRadius: BorderRadius.circular(12)),
              child: Text('اعلم أن فن التاريخ فن عزيز المذهب، جم الفوائد', style: naskh(app.fontSize, c: app.darkReader ? const Color(0xFFE9E1D0) : kInk)),
            ),
          ]),
        ),
      ),
    );

class Speaker {
  static FlutterTts? _t;
  static Future<FlutterTts> _get() async {
    if (_t == null) {
      _t = FlutterTts();
      await _t!.setLanguage('ar');
    }
    return _t!;
  }

  static Future<void> speak(String text) async {
    final t = await _get();
    await t.stop();
    await t.speak(text);
  }

  static Future<void> stop() async => (await _get()).stop();
}

class PageText extends StatefulWidget {
  const PageText(this.b, this.i, {super.key, required this.fg, this.onTap});
  final Book b;
  final int i;
  final Color fg;
  final VoidCallback? onTap;
  @override
  State<PageText> createState() => _PageTextState();
}

class _PageTextState extends State<PageText> {
  late Future<String> f = app.pageText(widget.b, widget.i);
  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: f,
        builder: (context, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator(color: kRed));
          final t = s.data!;
          if (t.isEmpty) {
            return Empty(Icons.image_not_supported_outlined, 'لا يوجد نص قابل للقراءة في هذه الصفحة (ربما صفحة ممسوحة ضوئيًا). افتح عرض PDF الأصلي من الشريط السفلي.');
          }
          return ListenableBuilder(
            listenable: app,
            builder: (context, _) {
              final hl = app.notes.where((n) => n.bookId == widget.b.id && n.page == widget.i && n.kind == 'highlight' && n.quote.isNotEmpty).toList();
              final base = naskh(app.fontSize, c: widget.fg);
              final spans = <InlineSpan>[];
              var cur = 0;
              final ranges = <(int, int)>[];
              for (final n in hl) {
                final at = t.indexOf(n.quote);
                if (at >= 0) ranges.add((at, at + n.quote.length));
              }
              ranges.sort((a, b) => a.$1.compareTo(b.$1));
              for (final r in ranges) {
                if (r.$1 < cur) continue;
                spans.add(TextSpan(text: t.substring(cur, r.$1)));
                spans.add(TextSpan(text: t.substring(r.$1, r.$2), style: TextStyle(backgroundColor: kHi, color: kInk)));
                cur = r.$2;
              }
              spans.add(TextSpan(text: t.substring(cur)));
              return GestureDetector(
                behavior: HitTestBehavior.translucent, onTap: widget.onTap,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
                  child: SelectableText.rich(
                    TextSpan(style: base, children: spans),
                    textAlign: TextAlign.justify,
                    contextMenuBuilder: (ctx, st) {
                      final sel = st.textEditingValue.selection.textInside(st.textEditingValue.text);
                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: st.contextMenuAnchors,
                        buttonItems: [
                          ContextMenuButtonItem(label: 'نسخ', onPressed: () { Clipboard.setData(ClipboardData(text: sel)); st.hideToolbar(); }),
                          ContextMenuButtonItem(label: 'تمييز', onPressed: () async {
                            st.hideToolbar();
                            if (sel.trim().isEmpty) return;
                            await app.addNote(Note(bookId: widget.b.id, page: widget.i, kind: 'highlight', quote: sel.trim()));
                          }),
                          ContextMenuButtonItem(label: 'ملاحظة', onPressed: () {
                            st.hideToolbar();
                            noteDialog(context, widget.b, widget.i, quote: sel.trim());
                          }),
                          ContextMenuButtonItem(label: 'اسأل', onPressed: () {
                            st.hideToolbar();
                            go(context, AiChat(widget.b.id, page: widget.i, seed: sel.trim()));
                          }),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      );
}

class Contents extends StatelessWidget {
  const Contents(this.id, {super.key});
  final int id;
  @override
  Widget build(BuildContext context) {
    final b = app.bookById(id)!;
    final marks = app.notes.where((n) => n.bookId == id && n.kind != 'bookmark' ? true : n.bookId == id).toList();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('الفهرس'), bottom: TabBar(labelColor: kRed, indicatorColor: kRed, tabs: [
          Tab(child: Text('الصفحات', style: sans(13, w: FontWeight.w700))),
          Tab(child: Text('إشارات', style: sans(13, w: FontWeight.w700))),
          Tab(child: Text('تمييزات', style: sans(13, w: FontWeight.w700))),
        ])),
        body: TabBarView(children: [
          GridView.count(
            crossAxisCount: 5, padding: const EdgeInsets.all(16), mainAxisSpacing: 8, crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < b.pages; i++)
                GestureDetector(
                  onTap: () => Navigator.pop(context, i),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: i == b.lastPage ? kRed : kCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLine)),
                    child: Text('${i + 1}', style: sans(13, c: i == b.lastPage ? Colors.white : kInk, w: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          _list(context, marks.where((n) => n.kind == 'bookmark').toList()),
          _list(context, marks.where((n) => n.kind == 'highlight').toList()),
        ]),
      ),
    );
  }

  Widget _list(BuildContext context, List<Note> l) => l.isEmpty
      ? const Empty(Icons.bookmark_border, 'لا شيء هنا بعد.')
      : ListView(padding: const EdgeInsets.all(16), children: [
          for (final n in l)
            PaperCard(
              onTap: () => Navigator.pop(context, n.page),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ص ${n.page + 1}', style: sans(11, c: kRed, w: FontWeight.w700)),
                Text(n.quote.isNotEmpty ? n.quote : n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: naskh(15, h: 1.5)),
              ]),
            ),
        ]);
}

class PdfOriginal extends StatelessWidget {
  const PdfOriginal(this.b, this.page, {super.key});
  final Book b;
  final int page;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(b.title, style: kufi(14))),
        body: PdfViewer.file(b.path, initialPageNumber: page + 1),
      );
}

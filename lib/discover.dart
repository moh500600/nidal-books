import 'package:material_ui/material_ui.dart';

import 'ai.dart';
import 'core.dart';
import 'library.dart';
import 'reader.dart';
import 'ui.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final q = TextEditingController();
  int mode = 0; // 0 all, 1 titles, 2 authors, 3 inside texts
  bool busy = false;
  List<Book> hits = [];
  final List<(Book, int, String)> textHits = [];

  Future<void> run() async {
    final t = q.text.trim();
    setState(() { busy = true; textHits.clear(); hits = []; });
    final low = t.toLowerCase();
    hits = app.books.where((b) {
      if (t.isEmpty) return false;
      final inT = b.title.toLowerCase().contains(low), inA = b.author.toLowerCase().contains(low);
      return mode == 0 ? (inT || inA) : mode == 1 ? inT : mode == 2 ? inA : false;
    }).toList();
    if (mode == 0 || mode == 3) {
      for (final b in app.books) {
        for (final h in await app.searchBook(b, t, limit: 5)) {
          textHits.add((b, h.$1, h.$2));
        }
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('بحث')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Field(q, 'اكتب كلمة أو عنوانًا...', icon: Icons.search, onSubmit: (_) => run()),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final e in const [(0, 'الكل'), (1, 'عناوين'), (2, 'مؤلفون'), (3, 'داخل النصوص')])
                Chip2(e.$2, on: mode == e.$1, onTap: () { setState(() => mode = e.$1); run(); }),
            ]),
          ),
          if (busy) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: kRed))),
          if (!busy && q.text.isNotEmpty && hits.isEmpty && textHits.isEmpty)
            const SizedBox(height: 260, child: Empty(Icons.search_off, 'لا نتائج. جرّب كلمة أخرى.')),
          if (hits.isNotEmpty) Head('${hits.length} كتاب'),
          for (final b in hits) BookRow(b, onTap: () => go(context, BookDetails(b.id))),
          if (textHits.isNotEmpty) Head('${textHits.length} نتيجة داخل النصوص'),
          for (final h in textHits)
            PaperCard(
              onTap: () => go(context, ReaderOpen(h.$1.id, page: h.$2)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${h.$1.title} · ص ${h.$2 + 1}', style: kufi(13)),
                const SizedBox(height: 4),
                Text('...${h.$3}...', style: naskh(15, h: 1.6)),
              ]),
            ),
        ]),
      );
}

class BookDetails extends StatelessWidget {
  const BookDetails(this.id, {super.key});
  final int id;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final b = app.bookById(id);
          if (b == null) return const Scaffold(body: Empty(Icons.error_outline, 'الكتاب غير موجود'));
          final nn = app.notes.where((n) => n.bookId == b.id).length;
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل الكتاب'), actions: [
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => go(context, EditBook(b.id))),
            ]),
            body: ListView(padding: const EdgeInsets.all(20), children: [
              Center(child: Cover(b, w: 130, h: 184)),
              const SizedBox(height: 14),
              Text(b.title, textAlign: TextAlign.center, style: kufi(20)),
              Text(b.author.isEmpty ? 'مؤلف غير محدد' : b.author, textAlign: TextAlign.center, style: sans(13, c: kInk2)),
              const SizedBox(height: 14),
              Row(children: [
                _s('${b.pages}', 'صفحة'),
                _s(b.kind == 'pdf' ? 'PDF' : 'نص', 'النوع'),
                _s('$nn', 'ملاحظة'),
              ]),
              if (b.category.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(children: [Chip2(b.category)])),
              const SizedBox(height: 8),
              Text('تقدمك: ${(b.progress * 100).round()}% (ص ${b.lastPage + 1} من ${b.pages})', style: sans(12.5, c: kInk2)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Btn(b.lastPage > 0 ? 'تابع القراءة' : 'ابدأ القراءة', icon: Icons.play_arrow, onTap: () => go(context, ReaderOpen(b.id)))),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () { b.fav = !b.fav; app.saveBook(b); },
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: kRed, width: 1.4), minimumSize: const Size(48, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Icon(b.fav ? Icons.bookmark : Icons.bookmark_border, color: kRed),
                ),
              ]),
              const SizedBox(height: 10),
              Btn('لخّص مع CMD AI', outline: true, icon: Icons.auto_awesome, onTap: () => go(context, AiWork(b.id, 'summary'))),
              const SizedBox(height: 10),
              Btn('إضافة إلى رف', outline: true, icon: Icons.shelves, onTap: () => pickShelf(context, b)),
            ]),
          );
        },
      );

  Widget _s(String n, String l) => Expanded(
        child: PaperCard(margin: const EdgeInsetsDirectional.only(end: 8), pad: 10, child: Column(children: [Text(n, style: kufi(17, c: kRed)), Text(l, style: sans(11, c: kInk2))])),
      );
}

Future<void> pickShelf(BuildContext context, Book b) async {
  if (app.shelves.isEmpty) {
    snack(context, 'أنشئ رفًّا أولًا من تبويب مكتبتي > الأرفف');
    return;
  }
  await showModalBottomSheet(
    context: context, backgroundColor: kCard,
    builder: (_) => ListenableBuilder(
      listenable: app,
      builder: (ctx, _) => ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
        Text('أضف إلى رف', style: kufi(16)),
        for (final s in app.shelves)
          CheckboxListTile(
            value: (app.shelfBooks[s.id] ?? []).contains(b.id), activeColor: kRed,
            title: Text(s.name, style: sans(14)),
            onChanged: (_) => app.toggleInShelf(s, b),
          ),
      ]),
    ),
  );
}

class Categories extends StatelessWidget {
  const Categories({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التصنيفات')),
        body: ListenableBuilder(
          listenable: app,
          builder: (_, __) => GridView.count(
            crossAxisCount: 2, padding: const EdgeInsets.all(16), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.1,
            children: [
              for (final c in kCategories)
                PaperCard(
                  margin: EdgeInsets.zero, onTap: () => go(context, CategoryBooks(c)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(c, textAlign: TextAlign.center, style: kufi(13)),
                    Text('${app.books.where((b) => b.category == c).length} كتاب', style: sans(11, c: kRed)),
                  ]),
                ),
            ],
          ),
        ),
      );
}

class CategoryBooks extends StatelessWidget {
  const CategoryBooks(this.cat, {super.key});
  final String cat;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(cat)),
        body: ListenableBuilder(
          listenable: app,
          builder: (_, __) {
            final l = app.books.where((b) => b.category == cat).toList();
            if (l.isEmpty) return Empty(Icons.category_outlined, 'لا كتب في هذا التصنيف بعد. عدّل تصنيف كتاب من صفحة تفاصيله.');
            return ListView(padding: const EdgeInsets.all(16), children: [for (final b in l) BookRow(b, onTap: () => go(context, BookDetails(b.id)))]);
          },
        ),
      );
}

class BrowseAll extends StatelessWidget {
  const BrowseAll({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('كل الكتب')),
        body: ListenableBuilder(
          listenable: app,
          builder: (_, __) => ListView(padding: const EdgeInsets.all(16), children: [
            for (final b in app.books) BookRow(b, onTap: () => go(context, BookDetails(b.id))),
          ]),
        ),
      );
}

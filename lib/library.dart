import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'core.dart';
import 'discover.dart';
import 'ui.dart';

class LibraryTab extends StatefulWidget {
  const LibraryTab({super.key});
  @override
  State<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<LibraryTab> {
  String filter = 'الكل';
  bool grid = false;
  int sort = 0; // 0 newest, 1 title, 2 progress
  bool shelvesView = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final cats = ['الكل', 'مفضلة', ...app.books.map((b) => b.category).where((c) => c.isNotEmpty).toSet()];
          var l = app.books.where((b) => filter == 'الكل' ? true : filter == 'مفضلة' ? b.fav : b.category == filter).toList();
          l.sort((a, b) => sort == 0 ? b.added.compareTo(a.added) : sort == 1 ? a.title.compareTo(b.title) : b.progress.compareTo(a.progress));
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: Row(children: [
                Expanded(child: Text('مكتبتي', style: kufi(24))),
                IconButton(
                  icon: Icon(shelvesView ? Icons.menu_book : Icons.shelves, color: kInk),
                  tooltip: 'الأرفف', onPressed: () => setState(() => shelvesView = !shelvesView),
                ),
                Container(
                  decoration: BoxDecoration(border: Border.all(color: kRed), borderRadius: BorderRadius.circular(12)),
                  child: IconButton(icon: const Icon(Icons.add, color: kRed), onPressed: () => go(context, const ImportScreen())),
                ),
              ]),
            ),
            if (shelvesView) const Expanded(child: ShelvesView()) else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final c in cats) Chip2(c, on: filter == c, onTap: () => setState(() => filter = c))])),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
                child: Row(children: [
                  Expanded(child: Text('${l.length} كتاب · ${['الأحدث', 'العنوان', 'التقدم'][sort]}', style: sans(12, c: kRed))),
                  IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.sort, size: 20), onPressed: () => setState(() => sort = (sort + 1) % 3)),
                  IconButton(visualDensity: VisualDensity.compact, icon: Icon(grid ? Icons.view_list : Icons.grid_view, size: 20), onPressed: () => setState(() => grid = !grid)),
                ]),
              ),
              Expanded(
                child: l.isEmpty
                    ? Empty(Icons.menu_book_outlined, 'لا كتب هنا بعد.', action: 'استيراد كتاب', onAction: () => go(context, const ImportScreen()))
                    : grid
                        ? GridView.count(
                            crossAxisCount: 3, padding: const EdgeInsets.fromLTRB(18, 4, 18, 18), mainAxisSpacing: 14, crossAxisSpacing: 10, childAspectRatio: .58,
                            children: [
                              for (final b in l)
                                GestureDetector(
                                  onTap: () => go(context, BookDetails(b.id)),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Expanded(child: LayoutBuilder(builder: (_, c) => Cover(b, w: c.maxWidth, h: c.maxHeight))),
                                    const SizedBox(height: 4),
                                    Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, w: FontWeight.w700)),
                                  ]),
                                ),
                            ],
                          )
                        : ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 18), children: [
                            for (final b in l)
                              BookRow(b, onTap: () => go(context, BookDetails(b.id)), trailing: IconButton(icon: Icon(b.fav ? Icons.favorite : Icons.favorite_border, color: kRed, size: 20), onPressed: () { b.fav = !b.fav; app.saveBook(b); })),
                          ]),
              ),
            ],
          ]);
        },
      );
}

/// Shelves = user folders/collections.
class ShelvesView extends StatelessWidget {
  const ShelvesView({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 18), children: [
        Btn('رف جديد', icon: Icons.add, outline: true, onTap: () async {
          final c = TextEditingController();
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: kCard, title: Text('رف جديد', style: kufi(16)),
              content: Field(c, 'اسم الرف (مثل: للدراسة)'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء'))],
            ),
          );
          if (ok == true && c.text.trim().isNotEmpty) app.addShelf(c.text.trim());
        }),
        const SizedBox(height: 10),
        if (app.shelves.isEmpty) const SizedBox(height: 240, child: Empty(Icons.shelves, 'أنشئ أرففًا لتنظيم كتبك (للدراسة، للعمل، قيد القراءة...).')),
        for (final s in app.shelves)
          PaperCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(s.name, style: kufi(16))),
                Text('${(app.shelfBooks[s.id] ?? []).length} كتاب', style: sans(11.5, c: kRed)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: kInk2), onPressed: () => app.deleteShelf(s)),
              ]),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final id in (app.shelfBooks[s.id] ?? []))
                    if (app.bookById(id) != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: GestureDetector(onTap: () => go(context, BookDetails(id)), child: Cover(app.bookById(id)!, w: 56, h: 80)),
                      ),
                  if ((app.shelfBooks[s.id] ?? []).isEmpty) Text('الرف فارغ. أضف كتبًا من صفحة الكتاب.', style: sans(12, c: kInk2)),
                ]),
              ),
            ]),
          ),
      ]);
}

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final log = <(String, String)>[]; // name, status
  bool busy = false;

  Future<void> pick() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'txt']);
    if (files.isEmpty) return;
    setState(() => busy = true);
    for (final f in files) {
      final path = f.path;
      if (path == null) { log.add((f.name, 'تعذر قراءة الملف')); continue; }
      final title = f.name.replaceAll(RegExp(r'\.(pdf|txt)$', caseSensitive: false), '');
      if (await app.duplicateOf(title)) { log.add((f.name, 'مكرر: موجود في مكتبتك')); continue; }
      try {
        await app.importFile(path, name: f.name);
        log.add((f.name, 'تم'));
      } catch (e) {
        log.add((f.name, 'فشل: الملف تالف أو محمي بكلمة مرور'));
      }
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('استيراد كتب')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          GestureDetector(
            onTap: busy ? null : pick,
            child: Container(
              height: 150,
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(20), border: Border.all(color: kRed.withValues(alpha: .5), width: 1.5)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.upload_file, size: 38, color: kRed),
                const SizedBox(height: 8),
                Text('اختر ملفات PDF أو نص', style: kufi(15)),
                Text('يمكنك تحديد عدة ملفات. تُنسخ إلى تخزين التطبيق على هاتفك.', textAlign: TextAlign.center, style: sans(11.5, c: kInk2)),
              ]),
            ),
          ),
          if (busy) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: kRed))),
          const SizedBox(height: 12),
          for (final l in log)
            PaperCard(pad: 12, child: Row(children: [
              Expanded(child: Text(l.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13, w: FontWeight.w700))),
              Text(l.$2, style: sans(12, c: l.$2 == 'تم' ? Colors.green.shade800 : kRed)),
            ])),
          if (log.any((l) => l.$2 == 'تم')) Btn('إنهاء', onTap: () => Navigator.pop(context)),
        ]),
      );
}

class EditBook extends StatefulWidget {
  const EditBook(this.id, {super.key});
  final int id;
  @override
  State<EditBook> createState() => _EditBookState();
}

class _EditBookState extends State<EditBook> {
  late final Book b = app.bookById(widget.id)!;
  late final t = TextEditingController(text: b.title), a = TextEditingController(text: b.author);
  late String cat = b.category;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تعديل بيانات الكتاب')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Center(child: Cover(b, w: 90, h: 128)),
          const SizedBox(height: 10),
          Center(child: TextButton(onPressed: () { setState(() => b.color = (b.color + 1) % kCoverColors.length); }, child: Text('تغيير الغلاف', style: sans(13, c: kRed, w: FontWeight.w700)))),
          Field(t, 'العنوان'), const SizedBox(height: 10),
          Field(a, 'المؤلف'), const SizedBox(height: 14),
          Text('التصنيف', style: kufi(14)),
          const SizedBox(height: 8),
          Wrap(runSpacing: 8, children: [for (final c in kCategories) Chip2(c, on: cat == c, onTap: () => setState(() => cat = cat == c ? '' : c))]),
          const SizedBox(height: 20),
          Btn('حفظ', icon: Icons.check, onTap: () async {
            b.title = t.text.trim().isEmpty ? b.title : t.text.trim();
            b.author = a.text.trim();
            b.category = cat;
            await app.saveBook(b);
            if (context.mounted) Navigator.pop(context);
          }),
          const SizedBox(height: 10),
          Btn('حذف الكتاب من الجهاز', outline: true, icon: Icons.delete_outline, onTap: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: kCard, title: Text('حذف الكتاب؟', style: kufi(16)),
                content: Text('سيُحذف الملف وملاحظاته من هذا الهاتف ولا يمكن استرجاعه.', style: sans(13)),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))],
              ),
            );
            if (ok == true) {
              await app.deleteBook(b);
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            }
          }),
        ]),
      );
}

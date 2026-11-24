import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import 'account.dart';
import 'ai.dart';
import 'core.dart';
import 'discover.dart';
import 'library.dart';
import 'notes.dart';
import 'onboarding.dart';
import 'reader.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  pdfrxFlutterInitialize();
  app = AppState();
  await app.init();
  runApp(const CmdApp());
}

class CmdApp extends StatelessWidget {
  const CmdApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => MaterialApp(
          title: 'CMD Book',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: !app.onboarded ? const Welcome() : (app.pin.isNotEmpty ? const Unlock() : const Shell()),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key, this.tab = 0});
  final int tab;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int i = widget.tab;
  static const tabs = [
    (Icons.home_outlined, Icons.home, 'الرئيسية'),
    (Icons.local_library_outlined, Icons.local_library, 'مكتبتي'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Nidal AI'),
    (Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'ملاحظاتي'),
    (Icons.person_outline, Icons.person, 'حسابي'),
  ];
  @override
  Widget build(BuildContext context) {
    final pages = const [HomeTab(), LibraryTab(), AiTab(), NotesTab(), AccountTab()];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: i, children: pages)),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(26), border: Border.all(color: kLine)),
        child: SafeArea(
          top: false,
          child: Row(children: [
            for (var k = 0; k < tabs.length; k++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => i = k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(i == k ? tabs[k].$2 : tabs[k].$1, color: i == k ? kRed : kInk2, size: 23),
                      const SizedBox(height: 2),
                      Text(tabs[k].$3, style: sans(10.5, c: i == k ? kRed : kInk2, w: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final cont = app.books.where((b) => b.lastPage > 0 || b.progress > 0).toList()
            ..sort((a, b) => b.added.compareTo(a.added));
          final cur = cont.isNotEmpty ? cont.first : (app.books.isNotEmpty ? app.books.first : null);
          final pagesRead = app.books.fold<int>(0, (a, b) => a + (b.lastPage > 0 ? b.lastPage + 1 : 0));
          return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(app.userName.isEmpty ? 'أهلًا بك' : 'أهلًا، ${app.userName}', style: sans(12, c: kInk2)),
                  Text('تابع رحلتك', style: kufi(24)),
                ]),
              ),
              CircleAvatar(radius: 18, backgroundColor: kRed,
                  child: Text(app.userName.isEmpty ? 'ن' : app.userName.characters.first, style: kufi(15, c: Colors.white))),
            ]),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => go(context, const SearchScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                child: Row(children: [
                  const Icon(Icons.search, color: kInk2, size: 20), const SizedBox(width: 10),
                  Text('ابحث في مكتبتك والكتب...', style: sans(13, c: kInk2)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            if (cur == null)
              PaperCard(child: Empty(Icons.menu_book_outlined, 'مكتبتك فارغة. استورد أول كتاب PDF أو نص.', action: 'استيراد كتاب', onAction: () => go(context, const ImportScreen())))
            else
              PaperCard(
                onTap: () => go(context, BookDetails(cur.id)),
                child: Row(children: [
                  Cover(cur, w: 62, h: 88),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('تابع القراءة', style: sans(11, c: kRed, w: FontWeight.w700)),
                      Text(cur.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: kufi(15)),
                      Text('ص ${cur.lastPage + 1} من ${cur.pages}', style: sans(11.5, c: kInk2)),
                      const SizedBox(height: 10),
                      Btn('متابعة', icon: Icons.play_arrow, wide: false, onTap: () => go(context, ReaderOpen(cur.id))),
                    ]),
                  ),
                  SizedBox(
                    width: 44, height: 44,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(value: cur.progress, strokeWidth: 4, backgroundColor: kLine, color: kRed),
                      Text('${(cur.progress * 100).round()}', style: sans(11, w: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
            Row(children: [
              _stat('${app.books.length}', 'كتاب'),
              _stat('$pagesRead', 'صفحة'),
              _stat('${app.notes.where((n) => n.kind == 'highlight').length}', 'تمييز'),
            ]),
            Head('أضيف حديثًا', action: 'عرض الكل', onAction: () => go(context, const BrowseAll())),
            SizedBox(
              height: 150,
              child: app.books.isEmpty
                  ? const SizedBox()
                  : ListView(scrollDirection: Axis.horizontal, children: [
                      for (final b in app.books.take(10))
                        GestureDetector(
                          onTap: () => go(context, BookDetails(b.id)),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: SizedBox(width: 90, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Cover(b, w: 90, h: 112),
                              const SizedBox(height: 4),
                              Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, w: FontWeight.w700)),
                            ])),
                          ),
                        ),
                    ]),
            ),
            Head('تصنيفات', action: 'كل التصنيفات', onAction: () => go(context, const Categories())),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final c in (app.interests.isNotEmpty ? app.interests : kCategories.take(6).toList()))
                  Chip2(c, onTap: () => go(context, CategoryBooks(c))),
              ]),
            ),
          ]);
        },
      );

  Widget _stat(String n, String l) => Expanded(
        child: PaperCard(
          margin: const EdgeInsetsDirectional.only(end: 8, top: 4),
          pad: 12,
          child: Column(children: [Text(n, style: kufi(20, c: kRed)), Text(l, style: sans(11, c: kInk2))]),
        ),
      );
}

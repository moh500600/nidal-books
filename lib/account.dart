import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import 'ai.dart';
import 'core.dart';
import 'ui.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  Map<String, int> week = {};
  int streak = 0, secs = 0;
  Future<void> load() async {
    week = await app.weekPages();
    streak = await app.streak();
    secs = await app.totalSecs();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    load();
    app.addListener(load);
  }

  @override
  void dispose() {
    app.removeListener(load);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mx = week.values.fold<int>(1, (a, b) => b > a ? b : a);
    final done = app.books.where((b) => b.progress >= 1).length;
    final goalSecs = app.weeklyGoalHours * 3600;
    final weekSecs = week.values.fold<int>(0, (a, b) => a + b) * 30;
    return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
      Center(child: CircleAvatar(radius: 32, backgroundColor: kRed, child: Text(app.userName.isEmpty ? 'ن' : app.userName.characters.first, style: kufi(26, c: Colors.white)))),
      const SizedBox(height: 8),
      Center(child: Text(app.userName.isEmpty ? 'قارئ' : app.userName, style: kufi(19))),
      Center(child: Text('الملف محفوظ على هذا الجهاز', style: sans(11.5, c: kInk2))),
      PaperCard(
        margin: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('هدف الأسبوع', style: kufi(14)),
          Text('${(weekSecs / 3600).toStringAsFixed(1)} من ${app.weeklyGoalHours} ساعات (تقدير من الصفحات المقروءة)', style: sans(11.5, c: kInk2)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (weekSecs / goalSecs).clamp(0, 1).toDouble(), minHeight: 7, backgroundColor: kLine, color: kRed)),
        ]),
      ),
      PaperCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('القراءة هذا الأسبوع (صفحات)', style: kufi(13)),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final v in week.values)
                Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Container(height: 6 + 70 * v / mx, decoration: BoxDecoration(color: v == 0 ? kLine : kRed, borderRadius: BorderRadius.circular(5))))),
            ]),
          ),
        ]),
      ),
      Row(children: [
        Expanded(child: PaperCard(margin: const EdgeInsetsDirectional.only(end: 8), child: Column(children: [Text('$done', style: kufi(22, c: kRed)), Text('كتاب مكتمل', style: sans(11, c: kInk2))]))),
        Expanded(child: PaperCard(child: Column(children: [Text('$streak', style: kufi(22, c: kRed)), Text('أيام متتالية', style: sans(11, c: kInk2))]))),
      ]),
      const Head('الحساب والبيانات'),
      _item(context, Icons.backup_outlined, 'النسخ الاحتياطي والاسترجاع', 'تصدير واستيراد ملاحظاتك وأرففك كملف', const Backup()),
      _item(context, Icons.group_outlined, 'قوائم القراءة والمشاركة', 'شارك قائمة كتب أو ملاحظات كملف أو نص', const SharedLists()),
      _item(context, Icons.dashboard_outlined, 'إدارة المكتبة', 'المساحة، التكرار، الملفات التالفة', const Manage()),
      _item(context, Icons.settings_outlined, 'الإعدادات', 'الخط، القفل، Nidal AI', const SettingsScreen()),
    ]);
  }

  Widget _item(BuildContext c, IconData i, String t, String s, Widget w) => PaperCard(
        onTap: () => go(c, w),
        child: Row(children: [
          Icon(i, color: kRed), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: kufi(14)), Text(s, style: sans(11.5, c: kInk2))])),
          const Icon(Icons.chevron_left, color: kInk2),
        ]),
      );
}

class Backup extends StatelessWidget {
  const Backup({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('النسخ الاحتياطي')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          PaperCard(child: Text('بياناتك كلها على هذا الهاتف، ولا توجد مزامنة سحابية. النسخة الاحتياطية ملف JSON فيه قائمة كتبك وملاحظاتك وتمييزاتك وأرففك وإحصاءاتك. ملفات الكتب نفسها (PDF) لا تدخل في الملف؛ انسخها بنفسك. عند الاسترجاع على جهاز آخر استورد الكتب أولًا بنفس العناوين، ثم استرجع الملف لتعود الملاحظات إلى كتبها.', style: sans(13))),
          const SizedBox(height: 8),
          Btn('تصدير نسخة احتياطية', icon: Icons.upload, onTap: () async {
            final f = await app.exportBackup();
            await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'نسخة Nidal Books الاحتياطية'));
          }),
          const SizedBox(height: 10),
          Btn('استرجاع من ملف', outline: true, icon: Icons.download, onTap: () async {
            final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
            if (r.isEmpty || r.first.path == null) return;
            try {
              final n = await app.restoreBackup(r.first.path!);
              if (context.mounted) snack(context, 'تم استرجاع $n ملاحظة');
            } catch (e) {
              if (context.mounted) snack(context, 'الملف غير صالح');
            }
          }),
        ]),
      );
}

class SharedLists extends StatelessWidget {
  const SharedLists({super.key});
  String listText(Shelf s) {
    final sb = StringBuffer('قائمة: ${s.name}\n');
    for (final id in (app.shelfBooks[s.id] ?? [])) {
      final b = app.bookById(id);
      if (b != null) sb.writeln('- ${b.title}${b.author.isEmpty ? '' : ' (${b.author})'}');
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('قوائم القراءة')),
        body: ListenableBuilder(
          listenable: app,
          builder: (_, __) => ListView(padding: const EdgeInsets.all(18), children: [
            Text('بدون خادم لا توجد مشاركة حية بين مستخدمين. يمكنك إرسال قائمة كتب كنص عبر أي تطبيق (واتساب، تيليجرام...).', style: sans(12.5, c: kInk2)),
            const SizedBox(height: 8),
            if (app.shelves.isEmpty) const SizedBox(height: 200, child: Empty(Icons.shelves, 'أنشئ رفًّا من مكتبتي أولًا.')),
            for (final s in app.shelves)
              PaperCard(
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: kufi(15)), Text('${(app.shelfBooks[s.id] ?? []).length} كتاب', style: sans(11.5, c: kInk2))])),
                  IconButton(icon: const Icon(Icons.ios_share, color: kRed), onPressed: () => SharePlus.instance.share(ShareParams(text: listText(s)))),
                ]),
              ),
          ]),
        ),
      );
}

/// Local library management (replaces the server-side admin panel).
class Manage extends StatelessWidget {
  const Manage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إدارة المكتبة')),
        body: FutureBuilder<int>(
          future: app.storageBytes(),
          builder: (context, s) {
            final seen = <String>{};
            final dups = <Book>[];
            for (final b in app.books) {
              if (!seen.add(b.title.trim())) dups.add(b);
            }
            final missing = app.books.where((b) => !File(b.path).existsSync()).toList();
            return ListView(padding: const EdgeInsets.all(18), children: [
              Row(children: [
                Expanded(child: PaperCard(margin: const EdgeInsetsDirectional.only(end: 8), child: Column(children: [Text('${app.books.length}', style: kufi(22, c: kRed)), Text('كتاب', style: sans(11, c: kInk2))]))),
                Expanded(child: PaperCard(margin: const EdgeInsetsDirectional.only(end: 8), child: Column(children: [Text(s.hasData ? fmtBytes(s.data!) : '...', style: kufi(18, c: kRed)), Text('المساحة', style: sans(11, c: kInk2))]))),
                Expanded(child: PaperCard(child: Column(children: [Text('${app.notes.length}', style: kufi(22, c: kRed)), Text('ملاحظة', style: sans(11, c: kInk2))]))),
              ]),
              Head('مكررات (${dups.length})'),
              if (dups.isEmpty) Text('لا مكررات.', style: sans(13, c: kInk2)),
              for (final b in dups) BookRow(b, trailing: IconButton(icon: const Icon(Icons.delete_outline, color: kRed), onPressed: () => app.deleteBook(b))),
              Head('ملفات مفقودة (${missing.length})'),
              if (missing.isEmpty) Text('كل الملفات سليمة.', style: sans(13, c: kInk2)),
              for (final b in missing) BookRow(b, trailing: IconButton(icon: const Icon(Icons.delete_outline, color: kRed), onPressed: () => app.deleteBook(b))),
            ]);
          },
        ),
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('الإعدادات')),
          body: ListView(padding: const EdgeInsets.all(18), children: [
            PaperCard(child: Row(children: [
              Expanded(child: Text('السمة في القارئ', style: kufi(14))),
              Chip2('فاتح', on: !app.darkReader, onTap: () => app.setPref('dark', false)),
              Chip2('داكن', on: app.darkReader, onTap: () => app.setPref('dark', true)),
            ])),
            PaperCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('حجم خط القراءة: ${app.fontSize.round()}', style: kufi(14)),
              Slider(value: app.fontSize, min: 14, max: 32, divisions: 18, activeColor: kRed, onChanged: (v) => app.setPref('font', v)),
            ])),
            PaperCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('هدف القراءة الأسبوعي: ${app.weeklyGoalHours} ساعات', style: kufi(14)),
              Slider(value: app.weeklyGoalHours.toDouble(), min: 1, max: 20, divisions: 19, activeColor: kRed, onChanged: (v) => app.setPref('goal', v.round())),
            ])),
            PaperCard(
              onTap: () => _pin(context),
              child: Row(children: [
                const Icon(Icons.lock_outline, color: kRed), const SizedBox(width: 12),
                Expanded(child: Text(app.pin.isEmpty ? 'تفعيل رمز القفل' : 'تغيير أو إزالة رمز القفل', style: kufi(14))),
              ]),
            ),
            PaperCard(
              onTap: () => go(context, const AiSettings()),
              child: Row(children: [const Icon(Icons.auto_awesome, color: kRed), const SizedBox(width: 12), Expanded(child: Text('Nidal AI (المزود والمفتاح)', style: kufi(14)))]),
            ),
            PaperCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('حول Nidal Books', style: kufi(14)),
              Text('الإصدار 1.0 · كل بياناتك على هذا الجهاز · لا حساب ولا خادم.', style: sans(12, c: kInk2)),
            ])),
          ]),
        ),
      );

  Future<void> _pin(BuildContext context) async {
    final c = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard, title: Text('رمز القفل', style: kufi(16)),
        content: Field(c, '4 أرقام (فارغ = إزالة)', obscure: true, type: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              if (c.text.isNotEmpty && c.text.length != 4) return;
              await app.setPin(c.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

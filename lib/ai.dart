import 'package:material_ui/material_ui.dart';

import 'core.dart';
import 'reader.dart';
import 'ui.dart';

Ai get ai => Ai(app);

/// Nidal AI tab: choose a book, then chat / summarize / quiz / translate.
class AiTab extends StatefulWidget {
  const AiTab({super.key});
  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> {
  int? sel;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final b = sel != null ? app.bookById(sel!) : (app.books.isNotEmpty ? app.books.first : null);
          return ListView(padding: const EdgeInsets.fromLTRB(18, 12, 18, 24), children: [
            Text('Nidal AI', style: kufi(24)),
            const SizedBox(height: 4),
            Text(ai.configured ? 'متصل بمزودك: ${app.aiModel}' : 'غير مفعّل بعد: يحتاج مفتاح مزود وإنترنت', style: sans(12, c: ai.configured ? Colors.green.shade800 : kRed)),
            if (!ai.configured)
              PaperCard(
                margin: const EdgeInsets.only(top: 10),
                onTap: () => go(context, const AiSettings()),
                child: Row(children: [
                  const Icon(Icons.key, color: kRed),
                  const SizedBox(width: 10),
                  Expanded(child: Text('لتفعيل الأسئلة والترجمة والاختبارات أضف مفتاح مزود الذكاء الاصطناعي. التطبيق نفسه يعمل بدون إنترنت، لكن Nidal AI يحتاج اتصالًا.', style: sans(12.5))),
                ]),
              ),
            Head('اختر كتابًا'),
            if (b == null) const SizedBox(height: 200, child: Empty(Icons.menu_book_outlined, 'استورد كتابًا أولًا.')) else ...[
              SizedBox(
                height: 120,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final x in app.books)
                    GestureDetector(
                      onTap: () => setState(() => sel = x.id),
                      child: Container(
                        margin: const EdgeInsetsDirectional.only(end: 10), padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: x.id == b.id ? kRed : Colors.transparent, width: 2)),
                        child: Cover(x, w: 70, h: 100),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(b.title, style: kufi(15)),
              const SizedBox(height: 12),
              _tile(context, Icons.chat_bubble_outline, 'محادثة مع الكتاب', 'اسأل واحصل على إجابة مع رقم الصفحة', () => go(context, AiChat(b.id, page: b.lastPage))),
              _tile(context, Icons.summarize_outlined, 'ملخص الصفحات', 'ملخص نقاط رئيسية للصفحة الحالية', () => go(context, AiWork(b.id, 'summary'))),
              _tile(context, Icons.quiz_outlined, 'اختبر نفسك', 'أسئلة من النص (AI) أو بطاقات من تمييزاتك (محلي)', () => go(context, AiWork(b.id, 'quiz'))),
              _tile(context, Icons.translate, 'ترجمة وقراءة صوتية', 'ترجمة الصفحة (AI) وقراءتها بصوت الجهاز', () => go(context, AiWork(b.id, 'translate'))),
            ],
            const SizedBox(height: 8),
            Btn('إعدادات Nidal AI', outline: true, icon: Icons.settings_outlined, onTap: () => go(context, const AiSettings())),
          ]);
        },
      );

  Widget _tile(BuildContext c, IconData i, String t, String s, VoidCallback f) => PaperCard(
        onTap: f,
        child: Row(children: [
          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: kRed.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: kRed)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: kufi(14)), Text(s, style: sans(11.5, c: kInk2))])),
          const Icon(Icons.chevron_left, color: kInk2),
        ]),
      );
}

class AiSettings extends StatefulWidget {
  const AiSettings({super.key});
  @override
  State<AiSettings> createState() => _AiSettingsState();
}

class _AiSettingsState extends State<AiSettings> {
  final base = TextEditingController(text: app.aiBase);
  final model = TextEditingController(text: app.aiModel);
  final key = TextEditingController(text: app.aiKey);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('إعدادات Nidal AI')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text('Nidal AI يرسل نص الصفحات التي تسأل عنها مباشرة من هاتفك إلى المزود الذي تختاره (متوافق مع واجهة OpenAI). لا يوجد خادم وسيط من طرفنا، والمفتاح يُحفظ على هذا الهاتف فقط. بدون مفتاح أو إنترنت تبقى القراءة والبحث والملاحظات تعمل.', style: sans(12.5, c: kInk2)),
          const SizedBox(height: 14),
          Field(base, 'عنوان الواجهة (Base URL)', icon: Icons.link),
          const SizedBox(height: 10),
          Field(model, 'اسم النموذج', icon: Icons.memory),
          const SizedBox(height: 10),
          Field(key, 'مفتاح API', icon: Icons.key, obscure: true),
          const SizedBox(height: 16),
          Btn('حفظ', onTap: () async {
            await app.setPref('ai_base', base.text.trim());
            await app.setPref('ai_model', model.text.trim());
            await app.setPref('ai_key', key.text.trim());
            if (context.mounted) { snack(context, 'تم الحفظ'); Navigator.pop(context); }
          }),
          const SizedBox(height: 10),
          if (app.aiKey.isNotEmpty)
            Btn('حذف المفتاح', outline: true, onTap: () async { await app.setPref('ai_key', ''); key.clear(); setState(() {}); }),
        ]),
      );
}

class _Msg {
  _Msg(this.text, this.me, {this.err = false, this.local = false});
  final String text;
  final bool me, err, local;
}

class AiChat extends StatefulWidget {
  const AiChat(this.id, {super.key, this.page = 0, this.seed});
  final int id, page;
  final String? seed;
  @override
  State<AiChat> createState() => _AiChatState();
}

class _AiChatState extends State<AiChat> {
  late final Book b = app.bookById(widget.id)!;
  final msgs = <_Msg>[];
  final q = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.seed != null && widget.seed!.isNotEmpty) q.text = 'اشرح لي: ${widget.seed}';
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    setState(() { msgs.add(_Msg(text, true)); busy = true; q.clear(); });
    final r = await ai.chat(b, widget.page, text);
    if (!mounted) return;
    setState(() {
      busy = false;
      msgs.add(r.error != null ? _Msg(r.error!, false, err: true) : _Msg(r.text, false));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Nidal AI · ${b.title}', style: kufi(14), maxLines: 1)),
        body: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
              PaperCard(child: Text('أسأل عن «${b.title}». سأعتمد على نص الصفحات حول ص ${widget.page + 1}. الإجابات من نموذج ذكاء اصطناعي وقد تخطئ، راجع المصدر.', style: sans(12.5, c: kInk2))),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                for (final s in const ['لخّص هذه الصفحة', 'ما الفكرة الرئيسية؟', 'اشرح المصطلحات الصعبة'])
                  Chip2(s, onTap: () => send(s)),
              ])),
              const SizedBox(height: 10),
              for (final m in msgs)
                Align(
                  alignment: m.me ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
                    decoration: BoxDecoration(color: m.me ? kNavy : (m.err ? const Color(0xFFFBE9E5) : kCard), borderRadius: BorderRadius.circular(16), border: Border.all(color: m.err ? kRed : kLine)),
                    child: SelectableText(m.text, style: m.me ? sans(13.5, c: Colors.white) : naskh(16, h: 1.7)),
                  ),
                ),
              if (busy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: kRed))),
            ]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                Expanded(child: Field(q, 'اسأل عن الكتاب...', onSubmit: send)),
                const SizedBox(width: 8),
                IconButton.filled(style: IconButton.styleFrom(backgroundColor: kRed), onPressed: busy ? null : () => send(q.text), icon: const Icon(Icons.send, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      );
}

/// summary | quiz | translate for the current page of a book.
class AiWork extends StatefulWidget {
  const AiWork(this.id, this.mode, {super.key});
  final int id;
  final String mode;
  @override
  State<AiWork> createState() => _AiWorkState();
}

class _AiWorkState extends State<AiWork> {
  late final Book b = app.bookById(widget.id)!;
  String out = '';
  String? err;
  bool busy = false, local = false;
  String lang = 'الإنجليزية';
  List<(String, String)> cards = [];
  final shown = <int>{};

  String get title => {'summary': 'ملخص', 'quiz': 'اختبر نفسك', 'translate': 'ترجمة وصوت'}[widget.mode]!;

  Future<void> run({bool useLocal = false}) async {
    setState(() { busy = true; err = null; out = ''; local = useLocal; });
    final t = await app.bookTextSample(b, from: b.lastPage, count: 1);
    if (t.trim().isEmpty) {
      setState(() { busy = false; err = 'لا نص في الصفحة الحالية.'; });
      return;
    }
    if (useLocal) {
      if (widget.mode == 'summary') out = localSummary(t);
      if (widget.mode == 'quiz') cards = clozeFrom(app.notes.where((n) => n.bookId == b.id && n.kind == 'highlight').toList());
      setState(() => busy = false);
      return;
    }
    final r = widget.mode == 'summary' ? await ai.summarize(t) : widget.mode == 'quiz' ? await ai.quiz(t) : await ai.translate(t, lang);
    if (!mounted) return;
    setState(() { busy = false; out = r.text; err = r.error; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('$title · ${b.title}', style: kufi(14), maxLines: 1)),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          Text('الصفحة الحالية: ${b.lastPage + 1} من ${b.pages}', style: sans(12, c: kInk2)),
          const SizedBox(height: 12),
          if (widget.mode == 'translate')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                for (final l in const ['الإنجليزية', 'الفرنسية', 'التركية', 'الأردية'])
                  Chip2(l, on: lang == l, onTap: () => setState(() => lang = l)),
              ])),
            ),
          Btn(widget.mode == 'quiz' ? 'أسئلة بالذكاء الاصطناعي (إنترنت)' : widget.mode == 'translate' ? 'ترجم بالذكاء الاصطناعي (إنترنت)' : 'لخّص بالذكاء الاصطناعي (إنترنت)', icon: Icons.auto_awesome, onTap: busy ? null : () => run()),
          if (widget.mode != 'translate') ...[
            const SizedBox(height: 10),
            Btn(widget.mode == 'quiz' ? 'بطاقات من تمييزاتك (بدون إنترنت)' : 'ملخص بسيط على الجهاز (بدون إنترنت)', outline: true, icon: Icons.offline_bolt_outlined, onTap: busy ? null : () => run(useLocal: true)),
          ] else ...[
            const SizedBox(height: 10),
            Btn('قراءة الصفحة بصوت الجهاز', outline: true, icon: Icons.volume_up_outlined, onTap: () async {
              final t = await app.pageText(b, b.lastPage);
              if (t.isNotEmpty) await Speaker.speak(t);
            }),
          ],
          if (busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: kRed))),
          if (err != null) PaperCard(margin: const EdgeInsets.only(top: 14), child: Text(err!, style: sans(13, c: kRed))),
          if (local && out.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('ملخص محلي بسيط: يختار أهم الجمل من النص، وليس نموذج ذكاء اصطناعي.', style: sans(11.5, c: kInk2))),
          if (out.isNotEmpty) PaperCard(margin: const EdgeInsets.only(top: 8), child: SelectableText(out, style: naskh(17, h: 1.8))),
          if (local && widget.mode == 'quiz' && cards.isEmpty && !busy) const Padding(padding: EdgeInsets.only(top: 14), child: Text('لا توجد تمييزات كافية بعد. ميّز جملًا أثناء القراءة ثم عد هنا.')),
          for (var i = 0; i < cards.length; i++)
            PaperCard(
              onTap: () => setState(() => shown.add(i)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cards[i].$1, style: naskh(17, h: 1.7)),
                if (shown.contains(i)) Text('الجواب: ${cards[i].$2}', style: sans(13, c: kRed, w: FontWeight.w700)) else Text('اضغط لإظهار الجواب', style: sans(11, c: kInk2)),
              ]),
            ),
        ]),
      );
}

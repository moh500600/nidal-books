import 'package:material_ui/material_ui.dart';

import 'core.dart';
import 'main.dart';
import 'ui.dart';

class Welcome extends StatelessWidget {
  const Welcome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Spacer(),
              Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Cover(Book(title: ['كتب', 'قراءة', 'معرفة'][i], path: '', color: [0, 1, 2][i]), w: 72, h: 104),
                    ),
                ]),
              ),
              const SizedBox(height: 30),
              Text('Nidal Books', textAlign: TextAlign.center, style: kufi(32)),
              const SizedBox(height: 8),
              Text('مكتبتك الشخصية للكتب والـPDF، على جهازك أنت.', textAlign: TextAlign.center, style: naskh(17, c: kInk2)),
              const Spacer(),
              Btn('ابدأ', onTap: () => go(context, const CreateProfile())),
              const SizedBox(height: 10),
              Text('بياناتك وكتبك تبقى على هذا الهاتف. لا حساب سحابي ولا خادم.', textAlign: TextAlign.center, style: sans(11.5, c: kInk2)),
            ]),
          ),
        ),
      );
}

/// Local profile (replaces cloud sign-up): name + optional PIN lock.
class CreateProfile extends StatefulWidget {
  const CreateProfile({super.key});
  @override
  State<CreateProfile> createState() => _CreateProfileState();
}

class _CreateProfileState extends State<CreateProfile> {
  final name = TextEditingController(text: app.userName);
  final pin = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('أنشئ ملفك')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('ملفك محفوظ على هذا الجهاز فقط.', style: naskh(16, c: kInk2)),
          const SizedBox(height: 18),
          Field(name, 'اسمك', icon: Icons.person_outline),
          const SizedBox(height: 12),
          Field(pin, 'رمز قفل اختياري (4 أرقام)', icon: Icons.lock_outline, obscure: true, type: TextInputType.number),
          const SizedBox(height: 6),
          Text('إذا نسيت الرمز لا يمكن استرجاعه لأنه لا يوجد خادم. يمكنك تركه فارغًا.', style: sans(11.5, c: kInk2)),
          const SizedBox(height: 22),
          Btn('متابعة', onTap: () async {
            if (name.text.trim().isEmpty) return snack(context, 'اكتب اسمك');
            if (pin.text.isNotEmpty && pin.text.length != 4) return snack(context, 'الرمز 4 أرقام');
            await app.setPref('name', name.text.trim());
            if (pin.text.isNotEmpty) await app.setPref('pin', pin.text);
            if (context.mounted) go(context, const Interests());
          }),
        ]),
      );
}

class Interests extends StatefulWidget {
  const Interests({super.key});
  @override
  State<Interests> createState() => _InterestsState();
}

class _InterestsState extends State<Interests> {
  final sel = <String>{};
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ما الذي تحب قراءته؟')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(spacing: 0, runSpacing: 10, children: [
                  for (final c in kCategories)
                    Chip2(c, on: sel.contains(c), onTap: () => setState(() => sel.contains(c) ? sel.remove(c) : sel.add(c))),
                ]),
              ),
            ),
            Btn('ابدأ القراءة', onTap: () async {
              await app.setPref('interests', sel.toList());
              await app.setPref('onboarded', true);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Shell()), (r) => false);
              }
            }),
          ]),
        ),
      );
}

class Unlock extends StatefulWidget {
  const Unlock({super.key});
  @override
  State<Unlock> createState() => _UnlockState();
}

class _UnlockState extends State<Unlock> {
  String v = '';
  void tap(String d) {
    if (v.length >= 4) return;
    setState(() => v += d);
    if (v.length == 4) {
      if (v == app.pin) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
      } else {
        Future.delayed(const Duration(milliseconds: 250), () => setState(() => v = ''));
        snack(context, 'الرمز غير صحيح');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            const Spacer(),
            Text('مرحبًا ${app.userName}', style: kufi(22)),
            const SizedBox(height: 6),
            Text('أدخل رمز القفل', style: sans(13, c: kInk2)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 4; i++)
                Container(margin: const EdgeInsets.all(7), width: 14, height: 14,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i < v.length ? kRed : kLine)),
            ]),
            const Spacer(),
            for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '<']])
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final k in row)
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: SizedBox(
                      width: 72, height: 60,
                      child: k.isEmpty
                          ? null
                          : TextButton(
                              onPressed: () => k == '<' ? setState(() => v = v.isEmpty ? '' : v.substring(0, v.length - 1)) : tap(k),
                              style: TextButton.styleFrom(backgroundColor: kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kLine))),
                              child: k == '<' ? const Icon(Icons.backspace_outlined, color: kInk) : Text(k, style: kufi(22)),
                            ),
                    ),
                  ),
              ]),
            const SizedBox(height: 24),
          ]),
        ),
      );
}

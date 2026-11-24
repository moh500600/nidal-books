import 'package:material_ui/material_ui.dart';

import 'core.dart';

late final AppState app;

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: 'Sans',
      scaffoldBackgroundColor: kPaper,
      colorScheme: ColorScheme.fromSeed(seedColor: kRed, primary: kRed, surface: kPaper),
      appBarTheme: const AppBarTheme(
        backgroundColor: kPaper, foregroundColor: kInk, elevation: 0, centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: 'Kufi', fontSize: 17, fontWeight: FontWeight.w700, color: kInk),
      ),
      dividerColor: kLine,
    );

TextStyle kufi(double s, {Color c = kInk, FontWeight w = FontWeight.w700}) =>
    TextStyle(fontFamily: 'Kufi', fontSize: s, color: c, fontWeight: w, height: 1.35);
TextStyle naskh(double s, {Color c = kInk, FontWeight w = FontWeight.w400, double h = 1.9}) =>
    TextStyle(fontFamily: 'Naskh', fontSize: s, color: c, fontWeight: w, height: h);
TextStyle sans(double s, {Color c = kInk, FontWeight w = FontWeight.w400}) =>
    TextStyle(fontFamily: 'Sans', fontSize: s, color: c, fontWeight: w, height: 1.4);

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m, style: sans(13, c: Colors.white)), backgroundColor: kNavy));

Future<T?> go<T>(BuildContext c, Widget w) => Navigator.of(c).push<T>(MaterialPageRoute(builder: (_) => w));

/// Procedural cover: a deterministic pattern so every book has its own art.
class Cover extends StatelessWidget {
  const Cover(this.b, {super.key, this.w = 64, this.h = 90});
  final Book b;
  final double w, h;
  @override
  Widget build(BuildContext context) {
    final c = kCoverColors[b.color % kCoverColors.length];
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, .35)!], begin: Alignment.topRight, end: Alignment.bottomLeft),
        border: Border(right: BorderSide(color: kHi.withValues(alpha: .6), width: 2.5)),
      ),
      child: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _Pattern(b.color))),
        Positioned(
          left: 5, right: 7, bottom: 5,
          child: Text(b.title, maxLines: 3, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right,
              style: kufi(w / 7.5 + 2.5, c: Colors.white)),
        ),
      ]),
    );
  }
}

class _Pattern extends CustomPainter {
  _Pattern(this.k);
  final int k;
  @override
  void paint(Canvas c, Size s) {
    final pt = Paint()..color = Colors.white.withValues(alpha: .13)..style = PaintingStyle.stroke..strokeWidth = 1.2;
    final ctr = Offset(s.width / 2, s.height * .36);
    switch (k % 3) {
      case 0:
        for (var i = 1; i <= 3; i++) {
          c.drawCircle(ctr, s.width * .12 * i, pt);
        }
      case 1:
        final path = Path()..moveTo(ctr.dx, ctr.dy - s.width * .3)..lineTo(ctr.dx + s.width * .3, ctr.dy + s.width * .25)..lineTo(ctr.dx - s.width * .3, ctr.dy + s.width * .25)..close();
        c.drawPath(path, pt);
      default:
        for (var i = 0; i < 4; i++) {
          c.drawLine(Offset(0, s.height * .1 * i + 8), Offset(s.width, s.height * .1 * i + 18), pt);
        }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.child, this.onTap, this.pad = 14, this.margin});
  final Widget child;
  final VoidCallback? onTap;
  final double pad;
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: Padding(padding: EdgeInsets.all(pad), child: child)),
        ),
      );
}

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.onTap, this.icon, this.outline = false, this.wide = true});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outline, wide;
  @override
  Widget build(BuildContext context) {
    final fg = outline ? kRed : Colors.white;
    return SizedBox(
      width: wide ? double.infinity : null,
      height: 46,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: outline ? Colors.transparent : kRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: kRed, width: outline ? 1.4 : 0)),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
          Flexible(child: Text(label, style: kufi(14, c: fg), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

class Chip2 extends StatelessWidget {
  const Chip2(this.label, {super.key, this.on = false, this.onTap});
  final String label;
  final bool on;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsetsDirectional.only(end: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: on ? kInk : kCard, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? kInk : kLine),
          ),
          child: Text(label, style: sans(12.5, c: on ? Colors.white : kInk, w: FontWeight.w700)),
        ),
      );
}

class Head extends StatelessWidget {
  const Head(this.t, {super.key, this.action, this.onAction});
  final String t;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        child: Row(children: [
          Expanded(child: Text(t, style: kufi(16))),
          if (action != null) GestureDetector(onTap: onAction, child: Text(action!, style: sans(12, c: kRed))),
        ]),
      );
}

class Field extends StatelessWidget {
  const Field(this.ctl, this.hint, {super.key, this.icon, this.obscure = false, this.lines = 1, this.onSubmit, this.type});
  final TextEditingController ctl;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final int lines;
  final ValueChanged<String>? onSubmit;
  final TextInputType? type;
  @override
  Widget build(BuildContext context) => TextField(
        controller: ctl, obscureText: obscure, maxLines: obscure ? 1 : lines, onSubmitted: onSubmit, keyboardType: type,
        style: sans(14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: sans(13, c: kInk2),
          prefixIcon: icon == null ? null : Icon(icon, color: kInk2, size: 20),
          filled: true, fillColor: kCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLine)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLine)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kRed)),
        ),
      );
}

class BookRow extends StatelessWidget {
  const BookRow(this.b, {super.key, this.onTap, this.trailing});
  final Book b;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => PaperCard(
        onTap: onTap, pad: 10,
        child: Row(children: [
          Cover(b, w: 46, h: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: kufi(14)),
              const SizedBox(height: 2),
              Text(b.author.isEmpty ? 'مؤلف غير محدد' : b.author, style: sans(11.5, c: kInk2)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(value: b.progress, minHeight: 5, backgroundColor: kLine, color: kRed),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${(b.progress * 100).round()}%', style: sans(11, c: kInk2)),
              ]),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class Empty extends StatelessWidget {
  const Empty(this.icon, this.msg, {super.key, this.action, this.onAction});
  final IconData icon;
  final String msg;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 46, color: kInk2.withValues(alpha: .6)),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: sans(14, c: kInk2)),
            if (action != null) ...[const SizedBox(height: 14), Btn(action!, onTap: onAction, wide: false)],
          ]),
        ),
      );
}

String fmtBytes(int n) {
  if (n < 1024) return '$n B';
  if (n < 1048576) return '${(n / 1024).toStringAsFixed(0)} KB';
  if (n < 1073741824) return '${(n / 1048576).toStringAsFixed(1)} MB';
  return '${(n / 1073741824).toStringAsFixed(2)} GB';
}

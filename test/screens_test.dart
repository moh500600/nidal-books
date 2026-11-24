import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
// Renders real app widgets with the bundled fonts so their layout can be
// compared with the approved "Paper & Ink" design. Run with --update-goldens
// to write PNGs into test/goldens (CI uploads them as an artifact).
import 'dart:io' show Platform;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nidal_books/core.dart';
import 'package:nidal_books/onboarding.dart';
import 'package:nidal_books/ui.dart';

Future<void> shoot(WidgetTester t, String name, Widget home) async {
  t.view.physicalSize = const Size(780, 1688);
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
    home: home,
  ));
  await t.pump(const Duration(milliseconds: 300));
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
}

final _skip = !Platform.environment.containsKey('NB_RENDER'); // set NB_RENDER=1 (with --update-goldens) to write renders

void main() {
  setUpAll(() {
    app = AppState();
  });

  testWidgets('welcome screen', (t) => shoot(t, 'welcome', const Welcome()), skip: _skip);
  testWidgets('unlock screen', (t) => shoot(t, 'unlock', const Unlock()), skip: _skip);
  testWidgets('book covers', (t) => shoot(
        t,
        'covers',
        Scaffold(
          body: SafeArea(
            child: Center(
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < 6; i++) Cover(Book(title: 'كتاب ${i + 1}', author: 'مؤلف', path: '', color: i), w: 90, h: 130),
              ]),
            ),
          ),
        ),
      ), skip: _skip);
}

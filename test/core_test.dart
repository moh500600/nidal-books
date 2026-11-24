import 'package:flutter_test/flutter_test.dart';
import 'package:nidal_books/core.dart';

void main() {
  test('splitText keeps paragraphs and pages are non-empty', () {
    final t = List.generate(30, (i) => 'فقرة رقم $i ' * 20).join('\n\n');
    final pages = splitText(t);
    expect(pages.length, greaterThan(3));
    expect(pages.every((p) => p.trim().isNotEmpty), true);
    expect(splitText('').length, 1);
  });

  test('localSummary returns at most N sentences', () {
    const t = 'هذه جملة طويلة عن تاريخ الأمم والدول والملوك. وهذه جملة أخرى طويلة عن العمران والحضارة. '
        'وجملة ثالثة طويلة جدا عن الاقتصاد والمعاش والكسب. وجملة رابعة طويلة عن السياسة والحكم والدولة.';
    final s = localSummary(t, sentences: 2);
    expect(s.split('\n').length, 2);
  });

  test('clozeFrom blanks the longest word', () {
    final c = clozeFrom([Note(bookId: 1, page: 0, kind: 'highlight', quote: 'العمران البشري ضروري للاجتماع الإنساني')]);
    expect(c.length, 1);
    expect(c.first.$1.contains('_____'), true);
  });

  test('Book progress is clamped', () {
    final b = Book(title: 'x', path: '', pages: 10, lastPage: 99);
    expect(b.progress, 1.0);
  });
}

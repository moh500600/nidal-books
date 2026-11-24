import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'security.dart';

// ---------- palette ("ورق وحبر") ----------
const kPaper = Color(0xFFF6F1E7);
const kCard = Color(0xFFFFFAF1);
const kInk = Color(0xFF161A2B);
const kInk2 = Color(0xFF6B6455);
const kRed = Color(0xFFB3402A);
const kNavy = Color(0xFF1F2A44);
const kHi = Color(0xFFF2D58F);
const kLine = Color(0xFFE3D8C2);

const kCategories = [
  'البرمجة والتقنية', 'الذكاء الاصطناعي', 'الأمن السيبراني', 'العلوم', 'الطب',
  'الهندسة', 'التاريخ', 'الإدارة والأعمال', 'الاقتصاد', 'التعليم',
  'الروايات والأدب', 'التنمية البشرية', 'الدين', 'اللغات', 'القانون', 'كتب الأطفال',
];

const kCoverColors = [
  Color(0xFF3B2A1A), Color(0xFF1F5A63), Color(0xFF2E1F5A), Color(0xFF1F4A33),
  Color(0xFF5A1F2E), Color(0xFF1F2A44),
];

class Book {
  Book({
    this.id = 0, required this.title, this.author = '', this.category = '',
    required this.path, this.kind = 'pdf', this.pages = 1, this.lastPage = 0,
    this.fav = false, this.color = 0, int? added,
  }) : added = added ?? DateTime.now().millisecondsSinceEpoch;
  int id;
  String title, author, category, path, kind;
  int pages, lastPage, color, added;
  bool fav;
  double get progress => pages <= 1 ? 0 : ((lastPage + 1) / pages).clamp(0, 1).toDouble();

  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id, 'title': title, 'author': author, 'category': category,
        'path': path, 'kind': kind, 'pages': pages, 'last_page': lastPage,
        'fav': fav ? 1 : 0, 'color': color, 'added': added,
      };
  static Book from(Map<String, Object?> m) => Book(
        id: m['id'] as int, title: m['title'] as String, author: (m['author'] ?? '') as String,
        category: (m['category'] ?? '') as String, path: m['path'] as String,
        kind: m['kind'] as String, pages: m['pages'] as int, lastPage: m['last_page'] as int,
        fav: m['fav'] == 1, color: m['color'] as int, added: m['added'] as int,
      );
}

class Note {
  Note({this.id = 0, required this.bookId, required this.page, required this.kind,
      this.quote = '', this.body = '', int? created})
      : created = created ?? DateTime.now().millisecondsSinceEpoch;
  int id, bookId, page, created;
  String kind; // highlight | note | bookmark
  String quote, body;
  Map<String, Object?> toMap() => {
        if (id != 0) 'id': id, 'book_id': bookId, 'page': page, 'kind': kind,
        'quote': quote, 'body': body, 'created': created,
      };
  static Note from(Map<String, Object?> m) => Note(
        id: m['id'] as int, bookId: m['book_id'] as int, page: m['page'] as int,
        kind: m['kind'] as String, quote: (m['quote'] ?? '') as String,
        body: (m['body'] ?? '') as String, created: m['created'] as int,
      );
}

class Shelf {
  Shelf(this.id, this.name);
  int id;
  String name;
}

/// Local-only app state. Everything lives on the phone: SQLite + files + preferences.
class AppState extends ChangeNotifier {
  late Database db;
  late SharedPreferences prefs;
  final FlutterSecureStorage secure = const FlutterSecureStorage();
  late Directory dir;
  List<Book> books = [];
  List<Note> notes = [];
  List<Shelf> shelves = [];
  Map<int, List<int>> shelfBooks = {};
  final Map<String, String> _pageCache = {};

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    await _migrateSecrets();
    dir = await getApplicationDocumentsDirectory();
    await Directory(p.join(dir.path, 'books')).create(recursive: true);
    db = await openDatabase(p.join(dir.path, 'nidal_books.db'), version: 1,
        onCreate: (d, v) async {
      await d.execute('CREATE TABLE books(id INTEGER PRIMARY KEY AUTOINCREMENT,title TEXT,author TEXT,category TEXT,path TEXT,kind TEXT,pages INTEGER,last_page INTEGER DEFAULT 0,fav INTEGER DEFAULT 0,color INTEGER DEFAULT 0,added INTEGER)');
      await d.execute('CREATE TABLE notes(id INTEGER PRIMARY KEY AUTOINCREMENT,book_id INTEGER,page INTEGER,kind TEXT,quote TEXT,body TEXT,created INTEGER)');
      await d.execute('CREATE TABLE shelves(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT)');
      await d.execute('CREATE TABLE shelf_books(shelf_id INTEGER,book_id INTEGER)');
      await d.execute('CREATE TABLE reading(day TEXT PRIMARY KEY,pages INTEGER DEFAULT 0,secs INTEGER DEFAULT 0)');
    });
    if (!(prefs.getBool('seeded') ?? false)) {
      await _seed();
      await prefs.setBool('seeded', true);
    }
    await reload();
  }

  Future<void> _seed() async {
    final txt = await rootBundle.loadString('assets/books/muqaddima.txt');
    final f = File(p.join(dir.path, 'books', 'muqaddima.txt'));
    await f.writeAsString(txt);
    final b = Book(title: 'مقدمة ابن خلدون (مقتطف تجريبي)', author: 'عبد الرحمن بن خلدون',
        category: 'التاريخ', path: f.path, kind: 'txt', color: 0);
    b.pages = splitText(txt.split('\n').skip(2).join('\n')).length;
    await db.insert('books', b.toMap());
  }

  Future<void> reload() async {
    books = (await db.query('books', orderBy: 'added DESC')).map(Book.from).toList();
    notes = (await db.query('notes', orderBy: 'created DESC')).map(Note.from).toList();
    shelves = (await db.query('shelves')).map((m) => Shelf(m['id'] as int, m['name'] as String)).toList();
    shelfBooks = {};
    for (final r in await db.query('shelf_books')) {
      (shelfBooks[r['shelf_id'] as int] ??= []).add(r['book_id'] as int);
    }
    notifyListeners();
  }

  // ---- prefs ----
  String get userName => prefs.getString('name') ?? '';
  bool get onboarded => prefs.getBool('onboarded') ?? false;
  /// Stored PIN record (salted PBKDF2 hash). Empty means no lock.
  String get pin => prefs.getString('pin') ?? '';
  Future<void> setPin(String v) async {
    if (v.isEmpty) {
      await prefs.remove('pin');
    } else {
      await prefs.setString('pin', await compute(hashPinTask, v));
    }
    notifyListeners();
  }

  Future<bool> checkPin(String v) => compute(verifyPinTask, (v, pin));
  bool get darkReader => prefs.getBool('dark') ?? false;
  double get fontSize => prefs.getDouble('font') ?? 19;
  int get weeklyGoalHours => prefs.getInt('goal') ?? 5;
  List<String> get interests => prefs.getStringList('interests') ?? [];
  String get aiBase => prefs.getString('ai_base') ?? 'https://api.openai.com/v1';
  String get aiModel => prefs.getString('ai_model') ?? 'gpt-4o-mini';
  String _aiKey = '';
  String get aiKey => _aiKey;
  Future<void> setAiKey(String v) async {
    _aiKey = v;
    if (v.isEmpty) {
      await secure.delete(key: 'ai_key');
    } else {
      await secure.write(key: 'ai_key', value: v);
    }
    notifyListeners();
  }

  /// Moves values saved by 0.1.0 (plain text in app preferences) to safe storage.
  Future<void> _migrateSecrets() async {
    try {
      _aiKey = await secure.read(key: 'ai_key') ?? '';
      final old = prefs.getString('ai_key') ?? '';
      if (old.isNotEmpty) {
        if (_aiKey.isEmpty) {
          await secure.write(key: 'ai_key', value: old);
          _aiKey = old;
        }
        await prefs.remove('ai_key');
      }
    } catch (_) {
      // Secure storage unavailable: keep the key in memory only, never write plain text.
    }
    final p0 = prefs.getString('pin') ?? '';
    if (p0.isNotEmpty && !isPinRecord(p0)) {
      await prefs.setString('pin', await compute(hashPinTask, p0));
    }
  }
  Future<void> setPref(String k, Object v) async {
    if (v is String) await prefs.setString(k, v);
    if (v is bool) await prefs.setBool(k, v);
    if (v is int) await prefs.setInt(k, v);
    if (v is double) await prefs.setDouble(k, v);
    if (v is List<String>) await prefs.setStringList(k, v);
    notifyListeners();
  }

  // ---- books ----
  Future<Book?> importFile(String srcPath, {String? name}) async {
    final ext = p.extension(srcPath).toLowerCase();
    final base = p.basenameWithoutExtension(name ?? srcPath);
    final dest = File(p.join(dir.path, 'books', '${DateTime.now().millisecondsSinceEpoch}$ext'));
    await File(srcPath).copy(dest.path);
    final b = Book(title: base, path: dest.path, kind: ext == '.pdf' ? 'pdf' : 'txt',
        color: Random().nextInt(kCoverColors.length));
    if (b.kind == 'pdf') {
      final doc = await PdfDocument.openFile(dest.path);
      b.pages = doc.pages.length;
      await doc.dispose();
    } else {
      b.pages = splitText(await dest.readAsString()).length;
    }
    b.id = await db.insert('books', b.toMap());
    await reload();
    return b;
  }

  Future<bool> duplicateOf(String title) async =>
      books.any((b) => b.title.trim() == title.trim());

  Future<void> saveBook(Book b) async {
    await db.update('books', b.toMap(), where: 'id=?', whereArgs: [b.id]);
    await reload();
  }

  Future<void> deleteBook(Book b) async {
    await db.delete('books', where: 'id=?', whereArgs: [b.id]);
    await db.delete('notes', where: 'book_id=?', whereArgs: [b.id]);
    await db.delete('shelf_books', where: 'book_id=?', whereArgs: [b.id]);
    try { await File(b.path).delete(); } catch (_) {}
    await reload();
  }

  Future<void> setProgress(Book b, int page) async {
    b.lastPage = page;
    await db.update('books', {'last_page': page}, where: 'id=?', whereArgs: [b.id]);
    final day = DateTime.now().toIso8601String().substring(0, 10);
    await db.execute('INSERT INTO reading(day,pages,secs) VALUES(?,1,30) ON CONFLICT(day) DO UPDATE SET pages=pages+1,secs=secs+30', [day]);
    notifyListeners();
  }

  Future<Map<String, int>> weekPages() async {
    final out = <String, int>{};
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
      out[d] = 0;
    }
    for (final r in await db.query('reading')) {
      final d = r['day'] as String;
      if (out.containsKey(d)) out[d] = r['pages'] as int;
    }
    return out;
  }

  Future<int> totalSecs() async {
    final r = await db.rawQuery('SELECT COALESCE(SUM(secs),0) s FROM reading');
    return (r.first['s'] as int?) ?? 0;
  }

  Future<int> streak() async {
    final rows = await db.query('reading', where: 'pages>0');
    final days = rows.map((r) => r['day'] as String).toSet();
    var n = 0;
    var d = DateTime.now();
    while (days.contains(d.toIso8601String().substring(0, 10))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ---- text pages ----
  Future<String> pageText(Book b, int page) async {
    final key = '${b.id}:$page';
    if (_pageCache.containsKey(key)) return _pageCache[key]!;
    String t;
    if (b.kind == 'txt') {
      var raw = await File(b.path).readAsString();
      if (b.path.endsWith('muqaddima.txt')) raw = raw.split('\n').skip(2).join('\n');
      final pages = splitText(raw);
      t = page < pages.length ? pages[page] : '';
    } else {
      final doc = await PdfDocument.openFile(b.path);
      try {
        final pg = doc.pages[page];
        final raw = await pg.loadText();
        t = (raw?.fullText ?? '').trim();
      } finally {
        await doc.dispose();
      }
    }
    _pageCache[key] = t;
    return t;
  }

  Future<String> bookTextSample(Book b, {int from = 0, int count = 4}) async {
    final sb = StringBuffer();
    for (var i = from; i < min(b.pages, from + count); i++) {
      sb.writeln(await pageText(b, i));
    }
    return sb.toString();
  }

  /// Plain-text search through the pages of one book (local).
  Future<List<(int, String)>> searchBook(Book b, String q, {int limit = 20}) async {
    final out = <(int, String)>[];
    if (q.trim().isEmpty) return out;
    for (var i = 0; i < b.pages && out.length < limit; i++) {
      final t = await pageText(b, i);
      final at = t.indexOf(q);
      if (at >= 0) {
        final s = max(0, at - 40);
        out.add((i, t.substring(s, min(t.length, at + q.length + 60)).replaceAll('\n', ' ')));
      }
    }
    return out;
  }

  // ---- notes ----
  Future<void> addNote(Note n) async {
    n.id = await db.insert('notes', n.toMap());
    await reload();
  }

  Future<void> deleteNote(Note n) async {
    await db.delete('notes', where: 'id=?', whereArgs: [n.id]);
    await reload();
  }

  Future<void> updateNote(Note n) async {
    await db.update('notes', n.toMap(), where: 'id=?', whereArgs: [n.id]);
    await reload();
  }

  Book? bookById(int id) {
    for (final b in books) {
      if (b.id == id) return b;
    }
    return null;
  }

  // ---- shelves ----
  Future<void> addShelf(String name) async {
    await db.insert('shelves', {'name': name});
    await reload();
  }

  Future<void> deleteShelf(Shelf s) async {
    await db.delete('shelves', where: 'id=?', whereArgs: [s.id]);
    await db.delete('shelf_books', where: 'shelf_id=?', whereArgs: [s.id]);
    await reload();
  }

  Future<void> toggleInShelf(Shelf s, Book b) async {
    final has = (shelfBooks[s.id] ?? []).contains(b.id);
    if (has) {
      await db.delete('shelf_books', where: 'shelf_id=? AND book_id=?', whereArgs: [s.id, b.id]);
    } else {
      await db.insert('shelf_books', {'shelf_id': s.id, 'book_id': b.id});
    }
    await reload();
  }

  // ---- backup / restore (metadata + notes, JSON; book files are not included) ----
  Future<File> exportBackup() async {
    final data = {
      'app': 'CMD Book', 'version': 1,
      'books': (await db.query('books')),
      'notes': (await db.query('notes')),
      'shelves': (await db.query('shelves')),
      'shelf_books': (await db.query('shelf_books')),
      'reading': (await db.query('reading')),
      'prefs': {'name': userName, 'goal': weeklyGoalHours, 'interests': interests},
    };
    final f = File(p.join((await getTemporaryDirectory()).path, 'cmd-book-backup.json'));
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert(data));
    return f;
  }

  /// Returns number of notes restored. Notes are matched to books by title.
  Future<int> restoreBackup(String path) async {
    final data = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    if (data['app'] != 'CMD Book' && data['app'] != 'Nidal Books') throw 'ملف نسخة احتياطية غير صالح';
    final oldBooks = {for (final b in (data['books'] as List)) b['id'] as int: b as Map<String, dynamic>};
    var count = 0;
    for (final n in (data['notes'] as List)) {
      final ob = oldBooks[n['book_id']];
      if (ob == null) continue;
      Book? target;
      for (final b in books) {
        if (b.title == ob['title']) target = b;
      }
      if (target == null) continue;
      final dup = notes.any((x) => x.bookId == target!.id && x.page == n['page'] && x.quote == n['quote'] && x.body == n['body']);
      if (dup) continue;
      await db.insert('notes', Note(bookId: target.id, page: n['page'] as int, kind: n['kind'] as String,
          quote: (n['quote'] ?? '') as String, body: (n['body'] ?? '') as String,
          created: n['created'] as int).toMap());
      count++;
    }
    for (final s in (data['shelves'] as List)) {
      if (!shelves.any((x) => x.name == s['name'])) await db.insert('shelves', {'name': s['name']});
    }
    await reload();
    return count;
  }

  Future<int> storageBytes() async {
    var n = 0;
    for (final b in books) {
      try { n += await File(b.path).length(); } catch (_) {}
    }
    return n;
  }
}

List<String> splitText(String raw, {int size = 1100}) {
  final paras = raw.split(RegExp(r'\n\s*\n')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  final pages = <String>[];
  var cur = StringBuffer();
  for (final para in paras) {
    if (cur.length + para.length > size && cur.isNotEmpty) {
      pages.add(cur.toString().trim());
      cur = StringBuffer();
    }
    cur.writeln(para);
    cur.writeln();
  }
  if (cur.toString().trim().isNotEmpty) pages.add(cur.toString().trim());
  return pages.isEmpty ? [''] : pages;
}

// ---------- AI: optional, calls the user's own endpoint directly (no backend of ours) ----------
class AiResult {
  AiResult(this.text, {this.local = false, this.error});
  final String text;
  final bool local;
  final String? error;
}

class Ai {
  Ai(this.s);
  final AppState s;
  bool get configured => s.aiKey.isNotEmpty;

  Future<AiResult> ask(String system, String user) async {
    if (!configured) {
      return AiResult('', error: 'لم يُضبط مزود الذكاء الاصطناعي. أضف مفتاحك من الإعدادات > Nidal AI (يحتاج إنترنت).');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final base = s.aiBase.replaceAll(RegExp(r'/+$'), '');
      final req = await client.postUrl(Uri.parse('$base/chat/completions'));
      req.headers.set('content-type', 'application/json');
      req.headers.set('authorization', 'Bearer ${s.aiKey}');
      req.add(utf8.encode(jsonEncode({
        'model': s.aiModel,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      })));
      final res = await req.close().timeout(const Duration(seconds: 60));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) {
        return AiResult('', error: 'تعذر الاتصال بمزود الذكاء الاصطناعي (${res.statusCode}).');
      }
      final j = jsonDecode(body);
      return AiResult((j['choices'][0]['message']['content'] as String).trim());
    } on SocketException {
      return AiResult('', error: 'لا يوجد اتصال بالإنترنت. Nidal AI يحتاج إنترنت؛ بقية التطبيق يعمل بدون اتصال.');
    } catch (e) {
      return AiResult('', error: 'تعذر تنفيذ الطلب: $e');
    } finally {
      client.close();
    }
  }

  static const sysBook = 'أنت Nidal AI، مساعد قراءة. أجب بالعربية بإيجاز، واعتمد فقط على نص الكتاب المرفق. '
      'اذكر رقم الصفحة عند الاقتباس. إن لم تجد الجواب في النص فقل ذلك بصراحة.';

  Future<AiResult> chat(Book b, int page, String q) async {
    final ctx = await s.bookTextSample(b, from: max(0, page - 1), count: 4);
    return ask(sysBook, 'الكتاب: ${b.title}\nالصفحات حول ${page + 1}:\n$ctx\n\nالسؤال: $q');
  }

  Future<AiResult> summarize(String text) =>
      ask(sysBook, 'لخّص النص التالي في نقاط رئيسية قصيرة:\n$text');

  Future<AiResult> quiz(String text) => ask(sysBook,
      'أنشئ 3 أسئلة اختيار من متعدد من النص التالي، مع الإجابة الصحيحة بعد كل سؤال:\n$text');

  Future<AiResult> translate(String text, String lang) =>
      ask('أنت مترجم دقيق.', 'ترجم النص التالي إلى $lang دون إضافات:\n$text');
}

// ---------- local (on-device) helpers: not a language model ----------
String localSummary(String text, {int sentences = 3}) {
  final parts = text
      .split(RegExp(r'(?<=[\.\!\؟\?،؛])\s+|\n+'))
      .map((e) => e.trim())
      .where((e) => e.length > 25)
      .toList();
  if (parts.length <= sentences) return parts.join('\n');
  final freq = <String, int>{};
  for (final w in text.split(RegExp(r'[\s،\.\!\؟\?؛:]+'))) {
    if (w.length > 3) freq[w] = (freq[w] ?? 0) + 1;
  }
  final scored = <int, double>{};
  for (var i = 0; i < parts.length; i++) {
    var sc = 0.0;
    final ws = parts[i].split(RegExp(r'\s+'));
    for (final w in ws) {
      sc += freq[w] ?? 0;
    }
    scored[i] = sc / (ws.length + 3);
  }
  final top = scored.keys.toList()..sort((a, b) => scored[b]!.compareTo(scored[a]!));
  final pick = top.take(sentences).toList()..sort();
  return pick.map((i) => parts[i]).join('\n');
}

/// Fill-in-the-blank cards from highlights (local).
List<(String, String)> clozeFrom(List<Note> notes) {
  final out = <(String, String)>[];
  for (final n in notes) {
    final t = (n.quote.isNotEmpty ? n.quote : n.body).trim();
    final ws = t.split(RegExp(r'\s+'));
    if (ws.length < 4) continue;
    var idx = 0;
    for (var i = 0; i < ws.length; i++) {
      if (ws[i].length > ws[idx].length) idx = i;
    }
    final ans = ws[idx];
    final q = [...ws]..[idx] = '_____';
    out.add((q.join(' '), ans));
  }
  return out;
}

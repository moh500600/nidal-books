import 'package:flutter_test/flutter_test.dart';
import 'package:nidal_books/security.dart';

void main() {
  test('PBKDF2-HMAC-SHA256 matches RFC 7914 test vector and RFC 7914 style checks', () {
    // RFC 6070-style vector for SHA-256: P="password", S="salt", c=1, dkLen=32
    final h = pbkdf2('password'.codeUnits, 'salt'.codeUnits, 1);
    final hex = h.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(hex, '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    final h2 = pbkdf2('password'.codeUnits, 'salt'.codeUnits, 4096);
    final hex2 = h2.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    expect(hex2, 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
  });

  test('PIN record verifies only the right PIN and is salted', () {
    final a = hashPin('1234', iterations: 2000);
    final b = hashPin('1234', iterations: 2000);
    expect(a == b, false);
    expect(a.contains('1234'), false);
    expect(isPinRecord(a), true);
    expect(verifyPinRecord('1234', a), true);
    expect(verifyPinRecord('1235', a), false);
    expect(verifyPinRecord('1234', '1234'), false);
    expect(verifyPinRecord('1234', 'pbkdf2\$x'), false);
  });
}

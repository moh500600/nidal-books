import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256. Slow on purpose, so a stolen file is expensive to brute-force.
List<int> pbkdf2(List<int> password, List<int> salt, int iterations, {int length = 32}) {
  final hmac = Hmac(sha256, password);
  final blocks = (length / 32).ceil();
  final out = <int>[];
  for (var i = 1; i <= blocks; i++) {
    var u = hmac.convert([...salt, (i >> 24) & 255, (i >> 16) & 255, (i >> 8) & 255, i & 255]).bytes;
    final t = List<int>.from(u);
    for (var j = 1; j < iterations; j++) {
      u = hmac.convert(u).bytes;
      for (var k = 0; k < t.length; k++) {
        t[k] ^= u[k];
      }
    }
    out.addAll(t);
  }
  return out.sublist(0, length);
}

const pinIterations = 120000;

/// Record format: `pbkdf2$iterations$saltB64$hashB64`
String hashPin(String pin, {List<int>? salt, int iterations = pinIterations}) {
  final s = salt ?? List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final h = pbkdf2(utf8.encode(pin), s, iterations);
  return 'pbkdf2\$$iterations\$${base64.encode(s)}\$${base64.encode(h)}';
}

bool isPinRecord(String r) => r.startsWith('pbkdf2\$');

bool verifyPinRecord(String pin, String record) {
  if (!isPinRecord(record)) return false;
  final parts = record.split('\$');
  if (parts.length != 4) return false;
  final iters = int.tryParse(parts[1]);
  if (iters == null || iters < 1) return false;
  final salt = base64.decode(parts[2]);
  final want = base64.decode(parts[3]);
  final got = pbkdf2(utf8.encode(pin), salt, iters);
  if (got.length != want.length) return false;
  var diff = 0;
  for (var i = 0; i < got.length; i++) {
    diff |= got[i] ^ want[i];
  }
  return diff == 0;
}

/// Top-level so it can run in an isolate via compute().
String hashPinTask(String pin) => hashPin(pin);
bool verifyPinTask((String, String) a) => verifyPinRecord(a.$1, a.$2);

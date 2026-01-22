import 'dart:math';

import 'package:path/path.dart' as p;

class ObjStoreKey {
  static String generate({required String filename, String prefix = ''}) {
    final ext = p.extension(filename).trim();
    final safeExt = ext.isEmpty ? '' : ext;

    final ms = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(1 << 20).toRadixString(16).padLeft(5, '0');
    final name = '$ms-$rnd$safeExt';

    final normalizedPrefix = _normalizePrefix(prefix);
    return '$normalizedPrefix$name';
  }

  static String _normalizePrefix(String prefix) {
    final raw = prefix.trim();
    if (raw.isEmpty) return '';
    return raw.endsWith('/') ? raw : '$raw/';
  }
}

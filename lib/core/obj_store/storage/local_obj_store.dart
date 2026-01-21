import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../obj_store_key.dart';

typedef BaseDirProvider = Future<Directory> Function();

class LocalObjStore {
  final BaseDirProvider _baseDirProvider;

  LocalObjStore({required BaseDirProvider baseDirProvider})
    : _baseDirProvider = baseDirProvider;

  Future<LocalStoredObject> saveBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final baseDir = await _baseDirProvider();
    final dir = Directory(p.join(baseDir.path, 'media'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final fileName = ObjStoreKey.generate(filename: filename);
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    final key = p.join('media', fileName).replaceAll('\\', '/');
    final uri = Uri.file(file.path).toString();
    return LocalStoredObject(key: key, uri: uri);
  }

  Future<String?> resolveUri({required String key}) async {
    final baseDir = await _baseDirProvider();
    final safeKey = key.replaceAll('\\', '/');
    final path = p.normalize(p.join(baseDir.path, safeKey));
    final file = File(path);
    if (!file.existsSync()) return null;
    return Uri.file(file.path).toString();
  }
}

class LocalStoredObject {
  final String key;
  final String uri;
  const LocalStoredObject({required this.key, required this.uri});
}

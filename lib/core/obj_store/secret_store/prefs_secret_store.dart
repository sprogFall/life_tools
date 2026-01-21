import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secret_store.dart';

/// 轻量的本地“加解密”存储：
/// - 密钥派生：基于随机 salt（写入 SharedPreferences）+ 固定业务前缀
/// - 加解密：使用 HMAC-SHA256 生成伪随机字节流进行 XOR
///
/// 说明：这是“避免明文落盘”的实现，不等同于安全硬件级别存储。
/// 若后续需要更强的安全性，可替换为平台安全存储（Keychain/Keystore）。
class PrefsSecretStore implements SecretStore {
  static const _saltKey = 'obj_store_secret_salt_v1';

  @override
  Future<void> delete({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_valueKey(key));
  }

  @override
  Future<String?> read({required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_valueKey(key));
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final ciphertext = base64Decode(encoded);
      final plain = await _xor(ciphertext, mode: _CipherMode.decrypt);
      return utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final prefs = await SharedPreferences.getInstance();
    final bytes = utf8.encode(value);
    final cipher = await _xor(bytes, mode: _CipherMode.encrypt);
    await prefs.setString(_valueKey(key), base64Encode(cipher));
  }

  static String _valueKey(String key) => 'obj_store_secret:$key';

  Future<Uint8List> _xor(List<int> input, {required _CipherMode mode}) async {
    final key = await _deriveKey();
    final out = Uint8List(input.length);
    var offset = 0;
    var counter = 0;
    while (offset < input.length) {
      final block = _prf(key, counter);
      final n = min(block.length, input.length - offset);
      for (var i = 0; i < n; i++) {
        out[offset + i] = input[offset + i] ^ block[i];
      }
      offset += n;
      counter++;
    }
    return out;
  }

  Future<Uint8List> _deriveKey() async {
    final prefs = await SharedPreferences.getInstance();
    var salt = prefs.getString(_saltKey);
    if (salt == null || salt.trim().isEmpty) {
      salt = _randomSalt();
      await prefs.setString(_saltKey, salt);
    }
    final bytes = utf8.encode('life_tools_obj_store_v1|$salt');
    return Uint8List.fromList(sha256.convert(bytes).bytes);
  }

  static Uint8List _prf(Uint8List key, int counter) {
    final hmac = Hmac(sha256, key);
    final msg = utf8.encode('ctr:$counter');
    return Uint8List.fromList(hmac.convert(msg).bytes);
  }

  static String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }
}

enum _CipherMode { encrypt, decrypt }


import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'obj_store_config.dart';
import 'obj_store_secrets.dart';
import 'secret_store/secret_store.dart';

class ObjStoreConfigService extends ChangeNotifier {
  static const _storageKey = 'obj_store_config_v1';
  static const _qiniuAccessKey = 'obj_store_qiniu_ak_v1';
  static const _qiniuSecretKey = 'obj_store_qiniu_sk_v1';

  final SecretStore _secretStore;

  SharedPreferences? _prefs;
  ObjStoreConfig? _config;
  ObjStoreQiniuSecrets? _qiniuSecrets;

  ObjStoreConfigService({required SecretStore secretStore})
    : _secretStore = secretStore;

  ObjStoreConfig? get config => _config;

  ObjStoreType get selectedType => _config?.type ?? ObjStoreType.none;

  ObjStoreQiniuSecrets? get qiniuSecrets => _qiniuSecrets;

  bool get isConfigured {
    final cfg = _config;
    if (cfg == null || !cfg.isValid) return false;
    if (cfg.type == ObjStoreType.qiniu) {
      return _qiniuSecrets?.isValid ?? false;
    }
    return true;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _config = ObjStoreConfig.tryFromJsonString(_prefs?.getString(_storageKey));
    await _loadSecrets();
  }

  Future<void> save(
    ObjStoreConfig config, {
    ObjStoreQiniuSecrets? secrets,
    bool allowMissingSecrets = false,
  }) async {
    _config = config;
    await _prefs?.setString(_storageKey, config.toJsonString());

    if (config.type == ObjStoreType.qiniu) {
      if (secrets == null || !secrets.isValid) {
        if (!allowMissingSecrets) {
          throw const FormatException('七牛云存储需要填写 AK/SK');
        }
        _qiniuSecrets = null;
        await _secretStore.delete(key: _qiniuAccessKey);
        await _secretStore.delete(key: _qiniuSecretKey);
      } else {
        _qiniuSecrets = secrets;
        await _secretStore.write(
          key: _qiniuAccessKey,
          value: secrets.accessKey,
        );
        await _secretStore.write(
          key: _qiniuSecretKey,
          value: secrets.secretKey,
        );
      }
    } else {
      _qiniuSecrets = null;
      await _secretStore.delete(key: _qiniuAccessKey);
      await _secretStore.delete(key: _qiniuSecretKey);
    }

    notifyListeners();
  }

  Future<void> clear() async {
    _config = null;
    _qiniuSecrets = null;
    await _prefs?.remove(_storageKey);
    await _secretStore.delete(key: _qiniuAccessKey);
    await _secretStore.delete(key: _qiniuSecretKey);
    notifyListeners();
  }

  Future<void> _loadSecrets() async {
    if (_config?.type != ObjStoreType.qiniu) {
      _qiniuSecrets = null;
      return;
    }
    final ak = await _secretStore.read(key: _qiniuAccessKey);
    final sk = await _secretStore.read(key: _qiniuSecretKey);
    if (ak == null || sk == null || ak.trim().isEmpty || sk.trim().isEmpty) {
      _qiniuSecrets = null;
      return;
    }
    _qiniuSecrets = ObjStoreQiniuSecrets(accessKey: ak, secretKey: sk);
  }
}

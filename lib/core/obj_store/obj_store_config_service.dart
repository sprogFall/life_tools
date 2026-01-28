import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'obj_store_config.dart';
import 'obj_store_secrets.dart';
import 'secret_store/secret_store.dart';

class ObjStoreConfigService extends ChangeNotifier {
  static const _storageKey = 'obj_store_config_v1';
  static const _qiniuAccessKey = 'obj_store_qiniu_ak_v1';
  static const _qiniuSecretKey = 'obj_store_qiniu_sk_v1';
  static const _dataCapsuleAccessKey = 'obj_store_data_capsule_ak_v1';
  static const _dataCapsuleSecretKey = 'obj_store_data_capsule_sk_v1';

  final SecretStore _secretStore;

  SharedPreferences? _prefs;
  ObjStoreConfig? _config;
  ObjStoreQiniuSecrets? _qiniuSecrets;
  ObjStoreDataCapsuleSecrets? _dataCapsuleSecrets;

  ObjStoreConfigService({required SecretStore secretStore})
    : _secretStore = secretStore;

  ObjStoreConfig? get config => _config;

  ObjStoreType get selectedType => _config?.type ?? ObjStoreType.none;

  ObjStoreQiniuSecrets? get qiniuSecrets => _qiniuSecrets;

  ObjStoreDataCapsuleSecrets? get dataCapsuleSecrets => _dataCapsuleSecrets;

  bool get isConfigured {
    final cfg = _config;
    if (cfg == null || !cfg.isValid) return false;
    if (cfg.type == ObjStoreType.qiniu) {
      return _qiniuSecrets?.isValid ?? false;
    }
    if (cfg.type == ObjStoreType.dataCapsule) {
      return _dataCapsuleSecrets?.isValid ?? false;
    }
    return true;
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = ObjStoreConfig.tryFromJsonString(
      _prefs?.getString(_storageKey),
    );
    _config = stored?.normalizedDataCapsuleFixed();
    await _loadSecrets();
  }

  Future<void> save(
    ObjStoreConfig config, {
    ObjStoreQiniuSecrets? secrets,
    ObjStoreDataCapsuleSecrets? dataCapsuleSecrets,
    bool allowMissingSecrets = false,
  }) async {
    final normalized = config.normalizedDataCapsuleFixed();
    _config = normalized;
    await _prefs?.setString(_storageKey, normalized.toJsonString());

    if (normalized.type == ObjStoreType.qiniu) {
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

      _dataCapsuleSecrets = null;
      await _secretStore.delete(key: _dataCapsuleAccessKey);
      await _secretStore.delete(key: _dataCapsuleSecretKey);
    } else if (normalized.type == ObjStoreType.dataCapsule) {
      if (dataCapsuleSecrets == null || !dataCapsuleSecrets.isValid) {
        if (!allowMissingSecrets) {
          throw const FormatException('数据胶囊存储需要填写AK/SK');
        }
        _dataCapsuleSecrets = null;
        await _secretStore.delete(key: _dataCapsuleAccessKey);
        await _secretStore.delete(key: _dataCapsuleSecretKey);
      } else {
        _dataCapsuleSecrets = dataCapsuleSecrets;
        await _secretStore.write(
          key: _dataCapsuleAccessKey,
          value: dataCapsuleSecrets.accessKey,
        );
        await _secretStore.write(
          key: _dataCapsuleSecretKey,
          value: dataCapsuleSecrets.secretKey,
        );
      }

      _qiniuSecrets = null;
      await _secretStore.delete(key: _qiniuAccessKey);
      await _secretStore.delete(key: _qiniuSecretKey);
    } else {
      _qiniuSecrets = null;
      _dataCapsuleSecrets = null;
      await _secretStore.delete(key: _qiniuAccessKey);
      await _secretStore.delete(key: _qiniuSecretKey);
      await _secretStore.delete(key: _dataCapsuleAccessKey);
      await _secretStore.delete(key: _dataCapsuleSecretKey);
    }

    notifyListeners();
  }

  Future<void> clear() async {
    _config = null;
    _qiniuSecrets = null;
    _dataCapsuleSecrets = null;
    await _prefs?.remove(_storageKey);
    await _secretStore.delete(key: _qiniuAccessKey);
    await _secretStore.delete(key: _qiniuSecretKey);
    await _secretStore.delete(key: _dataCapsuleAccessKey);
    await _secretStore.delete(key: _dataCapsuleSecretKey);
    notifyListeners();
  }

  Future<void> _loadSecrets() async {
    final type = _config?.type ?? ObjStoreType.none;

    if (type == ObjStoreType.qiniu) {
      _dataCapsuleSecrets = null;
      final ak = await _secretStore.read(key: _qiniuAccessKey);
      final sk = await _secretStore.read(key: _qiniuSecretKey);
      if (ak == null || sk == null || ak.trim().isEmpty || sk.trim().isEmpty) {
        _qiniuSecrets = null;
        return;
      }
      _qiniuSecrets = ObjStoreQiniuSecrets(accessKey: ak, secretKey: sk);
      return;
    }

    if (type == ObjStoreType.dataCapsule) {
      _qiniuSecrets = null;
      final ak = await _secretStore.read(key: _dataCapsuleAccessKey);
      final sk = await _secretStore.read(key: _dataCapsuleSecretKey);
      if (ak == null || sk == null || ak.trim().isEmpty || sk.trim().isEmpty) {
        _dataCapsuleSecrets = null;
        return;
      }
      _dataCapsuleSecrets = ObjStoreDataCapsuleSecrets(
        accessKey: ak,
        secretKey: sk,
      );
      return;
    }

    _qiniuSecrets = null;
    _dataCapsuleSecrets = null;
  }
}

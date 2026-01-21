import 'dart:typed_data';

import 'obj_store_config.dart';
import 'obj_store_config_service.dart';
import 'obj_store_errors.dart';
import 'obj_store_key.dart';
import 'obj_store_secrets.dart';
import 'qiniu/qiniu_client.dart';
import 'storage/local_obj_store.dart';

class ObjStoreObject {
  final ObjStoreType storageType;
  final String key;
  final String uri;

  const ObjStoreObject({
    required this.storageType,
    required this.key,
    required this.uri,
  });
}

class ObjStoreService {
  final ObjStoreConfigService _configService;
  final LocalObjStore _localStore;
  final QiniuClient _qiniuClient;

  ObjStoreService({
    required ObjStoreConfigService configService,
    required LocalObjStore localStore,
    required QiniuClient qiniuClient,
  }) : _configService = configService,
       _localStore = localStore,
       _qiniuClient = qiniuClient;

  Future<ObjStoreObject> uploadBytes({
    required Uint8List bytes,
    required String filename,
  }) async {
    final cfg = _configService.config;
    if (cfg == null || cfg.type == ObjStoreType.none) {
      throw const ObjStoreNotConfiguredException();
    }

    return uploadBytesWithConfig(
      config: cfg,
      secrets: _configService.qiniuSecrets,
      bytes: bytes,
      filename: filename,
    );
  }

  Future<String> resolveUri({required String key}) async {
    final cfg = _configService.config;
    if (cfg == null || cfg.type == ObjStoreType.none) {
      throw const ObjStoreNotConfiguredException();
    }

    return resolveUriWithConfig(config: cfg, key: key);
  }

  Future<ObjStoreObject> uploadBytesWithConfig({
    required ObjStoreConfig config,
    required Uint8List bytes,
    required String filename,
    ObjStoreQiniuSecrets? secrets,
  }) async {
    switch (config.type) {
      case ObjStoreType.none:
        throw const ObjStoreNotConfiguredException();
      case ObjStoreType.local:
        final stored = await _localStore.saveBytes(bytes: bytes, filename: filename);
        return ObjStoreObject(
          storageType: ObjStoreType.local,
          key: stored.key,
          uri: stored.uri,
        );
      case ObjStoreType.qiniu:
        if (!config.isValid) {
          throw const ObjStoreConfigInvalidException('七牛云配置不完整，请检查 Bucket / 域名 / 上传域名');
        }
        if (secrets == null || !secrets.isValid) {
          throw const ObjStoreNotConfiguredException('请先填写七牛云 AK/SK');
        }
        final key = ObjStoreKey.generate(
          filename: filename,
          prefix: config.keyPrefix ?? '',
        );
        final result = await _qiniuClient.uploadBytes(
          accessKey: secrets.accessKey,
          secretKey: secrets.secretKey,
          bucket: config.bucket!.trim(),
          uploadHost: config.uploadHost!.trim(),
          key: key,
          bytes: bytes,
          filename: filename,
        );
        final url = _qiniuClient.buildPublicUrl(
          domain: config.domain!.trim(),
          key: result.key,
        );
        return ObjStoreObject(
          storageType: ObjStoreType.qiniu,
          key: result.key,
          uri: url,
        );
    }
  }

  Future<String> resolveUriWithConfig({
    required ObjStoreConfig config,
    required String key,
  }) async {
    switch (config.type) {
      case ObjStoreType.none:
        throw const ObjStoreNotConfiguredException();
      case ObjStoreType.local:
        final uri = await _localStore.resolveUri(key: key);
        if (uri == null) {
          throw const ObjStoreQueryException('本地文件不存在或已被清理');
        }
        return uri;
      case ObjStoreType.qiniu:
        if (!config.isValid) {
          throw const ObjStoreConfigInvalidException('七牛云配置不完整，请检查访问域名');
        }
        return _qiniuClient.buildPublicUrl(domain: config.domain!.trim(), key: key);
    }
  }

  Future<bool> probeWithConfig({
    required ObjStoreConfig config,
    required String key,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    switch (config.type) {
      case ObjStoreType.none:
        throw const ObjStoreNotConfiguredException();
      case ObjStoreType.local:
        final uri = await _localStore.resolveUri(key: key);
        return uri != null;
      case ObjStoreType.qiniu:
        final url = _qiniuClient.buildPublicUrl(domain: config.domain!.trim(), key: key);
        return _qiniuClient.probePublicUrl(url: url, timeout: timeout);
    }
  }
}

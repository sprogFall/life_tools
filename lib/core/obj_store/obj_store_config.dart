import 'dart:convert';

enum ObjStoreType { none, local, qiniu, dataCapsule }

class ObjStoreConfig {
  final ObjStoreType type;

  // Qiniu only
  final String? bucket;
  final String? domain;
  final String? uploadHost;
  final String? keyPrefix;
  final bool? qiniuIsPrivate;
  final bool? qiniuUseHttps;

  // DataCapsule (S3 compatible) only
  final String? dataCapsuleBucket;
  final String? dataCapsuleEndpoint;
  final String? dataCapsuleDomain;
  final String? dataCapsuleRegion;
  final String? dataCapsuleKeyPrefix;
  final bool? dataCapsuleIsPrivate;
  final bool? dataCapsuleUseHttps;
  final bool? dataCapsuleForcePathStyle;

  const ObjStoreConfig._({
    required this.type,
    this.bucket,
    this.domain,
    this.uploadHost,
    this.keyPrefix,
    this.qiniuIsPrivate,
    this.qiniuUseHttps,
    this.dataCapsuleBucket,
    this.dataCapsuleEndpoint,
    this.dataCapsuleDomain,
    this.dataCapsuleRegion,
    this.dataCapsuleKeyPrefix,
    this.dataCapsuleIsPrivate,
    this.dataCapsuleUseHttps,
    this.dataCapsuleForcePathStyle,
  });

  const ObjStoreConfig.local() : this._(type: ObjStoreType.local);

  const ObjStoreConfig.qiniu({
    required String bucket,
    required String domain,
    String uploadHost = 'https://upload.qiniup.com',
    String keyPrefix = '',
    bool isPrivate = false,
    bool useHttps = true,
  }) : this._(
         type: ObjStoreType.qiniu,
         bucket: bucket,
         domain: domain,
         uploadHost: uploadHost,
         keyPrefix: keyPrefix,
         qiniuIsPrivate: isPrivate,
         qiniuUseHttps: useHttps,
       );

  const ObjStoreConfig.dataCapsule({
    required String bucket,
    required String endpoint,
    required String region,
    String? domain,
    String keyPrefix = '',
    bool isPrivate = true,
    bool useHttps = true,
    bool forcePathStyle = true,
  }) : this._(
         type: ObjStoreType.dataCapsule,
         dataCapsuleBucket: bucket,
         dataCapsuleEndpoint: endpoint,
         dataCapsuleRegion: region,
         dataCapsuleDomain: domain,
         dataCapsuleKeyPrefix: keyPrefix,
         dataCapsuleIsPrivate: isPrivate,
         dataCapsuleUseHttps: useHttps,
         dataCapsuleForcePathStyle: forcePathStyle,
       );

  bool get isValid {
    switch (type) {
      case ObjStoreType.none:
        return false;
      case ObjStoreType.local:
        return true;
      case ObjStoreType.qiniu:
        return _isNonEmpty(bucket) &&
            _isNonEmpty(domain) &&
            _isNonEmpty(uploadHost);
      case ObjStoreType.dataCapsule:
        return _isNonEmpty(dataCapsuleBucket) &&
            _isNonEmpty(dataCapsuleEndpoint) &&
            _isNonEmpty(dataCapsuleRegion);
    }
  }

  ObjStoreConfig copyWith({
    ObjStoreType? type,
    String? bucket,
    String? domain,
    String? uploadHost,
    String? keyPrefix,
    bool? qiniuIsPrivate,
    bool? qiniuUseHttps,
    String? dataCapsuleBucket,
    String? dataCapsuleEndpoint,
    String? dataCapsuleDomain,
    String? dataCapsuleRegion,
    String? dataCapsuleKeyPrefix,
    bool? dataCapsuleIsPrivate,
    bool? dataCapsuleUseHttps,
    bool? dataCapsuleForcePathStyle,
  }) {
    return ObjStoreConfig._(
      type: type ?? this.type,
      bucket: bucket ?? this.bucket,
      domain: domain ?? this.domain,
      uploadHost: uploadHost ?? this.uploadHost,
      keyPrefix: keyPrefix ?? this.keyPrefix,
      qiniuIsPrivate: qiniuIsPrivate ?? this.qiniuIsPrivate,
      qiniuUseHttps: qiniuUseHttps ?? this.qiniuUseHttps,
      dataCapsuleBucket: dataCapsuleBucket ?? this.dataCapsuleBucket,
      dataCapsuleEndpoint: dataCapsuleEndpoint ?? this.dataCapsuleEndpoint,
      dataCapsuleDomain: dataCapsuleDomain ?? this.dataCapsuleDomain,
      dataCapsuleRegion: dataCapsuleRegion ?? this.dataCapsuleRegion,
      dataCapsuleKeyPrefix: dataCapsuleKeyPrefix ?? this.dataCapsuleKeyPrefix,
      dataCapsuleIsPrivate: dataCapsuleIsPrivate ?? this.dataCapsuleIsPrivate,
      dataCapsuleUseHttps: dataCapsuleUseHttps ?? this.dataCapsuleUseHttps,
      dataCapsuleForcePathStyle:
          dataCapsuleForcePathStyle ?? this.dataCapsuleForcePathStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (bucket != null) 'bucket': bucket,
      if (domain != null) 'domain': domain,
      if (uploadHost != null) 'uploadHost': uploadHost,
      if (keyPrefix != null) 'keyPrefix': keyPrefix,
      if (qiniuIsPrivate != null) 'qiniuIsPrivate': qiniuIsPrivate,
      if (qiniuUseHttps != null) 'qiniuUseHttps': qiniuUseHttps,
      if (dataCapsuleBucket != null) 'dataCapsuleBucket': dataCapsuleBucket,
      if (dataCapsuleEndpoint != null)
        'dataCapsuleEndpoint': dataCapsuleEndpoint,
      if (dataCapsuleDomain != null) 'dataCapsuleDomain': dataCapsuleDomain,
      if (dataCapsuleRegion != null) 'dataCapsuleRegion': dataCapsuleRegion,
      if (dataCapsuleKeyPrefix != null)
        'dataCapsuleKeyPrefix': dataCapsuleKeyPrefix,
      if (dataCapsuleIsPrivate != null)
        'dataCapsuleIsPrivate': dataCapsuleIsPrivate,
      if (dataCapsuleUseHttps != null)
        'dataCapsuleUseHttps': dataCapsuleUseHttps,
      if (dataCapsuleForcePathStyle != null)
        'dataCapsuleForcePathStyle': dataCapsuleForcePathStyle,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static ObjStoreConfig? tryFromJsonString(String? jsonText) {
    if (jsonText == null || jsonText.trim().isEmpty) return null;
    try {
      final map = jsonDecode(jsonText) as Map<String, dynamic>;
      return fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static ObjStoreConfig? fromJson(Map<String, dynamic> map) {
    final typeName = (map['type'] as String?)?.trim();
    if (typeName == null || typeName.isEmpty) return null;

    final type = ObjStoreType.values
        .where((t) => t.name == typeName)
        .firstOrNull;
    if (type == null) return null;

    switch (type) {
      case ObjStoreType.none:
        return null;
      case ObjStoreType.local:
        return const ObjStoreConfig.local();
      case ObjStoreType.qiniu:
        final bucket = (map['bucket'] as String?)?.trim() ?? '';
        final domain = (map['domain'] as String?)?.trim() ?? '';
        final uploadHost =
            (map['uploadHost'] as String?)?.trim() ??
            'https://upload.qiniup.com';
        final keyPrefix = (map['keyPrefix'] as String?)?.trim() ?? '';
        final isPrivate = (map['qiniuIsPrivate'] as bool?) ?? false;
        final useHttps =
            (map['qiniuUseHttps'] as bool?) ?? (!domain.startsWith('http://'));
        return ObjStoreConfig.qiniu(
          bucket: bucket,
          domain: domain,
          uploadHost: uploadHost,
          keyPrefix: keyPrefix,
          isPrivate: isPrivate,
          useHttps: useHttps,
        );
      case ObjStoreType.dataCapsule:
        final bucket = (map['dataCapsuleBucket'] as String?)?.trim() ?? '';
        final endpoint = (map['dataCapsuleEndpoint'] as String?)?.trim() ?? '';
        final region = (map['dataCapsuleRegion'] as String?)?.trim() ?? '';
        final domain = (map['dataCapsuleDomain'] as String?)?.trim();
        final keyPrefix =
            (map['dataCapsuleKeyPrefix'] as String?)?.trim() ?? '';
        final isPrivate = (map['dataCapsuleIsPrivate'] as bool?) ?? true;
        final useHttps =
            (map['dataCapsuleUseHttps'] as bool?) ??
            (!endpoint.startsWith('http://'));
        final forcePathStyle =
            (map['dataCapsuleForcePathStyle'] as bool?) ?? true;
        return ObjStoreConfig.dataCapsule(
          bucket: bucket,
          endpoint: endpoint,
          region: region,
          domain: domain,
          keyPrefix: keyPrefix,
          isPrivate: isPrivate,
          useHttps: useHttps,
          forcePathStyle: forcePathStyle,
        );
    }
  }
}

bool _isNonEmpty(String? v) => v != null && v.trim().isNotEmpty;

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

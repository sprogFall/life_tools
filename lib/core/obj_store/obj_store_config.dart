import 'dart:convert';

enum ObjStoreType { none, local, qiniu }

class ObjStoreConfig {
  final ObjStoreType type;

  // Qiniu only
  final String? bucket;
  final String? domain;
  final String? uploadHost;
  final String? keyPrefix;
  final bool? qiniuIsPrivate;

  const ObjStoreConfig._({
    required this.type,
    this.bucket,
    this.domain,
    this.uploadHost,
    this.keyPrefix,
    this.qiniuIsPrivate,
  });

  const ObjStoreConfig.local() : this._(type: ObjStoreType.local);

  const ObjStoreConfig.qiniu({
    required String bucket,
    required String domain,
    String uploadHost = 'https://upload.qiniup.com',
    String keyPrefix = '',
    bool isPrivate = false,
  }) : this._(
         type: ObjStoreType.qiniu,
         bucket: bucket,
         domain: domain,
         uploadHost: uploadHost,
         keyPrefix: keyPrefix,
         qiniuIsPrivate: isPrivate,
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
    }
  }

  ObjStoreConfig copyWith({
    ObjStoreType? type,
    String? bucket,
    String? domain,
    String? uploadHost,
    String? keyPrefix,
    bool? qiniuIsPrivate,
  }) {
    return ObjStoreConfig._(
      type: type ?? this.type,
      bucket: bucket ?? this.bucket,
      domain: domain ?? this.domain,
      uploadHost: uploadHost ?? this.uploadHost,
      keyPrefix: keyPrefix ?? this.keyPrefix,
      qiniuIsPrivate: qiniuIsPrivate ?? this.qiniuIsPrivate,
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
        return ObjStoreConfig.qiniu(
          bucket: bucket,
          domain: domain,
          uploadHost: uploadHost,
          keyPrefix: keyPrefix,
          isPrivate: isPrivate,
        );
    }
  }
}

bool _isNonEmpty(String? v) => v != null && v.trim().isNotEmpty;

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class ObjStoreQiniuSecrets {
  final String accessKey;
  final String secretKey;

  const ObjStoreQiniuSecrets({
    required this.accessKey,
    required this.secretKey,
  });

  bool get isValid =>
      accessKey.trim().isNotEmpty && secretKey.trim().isNotEmpty;
}

class ObjStoreDataCapsuleSecrets {
  final String accessKey;
  final String secretKey;

  const ObjStoreDataCapsuleSecrets({
    required this.accessKey,
    required this.secretKey,
  });

  bool get isValid =>
      accessKey.trim().isNotEmpty && secretKey.trim().isNotEmpty;
}

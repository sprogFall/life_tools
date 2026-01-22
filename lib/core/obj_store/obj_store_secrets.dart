class ObjStoreQiniuSecrets {
  final String accessKey;
  final String secretKey;

  const ObjStoreQiniuSecrets({required this.accessKey, required this.secretKey});

  bool get isValid => accessKey.trim().isNotEmpty && secretKey.trim().isNotEmpty;
}


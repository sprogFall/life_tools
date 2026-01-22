class ObjStoreNotConfiguredException implements Exception {
  final String message;
  const ObjStoreNotConfiguredException([this.message = '请先在设置中配置【资源存储】信息']);

  @override
  String toString() => 'ObjStoreNotConfiguredException: $message';
}

class ObjStoreConfigInvalidException implements Exception {
  final String message;
  const ObjStoreConfigInvalidException(this.message);

  @override
  String toString() => 'ObjStoreConfigInvalidException: $message';
}

class ObjStoreUploadException implements Exception {
  final String message;
  final int? statusCode;

  const ObjStoreUploadException(this.message, {this.statusCode});

  @override
  String toString() => 'ObjStoreUploadException($statusCode): $message';
}

class ObjStoreQueryException implements Exception {
  final String message;
  final int? statusCode;

  const ObjStoreQueryException(this.message, {this.statusCode});

  @override
  String toString() => 'ObjStoreQueryException($statusCode): $message';
}

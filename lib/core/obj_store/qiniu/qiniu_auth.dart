import 'dart:convert';

import 'package:crypto/crypto.dart';

class QiniuAuth {
  final String accessKey;
  final String secretKey;

  const QiniuAuth({required this.accessKey, required this.secretKey});

  String createUploadToken({
    required String scope,
    required int deadlineUnixSeconds,
  }) {
    final putPolicy = {'scope': scope, 'deadline': deadlineUnixSeconds};
    final putPolicyJson = jsonEncode(putPolicy);
    final encodedPutPolicy = base64Url.encode(utf8.encode(putPolicyJson));

    final hmac = Hmac(sha1, utf8.encode(secretKey));
    final sign = hmac.convert(utf8.encode(encodedPutPolicy)).bytes;
    final encodedSign = base64Url.encode(sign);

    return '$accessKey:$encodedSign:$encodedPutPolicy';
  }
}


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

  /// 生成私有空间下载链接（在原始 URL 后追加 `e` 和 `token`）。
  ///
  /// 规则：token = accessKey + ':' + urlsafe_base64(hmac_sha1(secretKey, urlToSign))
  /// 其中 urlToSign 为：baseUrl + ('?e=' 或 '&e=') + deadline
  String createPrivateDownloadUrl({
    required String baseUrl,
    required int deadlineUnixSeconds,
  }) {
    final separator = baseUrl.contains('?') ? '&' : '?';
    final urlToSign = '$baseUrl${separator}e=$deadlineUnixSeconds';

    final hmac = Hmac(sha1, utf8.encode(secretKey));
    final sign = hmac.convert(utf8.encode(urlToSign)).bytes;
    final encodedSign = base64Url.encode(sign);
    final token = '$accessKey:$encodedSign';

    return '$urlToSign&token=$token';
  }
}

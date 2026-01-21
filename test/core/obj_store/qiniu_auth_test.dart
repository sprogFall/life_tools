import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_auth.dart';

void main() {
  group('QiniuAuth', () {
    test('应按七牛规则生成 uploadToken（HMAC-SHA1 + URLSafeBase64）', () {
      final auth = QiniuAuth(accessKey: 'testak', secretKey: 'testsk');

      final token = auth.createUploadToken(
        scope: 'bucket:key',
        deadlineUnixSeconds: 1234567890,
      );

      expect(
        token,
        'testak:JnHPi-br_pfMIBuF_H4TX_Yc3lc=:eyJzY29wZSI6ImJ1Y2tldDprZXkiLCJkZWFkbGluZSI6MTIzNDU2Nzg5MH0=',
      );
    });
  });
}


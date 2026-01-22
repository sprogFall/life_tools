import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_auth.dart';

void main() {
  group('七牛私有空间下载链接', () {
    test('应生成带 e/token 的私有下载 URL', () {
      final auth = QiniuAuth(accessKey: 'testak', secretKey: 'testsk');

      final url = auth.createPrivateDownloadUrl(
        baseUrl: 'https://cdn.example.com/media/abc.png',
        deadlineUnixSeconds: 1234567890,
      );

      expect(
        url,
        'https://cdn.example.com/media/abc.png?e=1234567890&token=testak:FMNTFUnuG-wbXiPViZ0RjV026sE=',
      );
    });

    test('http 协议也应正确参与签名', () {
      final auth = QiniuAuth(accessKey: 'testak', secretKey: 'testsk');

      final url = auth.createPrivateDownloadUrl(
        baseUrl: 'http://cdn.example.com/media/abc.png',
        deadlineUnixSeconds: 1234567890,
      );

      expect(
        url,
        'http://cdn.example.com/media/abc.png?e=1234567890&token=testak:KEgiWwyKhJjXJNHpXlJP1VMVj7A=',
      );
    });
  });
}

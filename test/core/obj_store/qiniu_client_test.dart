import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_client.dart';

void main() {
  group('QiniuClient.buildPublicUrl', () {
    test('domain 带 http:// 且 useHttps=true 时，应强制输出 https', () {
      final client = QiniuClient();
      final url = client.buildPublicUrl(
        domain: 'http://cdn.example.com',
        key: 'media/abc.png',
        useHttps: true,
      );
      expect(url, 'https://cdn.example.com/media/abc.png');
    });

    test('domain 带 https:// 且 useHttps=false 时，应强制输出 http', () {
      final client = QiniuClient();
      final url = client.buildPublicUrl(
        domain: 'https://cdn.example.com',
        key: 'media/abc.png',
        useHttps: false,
      );
      expect(url, 'http://cdn.example.com/media/abc.png');
    });

    test('key 含中文/空格时，应进行 URL 编码（避免私有链接签名不一致）', () {
      final client = QiniuClient();
      final url = client.buildPublicUrl(
        domain: 'https://cdn.example.com',
        key: '胡闹厨房/a b.png',
        useHttps: true,
      );
      expect(
        url,
        'https://cdn.example.com/%E8%83%A1%E9%97%B9%E5%8E%A8%E6%88%BF/a%20b.png',
      );
    });

    test('domain 带 path 时，应正确拼接 pathSegments', () {
      final client = QiniuClient();
      final url = client.buildPublicUrl(
        domain: 'https://cdn.example.com/base/path/',
        key: 'media/abc.png',
        useHttps: true,
      );
      expect(url, 'https://cdn.example.com/base/path/media/abc.png');
    });
  });
}


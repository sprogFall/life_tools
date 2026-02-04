import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/performance/display_refresh_rate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DisplayRefreshRateService', () {
    const channel = MethodChannel('life_tools/display');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('应透传 90Hz 请求', () async {
      MethodCall? recordedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        recordedCall = call;
        return true;
      });

      final service = DisplayRefreshRateService();
      final ok = await service.tryRequestPreferredHz(90);

      expect(ok, isTrue);
      expect(recordedCall?.method, 'requestFrameRate');
      final args = recordedCall?.arguments;
      expect(args, isA<Map<dynamic, dynamic>>());
      expect((args as Map<dynamic, dynamic>)['hz'], 90.0);
    });

    test('平台异常时应返回 false', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'unavailable');
      });

      final service = DisplayRefreshRateService();
      final ok = await service.tryRequestPreferredHz(90);

      expect(ok, isFalse);
    });
  });
}

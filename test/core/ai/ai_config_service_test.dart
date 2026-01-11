import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiConfigService', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('首次初始化时应为未配置', () async {
      final service = AiConfigService();
      await service.init();

      expect(service.config, isNull);
      expect(service.isConfigured, isFalse);
    });

    test('保存后应可读取到配置', () async {
      final service = AiConfigService();
      await service.init();

      const config = AiConfig(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        model: 'gpt-4o-mini',
        temperature: 0.2,
        maxOutputTokens: 512,
      );

      await service.save(config);

      expect(service.isConfigured, isTrue);
      expect(service.config, isNotNull);
      expect(service.config!.baseUrl, config.baseUrl);
      expect(service.config!.apiKey, config.apiKey);
      expect(service.config!.model, config.model);
      expect(service.config!.temperature, config.temperature);
      expect(service.config!.maxOutputTokens, config.maxOutputTokens);
    });

    test('清空后应变为未配置', () async {
      final service = AiConfigService();
      await service.init();

      const config = AiConfig(
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'test-key',
        model: 'gpt-4o-mini',
        temperature: 0.2,
        maxOutputTokens: 512,
      );
      await service.save(config);

      await service.clear();
      expect(service.isConfigured, isFalse);
      expect(service.config, isNull);
    });
  });
}

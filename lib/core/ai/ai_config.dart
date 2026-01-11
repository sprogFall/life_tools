import 'dart:convert';

class AiConfig {
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final int maxOutputTokens;

  const AiConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.temperature,
    required this.maxOutputTokens,
  });

  bool get isValid =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      temperature.isFinite &&
      temperature >= 0 &&
      temperature <= 2 &&
      maxOutputTokens > 0;

  Map<String, dynamic> toMap() => {
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
        'maxOutputTokens': maxOutputTokens,
      };

  static AiConfig fromMap(Map<String, dynamic> map) {
    return AiConfig(
      baseUrl: (map['baseUrl'] as String?) ?? '',
      apiKey: (map['apiKey'] as String?) ?? '',
      model: (map['model'] as String?) ?? '',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      maxOutputTokens: (map['maxOutputTokens'] as num?)?.toInt() ?? 1024,
    );
  }

  String toJsonString() => jsonEncode(toMap());

  static AiConfig? tryFromJsonString(String? json) {
    if (json == null || json.trim().isEmpty) return null;
    final map = jsonDecode(json) as Map<String, dynamic>;
    return fromMap(map);
  }
}

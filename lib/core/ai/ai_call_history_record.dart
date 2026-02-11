import 'ai_call_source.dart';

class AiCallHistoryRecord {
  final String id;
  final AiCallSource source;
  final String model;
  final String prompt;
  final String response;
  final DateTime createdAt;

  const AiCallHistoryRecord({
    required this.id,
    required this.source,
    required this.model,
    required this.prompt,
    required this.response,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'source': source.toMap(),
    'model': model,
    'prompt': prompt,
    'response': response,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  static AiCallHistoryRecord fromMap(Map<String, dynamic> map) {
    final sourceMap = map['source'];
    final parsedSource = sourceMap is Map<String, dynamic>
        ? sourceMap
        : sourceMap is Map
        ? sourceMap.cast<String, dynamic>()
        : const <String, dynamic>{};

    return AiCallHistoryRecord(
      id: ((map['id'] as String?)?.trim().isNotEmpty ?? false)
          ? (map['id'] as String)
          : '${DateTime.now().microsecondsSinceEpoch}',
      source: AiCallSource.fromMap(parsedSource),
      model: (map['model'] as String?) ?? '',
      prompt: (map['prompt'] as String?) ?? '',
      response: (map['response'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['createdAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

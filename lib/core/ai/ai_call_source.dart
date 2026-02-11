class AiCallSource {
  final String toolId;
  final String toolName;
  final String featureId;
  final String featureName;

  const AiCallSource({
    required this.toolId,
    required this.toolName,
    required this.featureId,
    required this.featureName,
  });

  static const AiCallSource unknown = AiCallSource(
    toolId: 'unknown',
    toolName: '未知工具',
    featureId: 'unknown',
    featureName: '未知功能',
  );

  Map<String, dynamic> toMap() => {
    'toolId': toolId,
    'toolName': toolName,
    'featureId': featureId,
    'featureName': featureName,
  };

  static AiCallSource fromMap(Map<String, dynamic> map) {
    final toolId = (map['toolId'] as String?)?.trim() ?? '';
    final toolName = (map['toolName'] as String?)?.trim() ?? '';
    final featureId = (map['featureId'] as String?)?.trim() ?? '';
    final featureName = (map['featureName'] as String?)?.trim() ?? '';

    if (toolId.isEmpty ||
        toolName.isEmpty ||
        featureId.isEmpty ||
        featureName.isEmpty) {
      return unknown;
    }

    return AiCallSource(
      toolId: toolId,
      toolName: toolName,
      featureId: featureId,
      featureName: featureName,
    );
  }
}

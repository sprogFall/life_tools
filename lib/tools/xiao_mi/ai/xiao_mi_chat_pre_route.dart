import '../../../core/ai/ai_json_utils.dart';

sealed class XiaoMiPreRouteDecision {
  final String reasoning;

  const XiaoMiPreRouteDecision({this.reasoning = ''});
}

class XiaoMiPreRouteDirectAnswer extends XiaoMiPreRouteDecision {
  final String answer;

  const XiaoMiPreRouteDirectAnswer({required this.answer, super.reasoning});
}

class XiaoMiPreRouteSpecialCall extends XiaoMiPreRouteDecision {
  final String callId;
  final Map<String, Object?> arguments;

  const XiaoMiPreRouteSpecialCall({
    required this.callId,
    this.arguments = const <String, Object?>{},
    super.reasoning,
  });
}

class XiaoMiPreRouteParser {
  static XiaoMiPreRouteDecision parse({
    required String modelText,
    String reasoning = '',
  }) {
    final text = modelText.trim();
    final map = AiJsonUtils.decodeFirstObject(text);
    if (map == null) {
      return XiaoMiPreRouteDirectAnswer(answer: text, reasoning: reasoning);
    }

    final type = AiJsonUtils.asString(map['type'])?.trim().toLowerCase();
    if (type != 'special_call') {
      return XiaoMiPreRouteDirectAnswer(answer: text, reasoning: reasoning);
    }

    final callId = AiJsonUtils.asString(map['call'])?.trim();
    if (callId == null || callId.isEmpty) {
      return XiaoMiPreRouteDirectAnswer(answer: text, reasoning: reasoning);
    }

    return XiaoMiPreRouteSpecialCall(
      callId: callId,
      arguments:
          AiJsonUtils.asMap(map['arguments']) ?? const <String, Object?>{},
      reasoning: reasoning,
    );
  }
}

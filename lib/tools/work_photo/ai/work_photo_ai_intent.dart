import '../../../core/ai/ai_json_utils.dart';

sealed class WorkPhotoAiIntent {
  const WorkPhotoAiIntent();
}

class WorkPhotoAiUnknownIntent extends WorkPhotoAiIntent {
  final String reason;
  final Map<String, Object?>? raw;

  const WorkPhotoAiUnknownIntent({required this.reason, this.raw});
}

enum WorkPhotoAiNodeKind { level, item }

class WorkPhotoAiTemplateNode {
  final WorkPhotoAiNodeKind kind;
  final String name;
  final bool isRequired;
  final int minCount;
  final int? maxCount;
  final List<WorkPhotoAiTemplateNode> children;

  const WorkPhotoAiTemplateNode({
    required this.kind,
    required this.name,
    this.isRequired = true,
    this.minCount = 1,
    this.maxCount,
    this.children = const [],
  });

  bool get isLevel => kind == WorkPhotoAiNodeKind.level;
  bool get isItem => kind == WorkPhotoAiNodeKind.item;
}

class WorkPhotoAiReplaceTemplateTreeIntent extends WorkPhotoAiIntent {
  final List<WorkPhotoAiTemplateNode> nodes;

  const WorkPhotoAiReplaceTemplateTreeIntent({required this.nodes});
}

class WorkPhotoAiIntentParser {
  static WorkPhotoAiIntent parse(String text) {
    final map = AiJsonUtils.decodeFirstObject(text);
    if (map == null) {
      return const WorkPhotoAiUnknownIntent(reason: '无法解析 JSON');
    }

    final type = AiJsonUtils.asString(map['type'])?.trim();
    if (type == null || type.isEmpty) {
      return WorkPhotoAiUnknownIntent(reason: '缺少 type 字段', raw: map);
    }
    if (type != 'replace_template_tree') {
      return WorkPhotoAiUnknownIntent(reason: '不支持的 type: $type', raw: map);
    }

    final nodesRaw = AiJsonUtils.asList(map['nodes']);
    if (nodesRaw == null) {
      return WorkPhotoAiUnknownIntent(
        reason: 'replace_template_tree 缺少 nodes 数组',
        raw: map,
      );
    }

    final nodes = <WorkPhotoAiTemplateNode>[];
    for (var i = 0; i < nodesRaw.length; i++) {
      final parsed = _parseNode(nodesRaw[i], path: 'nodes[$i]', raw: map);
      if (parsed.error != null) {
        return WorkPhotoAiUnknownIntent(reason: parsed.error!, raw: map);
      }
      nodes.add(parsed.node!);
    }

    if (nodes.isEmpty) {
      return WorkPhotoAiUnknownIntent(
        reason: 'replace_template_tree.nodes 不能为空',
        raw: map,
      );
    }

    return WorkPhotoAiReplaceTemplateTreeIntent(nodes: nodes);
  }

  static ({WorkPhotoAiTemplateNode? node, String? error}) _parseNode(
    Object? value, {
    required String path,
    required Map<String, Object?> raw,
  }) {
    final map = AiJsonUtils.asMap(value);
    if (map == null) {
      return (node: null, error: '$path 不是对象');
    }

    final kindRaw = AiJsonUtils.asString(map['kind'])?.trim().toLowerCase();
    if (kindRaw != 'level' && kindRaw != 'item') {
      return (node: null, error: '$path.kind 必须是 level 或 item');
    }
    final kind = kindRaw == 'level'
        ? WorkPhotoAiNodeKind.level
        : WorkPhotoAiNodeKind.item;

    final name = AiJsonUtils.asString(map['name'])?.trim() ?? '';
    if (name.isEmpty) {
      return (node: null, error: '$path.name 不能为空');
    }

    if (kind == WorkPhotoAiNodeKind.item) {
      final minCount = AiJsonUtils.asInt(map['min_count']) ?? 1;
      if (minCount < 0) {
        return (node: null, error: '$path.min_count 不能小于 0');
      }
      final hasMaxKey = map.containsKey('max_count');
      final maxCount = hasMaxKey ? AiJsonUtils.asInt(map['max_count']) : null;
      if (hasMaxKey && map['max_count'] != null && maxCount == null) {
        return (node: null, error: '$path.max_count 不是有效整数');
      }
      if (maxCount != null && maxCount < minCount) {
        return (node: null, error: '$path.max_count 不能小于 min_count');
      }
      if (AiJsonUtils.asList(map['children'])?.isNotEmpty == true) {
        return (node: null, error: '$path 是 item，不能包含 children');
      }
      return (
        node: WorkPhotoAiTemplateNode(
          kind: kind,
          name: name,
          minCount: minCount,
          maxCount: maxCount,
        ),
        error: null,
      );
    }

    final isRequired = _asBool(map['is_required']) ?? true;
    final childrenRaw = AiJsonUtils.asList(map['children']) ?? const [];
    final children = <WorkPhotoAiTemplateNode>[];
    for (var i = 0; i < childrenRaw.length; i++) {
      final child = _parseNode(
        childrenRaw[i],
        path: '$path.children[$i]',
        raw: raw,
      );
      if (child.error != null) {
        return (node: null, error: child.error);
      }
      children.add(child.node!);
    }

    return (
      node: WorkPhotoAiTemplateNode(
        kind: kind,
        name: name,
        isRequired: isRequired,
        children: children,
      ),
      error: null,
    );
  }

  static bool? _asBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }
}

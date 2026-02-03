// 标签相关业务异常（用于向 UI 提供更友好的提示）

/// 同工具 + 同分类下出现同名标签
class TagNameConflictException implements Exception {
  final String toolId;
  final String categoryId;
  final String name;

  const TagNameConflictException({
    required this.toolId,
    required this.categoryId,
    required this.name,
  });

  @override
  String toString() {
    final n = name.trim();
    if (n.isEmpty) return '已存在同名标签，请换个名字';
    return '已存在同名标签「$n」，请换个名字';
  }
}

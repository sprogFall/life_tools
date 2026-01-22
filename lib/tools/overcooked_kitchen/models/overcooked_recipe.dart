import 'dart:convert';

class OvercookedRecipe {
  final int? id;
  final String name;
  final String? coverImageKey;
  final int? typeTagId;
  final List<int> ingredientTagIds;
  final List<int> sauceTagIds;
  final List<int> flavorTagIds;
  final String intro;
  final String content;
  final List<String> detailImageKeys;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OvercookedRecipe({
    required this.id,
    required this.name,
    required this.coverImageKey,
    required this.typeTagId,
    required this.ingredientTagIds,
    required this.sauceTagIds,
    required this.flavorTagIds,
    required this.intro,
    required this.content,
    required this.detailImageKeys,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OvercookedRecipe.create({
    required String name,
    required String? coverImageKey,
    required int? typeTagId,
    required List<int> ingredientTagIds,
    required List<int> sauceTagIds,
    required List<int> flavorTagIds,
    required String intro,
    required String content,
    required List<String> detailImageKeys,
    required DateTime now,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createRecipe 需要 name');
    }
    return OvercookedRecipe(
      id: null,
      name: trimmed,
      coverImageKey: coverImageKey?.trim().isEmpty ?? true
          ? null
          : coverImageKey!.trim(),
      typeTagId: typeTagId,
      ingredientTagIds: List<int>.unmodifiable(ingredientTagIds),
      sauceTagIds: List<int>.unmodifiable(sauceTagIds),
      flavorTagIds: List<int>.unmodifiable(flavorTagIds),
      intro: intro.trim(),
      content: content.trim(),
      detailImageKeys: List<String>.unmodifiable(detailImageKeys),
      createdAt: now,
      updatedAt: now,
    );
  }

  OvercookedRecipe copyWith({
    int? id,
    String? name,
    String? coverImageKey,
    int? typeTagId,
    List<int>? ingredientTagIds,
    List<int>? sauceTagIds,
    List<int>? flavorTagIds,
    String? intro,
    String? content,
    List<String>? detailImageKeys,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OvercookedRecipe(
      id: id ?? this.id,
      name: name ?? this.name,
      coverImageKey: coverImageKey ?? this.coverImageKey,
      typeTagId: typeTagId ?? this.typeTagId,
      ingredientTagIds:
          ingredientTagIds ?? List<int>.unmodifiable(this.ingredientTagIds),
      sauceTagIds: sauceTagIds ?? List<int>.unmodifiable(this.sauceTagIds),
      flavorTagIds: flavorTagIds ?? List<int>.unmodifiable(this.flavorTagIds),
      intro: intro ?? this.intro,
      content: content ?? this.content,
      detailImageKeys:
          detailImageKeys ?? List<String>.unmodifiable(this.detailImageKeys),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static OvercookedRecipe fromRow(
    Map<String, Object?> row, {
    required List<int> ingredientTagIds,
    required List<int> sauceTagIds,
    required List<int> flavorTagIds,
  }) {
    final rawKeys = row['detail_image_keys'] as String? ?? '[]';
    List<String> keys;
    try {
      final decoded = jsonDecode(rawKeys);
      keys = decoded is List
          ? decoded.whereType<String>().toList()
          : const <String>[];
    } catch (_) {
      keys = const <String>[];
    }
    return OvercookedRecipe(
      id: row['id'] as int?,
      name: row['name'] as String? ?? '',
      coverImageKey: row['cover_image_key'] as String?,
      typeTagId: row['type_tag_id'] as int?,
      ingredientTagIds: List<int>.unmodifiable(ingredientTagIds),
      sauceTagIds: List<int>.unmodifiable(sauceTagIds),
      flavorTagIds: List<int>.unmodifiable(flavorTagIds),
      intro: row['intro'] as String? ?? '',
      content: row['content'] as String? ?? '',
      detailImageKeys: List<String>.unmodifiable(keys),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as int?) ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (row['updated_at'] as int?) ?? 0,
      ),
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name.trim(),
      'cover_image_key': coverImageKey,
      'type_tag_id': typeTagId,
      'intro': intro.trim(),
      'content': content.trim(),
      'detail_image_keys': jsonEncode(detailImageKeys),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_service.dart';
import '../stockpile_constants.dart';

class StockpileTagUtils {
  StockpileTagUtils._();

  static String? createHint(BuildContext context, String categoryId) {
    final normalized = categoryId.trim();
    if (normalized.isEmpty) return null;
    final categories = context.read<TagService>().categoriesForTool(
      StockpileConstants.toolId,
    );
    for (final c in categories) {
      if (c.id == normalized) return c.createHint;
    }
    return null;
  }

  static Future<Tag> createTag(
    BuildContext context, {
    required String categoryId,
    required String name,
  }) async {
    final normalizedCategoryId = categoryId.trim();
    final normalizedName = name.trim();
    if (normalizedCategoryId.isEmpty) {
      throw ArgumentError('categoryId 不能为空');
    }
    if (normalizedName.isEmpty) {
      throw ArgumentError('name 不能为空');
    }

    final service = context.read<TagService>();
    final id = await service.createTagForToolCategory(
      toolId: StockpileConstants.toolId,
      categoryId: normalizedCategoryId,
      name: normalizedName,
      refreshCache: false,
    );
    final now = DateTime.now();
    return Tag(
      id: id,
      name: normalizedName,
      color: null,
      sortIndex: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  static ({List<Tag> itemTypes, Tag? location}) splitItemTags({
    required List<Tag> tags,
    required Map<int, String> categoryByTagId,
  }) {
    Tag? location;
    final itemTypes = <Tag>[];
    for (final t in tags) {
      final id = t.id;
      final category = id == null ? null : categoryByTagId[id];
      if (category == StockpileTagCategories.location && location == null) {
        location = t;
      } else {
        itemTypes.add(t);
      }
    }
    return (itemTypes: itemTypes, location: location);
  }
}

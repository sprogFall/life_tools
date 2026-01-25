import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_service.dart';
import '../overcooked_constants.dart';

class OvercookedFormat {
  static String date(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String yearMonth(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$y-$m';
  }
}

class OvercookedDialogs {
  static Future<void> showMessage(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(content),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '确认',
    String cancelText = '取消',
    bool isDestructive = false,
  }) async {
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(content),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class OvercookedTagUtils {
  static String? createHint(BuildContext context, String categoryId) {
    final normalized = categoryId.trim();
    if (normalized.isEmpty) return null;
    final categories = context.read<TagService>().categoriesForTool(
      OvercookedConstants.toolId,
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
      toolId: OvercookedConstants.toolId,
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
}

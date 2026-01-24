import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/obj_store/obj_store_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../models/overcooked_recipe.dart';
import '../repository/overcooked_repository.dart';
import 'overcooked_image.dart';

enum _SortMode { none, ratingDesc }

class OvercookedRecipePickerSheet extends StatefulWidget {
  final String title;
  final List<OvercookedRecipe> recipes;
  final Set<int> selectedRecipeIds;

  const OvercookedRecipePickerSheet({
    super.key,
    required this.title,
    required this.recipes,
    required this.selectedRecipeIds,
  });

  static Future<Set<int>?> show(
    BuildContext context, {
    required String title,
    required List<OvercookedRecipe> recipes,
    required Set<int> selectedRecipeIds,
  }) {
    return showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: IOS26Theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: OvercookedRecipePickerSheet(
          title: title,
          recipes: recipes,
          selectedRecipeIds: selectedRecipeIds,
        ),
      ),
    );
  }

  @override
  State<OvercookedRecipePickerSheet> createState() =>
      _OvercookedRecipePickerSheetState();
}

class _OvercookedRecipePickerSheetState
    extends State<OvercookedRecipePickerSheet> {
  late Set<int> _selected;
  String _query = '';
  _SortMode _sortMode = _SortMode.none;
  Map<int, ({int cookCount, double avgRating, int ratingCount})> _statsById =
      const {};
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.selectedRecipeIds);
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _loadingStats = true);
    try {
      final repo = context.read<OvercookedRepository>();
      final stats = await repo.getRecipeStats();
      if (mounted) setState(() => _statsById = stats);
    } catch (_) {
      // 忽略数据库关闭等异常
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  List<OvercookedRecipe> _getFilteredAndSorted() {
    final q = _query.trim().toLowerCase();
    var list = q.isEmpty
        ? widget.recipes
        : widget.recipes
              .where((r) => r.name.toLowerCase().contains(q))
              .toList();

    if (_sortMode == _SortMode.ratingDesc) {
      list = List.from(list)
        ..sort((a, b) {
          final aRating = _statsById[a.id]?.avgRating ?? 0.0;
          final bRating = _statsById[b.id]?.avgRating ?? 0.0;
          return bRating.compareTo(aRating);
        });
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredAndSorted();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.80,
      child: Column(
        children: [
          _header(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: CupertinoSearchTextField(
                    placeholder: '搜索菜谱',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  color: _sortMode == _SortMode.ratingDesc
                      ? IOS26Theme.primaryColor
                      : IOS26Theme.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                  onPressed: _loadingStats
                      ? null
                      : () {
                          setState(() {
                            _sortMode = _sortMode == _SortMode.ratingDesc
                                ? _SortMode.none
                                : _SortMode.ratingDesc;
                          });
                        },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.star_fill,
                        size: 14,
                        color: _sortMode == _SortMode.ratingDesc
                            ? Colors.white
                            : IOS26Theme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '评分',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _sortMode == _SortMode.ratingDesc
                              ? Colors.white
                              : IOS26Theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '暂无可选菜谱',
                      style: TextStyle(color: IOS26Theme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, index) => Divider(
                      height: 1,
                      color: IOS26Theme.textTertiary.withValues(alpha: 0.25),
                    ),
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      final id = r.id;
                      final checked = id != null && _selected.contains(id);
                      final stats = id != null ? _statsById[id] : null;
                      final avgRating = stats?.avgRating ?? 0.0;
                      final ratingCount = stats?.ratingCount ?? 0;

                      return ListTile(
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: OvercookedImageByKey(
                            objStoreService: context.read<ObjStoreService>(),
                            objectKey: r.coverImageKey,
                            borderRadius: 12,
                          ),
                        ),
                        title: Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: IOS26Theme.textPrimary,
                          ),
                        ),
                        subtitle: ratingCount > 0
                            ? Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.star_fill,
                                    size: 12,
                                    color: IOS26Theme.toolOrange,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    avgRating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: IOS26Theme.toolOrange,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                        trailing: CupertinoSwitch(
                          value: checked,
                          onChanged: id == null
                              ? null
                              : (value) => setState(() {
                                  if (value) {
                                    _selected.add(id);
                                  } else {
                                    _selected.remove(id);
                                  }
                                }),
                        ),
                        onTap: id == null
                            ? null
                            : () => setState(() {
                                if (checked) {
                                  _selected.remove(id);
                                } else {
                                  _selected.add(id);
                                }
                              }),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          CupertinoButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          Expanded(
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: IOS26Theme.textPrimary,
              ),
            ),
          ),
          CupertinoButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

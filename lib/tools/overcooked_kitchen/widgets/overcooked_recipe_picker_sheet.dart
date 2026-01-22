import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/obj_store/obj_store_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../models/overcooked_recipe.dart';
import 'overcooked_image.dart';

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

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.selectedRecipeIds);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.recipes
        : widget.recipes
              .where((r) => r.name.toLowerCase().contains(q))
              .toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.80,
      child: Column(
        children: [
          _header(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: CupertinoSearchTextField(
              placeholder: '搜索菜谱',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
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

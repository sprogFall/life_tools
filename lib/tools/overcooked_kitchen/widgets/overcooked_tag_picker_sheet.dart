import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/theme/ios26_theme.dart';

class OvercookedTagPickerSheet extends StatefulWidget {
  final String title;
  final List<Tag> tags;
  final Set<int> selectedIds;
  final bool multi;

  const OvercookedTagPickerSheet({
    super.key,
    required this.title,
    required this.tags,
    required this.selectedIds,
    required this.multi,
  });

  static Future<Set<int>?> show(
    BuildContext context, {
    required String title,
    required List<Tag> tags,
    required Set<int> selectedIds,
    required bool multi,
  }) {
    return showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: IOS26Theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: OvercookedTagPickerSheet(
          title: title,
          tags: tags,
          selectedIds: selectedIds,
          multi: multi,
        ),
      ),
    );
  }

  @override
  State<OvercookedTagPickerSheet> createState() =>
      _OvercookedTagPickerSheetState();
}

class _OvercookedTagPickerSheetState extends State<OvercookedTagPickerSheet> {
  late Set<int> _selected;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.tags.where((t) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q);
    }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          _buildHeader(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: CupertinoSearchTextField(
              placeholder: '搜索标签',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '暂无可选标签',
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
                      final tag = filtered[index];
                      final id = tag.id;
                      final checked = id != null && _selected.contains(id);
                      return ListTile(
                        title: Text(
                          tag.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: IOS26Theme.textPrimary,
                          ),
                        ),
                        trailing: widget.multi
                            ? CupertinoSwitch(
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
                              )
                            : checked
                            ? const Icon(
                                CupertinoIcons.check_mark_circled_solid,
                                color: IOS26Theme.primaryColor,
                              )
                            : const SizedBox.shrink(),
                        onTap: id == null
                            ? null
                            : () {
                                setState(() {
                                  if (widget.multi) {
                                    if (checked) {
                                      _selected.remove(id);
                                    } else {
                                      _selected.add(id);
                                    }
                                  } else {
                                    _selected = {id};
                                  }
                                });
                                if (!widget.multi) {
                                  Navigator.pop(context, _selected);
                                }
                              },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                fontWeight: FontWeight.w700,
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

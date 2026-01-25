import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/tags/models/tag.dart';
import '../../../core/theme/ios26_theme.dart';

class OvercookedTagPickerResult {
  final Set<int> selectedIds;
  final bool tagsChanged;

  const OvercookedTagPickerResult({
    required this.selectedIds,
    required this.tagsChanged,
  });
}

class OvercookedTagPickerSheet extends StatefulWidget {
  final String title;
  final List<Tag> tags;
  final Set<int> selectedIds;
  final bool multi;
  final String? createHint;
  final Future<Tag> Function(String name)? onCreateTag;

  const OvercookedTagPickerSheet({
    super.key,
    required this.title,
    required this.tags,
    required this.selectedIds,
    required this.multi,
    this.createHint,
    this.onCreateTag,
  });

  static Future<OvercookedTagPickerResult?> show(
    BuildContext context, {
    required String title,
    required List<Tag> tags,
    required Set<int> selectedIds,
    required bool multi,
    String? createHint,
    Future<Tag> Function(String name)? onCreateTag,
  }) {
    return showModalBottomSheet<OvercookedTagPickerResult>(
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
          createHint: createHint,
          onCreateTag: onCreateTag,
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
  late List<Tag> _tags;
  final _searchController = TextEditingController();
  final _quickAddController = TextEditingController();
  final _quickAddFocusNode = FocusNode();
  String _query = '';
  bool _creating = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.selectedIds);
    _tags = widget.tags;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quickAddController.dispose();
    _quickAddFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _tags.where((t) {
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
              controller: _searchController,
              placeholder: '搜索标签',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '暂无可选标签',
                          style: TextStyle(color: IOS26Theme.textSecondary),
                        ),
                        if (_canCreate) ...[
                          const SizedBox(height: 12),
                          IOS26QuickAddChip(
                            fieldKey: const ValueKey(
                              'overcooked-tag-quick-add-field',
                            ),
                            buttonKey: const ValueKey(
                              'overcooked-tag-quick-add-button',
                            ),
                            controller: _quickAddController,
                            focusNode: _quickAddFocusNode,
                            placeholder: _quickAddPlaceholder,
                            loading: _creating,
                            onAdd: _createFromInline,
                          ),
                        ],
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in filtered)
                          _TagSelectChip(
                            key: tag.id == null
                                ? null
                                : ValueKey('overcooked-tag-${tag.id}'),
                            text: tag.name,
                            selected:
                                tag.id != null && _selected.contains(tag.id),
                            onPressed: tag.id == null
                                ? null
                                : () => _toggle(tag.id!),
                          ),
                        if (_canCreate)
                          IOS26QuickAddChip(
                            fieldKey: const ValueKey(
                              'overcooked-tag-quick-add-field',
                            ),
                            buttonKey: const ValueKey(
                              'overcooked-tag-quick-add-button',
                            ),
                            controller: _quickAddController,
                            focusNode: _quickAddFocusNode,
                            placeholder: _quickAddPlaceholder,
                            loading: _creating,
                            onAdd: _createFromInline,
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool get _canCreate {
    return widget.onCreateTag != null;
  }

  String get _quickAddPlaceholder {
    final hint = widget.createHint?.trim();
    if (hint != null && hint.isNotEmpty) return '如：$hint';
    return '输入标签名';
  }

  void _toggle(int id) {
    final checked = _selected.contains(id);
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
      Navigator.pop(
        context,
        OvercookedTagPickerResult(
          selectedIds: _selected,
          tagsChanged: _changed,
        ),
      );
    }
  }

  Future<void> _createFromInline() async {
    if (!_canCreate || _creating) return;
    final name = _quickAddController.text.trim();
    if (name.isEmpty) {
      _quickAddFocusNode.requestFocus();
      return;
    }
    final exists = _tags.any((t) => t.name.trim() == name);
    if (exists) {
      _quickAddController.clear();
      _quickAddFocusNode.requestFocus();
      return;
    }

    setState(() => _creating = true);
    try {
      final created = await widget.onCreateTag!.call(name);
      final id = created.id;
      if (id == null) {
        throw StateError('新增标签失败：未返回 id');
      }
      if (!mounted) return;

      final next = [..._tags.where((t) => t.id != id), created]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _tags = next;
        _changed = true;
        _query = '';
        _searchController.clear();
        _quickAddController.clear();
        if (widget.multi) {
          _selected.add(id);
        } else {
          _selected = {id};
        }
      });
      if (!widget.multi) {
        if (!mounted) return;
        Navigator.pop(
          context,
          OvercookedTagPickerResult(
            selectedIds: _selected,
            tagsChanged: _changed,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await showCupertinoDialog<void>(
        context: context,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('新增失败'),
          content: Text(e.toString()),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
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
            key: const ValueKey('overcooked-tag-done'),
            onPressed: () => Navigator.pop(
              context,
              OvercookedTagPickerResult(
                selectedIds: _selected,
                tagsChanged: _changed,
              ),
            ),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

class _TagSelectChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onPressed;

  const _TagSelectChip({
    super.key,
    required this.text,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? IOS26Theme.primaryColor.withValues(alpha: 0.14)
        : IOS26Theme.surfaceColor.withValues(alpha: 0.65);
    final border = selected
        ? IOS26Theme.primaryColor.withValues(alpha: 0.35)
        : IOS26Theme.textTertiary.withValues(alpha: 0.35);
    final fg = selected ? IOS26Theme.primaryColor : IOS26Theme.textPrimary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(44, 44),
        pressedOpacity: 0.7,
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../services/tag_service.dart';
import '../models/tag_model.dart';
import '../../theme/ios26_theme.dart';

class TagSelectorWidget extends StatefulWidget {
  final String toolId;
  final List<int> initialTagIds;
  final void Function(List<int> selectedTagIds) onTagsChanged;
  final bool allowCreateNew;

  const TagSelectorWidget({
    super.key,
    required this.toolId,
    required this.initialTagIds,
    required this.onTagsChanged,
    this.allowCreateNew = true,
  });

  @override
  State<TagSelectorWidget> createState() => _TagSelectorWidgetState();
}

class _TagSelectorWidgetState extends State<TagSelectorWidget> {
  late TagService _tagService;
  List<Tag> _allAvailableTags = [];
  List<int> _selectedTagIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tagService = TagService();
    _selectedTagIds = List.from(widget.initialTagIds);
    _loadAvailableTags();
  }

  Future<void> _loadAvailableTags() async {
    try {
      final tags = await _tagService.getAvailableTags(widget.toolId);
      setState(() {
        _allAvailableTags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

    void _toggleTag(Tag tag) {
    setState(() {
      if (_selectedTagIds.contains(tag.id!)) {
        _selectedTagIds.remove(tag.id!);
      } else {
        _selectedTagIds.add(tag.id!);
      }
      widget.onTagsChanged(_selectedTagIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (_allAvailableTags.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(CupertinoIcons.tag, color: IOS26Theme.textTertiary),
            const SizedBox(width: 8),
            Text(
              '该工具暂无可用标签',
              style: TextStyle(color: IOS26Theme.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allAvailableTags.map((tag) {
            final isSelected = _selectedTagIds.contains(tag.id);
            return FilterChip(
              selected: isSelected,
              onSelected: (_) => _toggleTag(tag),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Color(tag.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(tag.name),
                ],
              ),
              selectedColor: Color(tag.color).withValues(alpha: 0.3),
              backgroundColor: IOS26Theme.textTertiary.withValues(alpha: 0.1),
              labelStyle: TextStyle(
                color: isSelected ? IOS26Theme.textPrimary : IOS26Theme.textSecondary,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class TagDisplayWidget extends StatelessWidget {
  final List<Tag> tags;
  final double size;

  const TagDisplayWidget({
    super.key,
    required this.tags,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags.map((tag) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Color(tag.color).withValues(alpha: 0.1),
            border: Border.all(
              color: Color(tag.color).withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(size / 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Color(tag.color),
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: size / 3),
              Text(
                tag.name,
                style: TextStyle(
                  fontSize: size,
                  color: IOS26Theme.textPrimary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
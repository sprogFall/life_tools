import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/tags/tag_service.dart';
import '../../../core/theme/ios26_theme.dart';

class TagRenamePage extends StatefulWidget {
  final int tagId;
  final String initialName;

  const TagRenamePage({
    super.key,
    required this.tagId,
    required this.initialName,
  });

  @override
  State<TagRenamePage> createState() => _TagRenamePageState();
}

class _TagRenamePageState extends State<TagRenamePage> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            IOS26AppBar(
              title: '编辑标签',
              showBackButton: true,
              onBackPressed: () => Navigator.pop(context, false),
              actions: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  onPressed: () => _save(context),
                  child: Text('保存', style: IOS26Theme.labelLarge),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('标签名', style: IOS26Theme.titleSmall),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: '例如：紧急',
                          hintStyle: IOS26Theme.bodyMedium,
                          filled: true,
                          fillColor: IOS26Theme.surfaceColor.withValues(
                            alpha: 0.65,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      await _showMessage('提示', '请填写标签名');
      return;
    }

    final service = context.read<TagService>();
    final navigator = Navigator.of(context);

    try {
      await service.renameTag(tagId: widget.tagId, name: name);
    } catch (e) {
      await _showMessage('保存失败', e.toString());
      return;
    }

    if (!mounted) return;
    navigator.pop(true);
  }

  Future<void> _showMessage(String title, String content) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

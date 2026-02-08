import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/ios26_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../utils/overcooked_utils.dart';
import '../../widgets/overcooked_markdown.dart';

class OvercookedRecipeMarkdownPage extends StatefulWidget {
  final String recipeName;
  final String markdown;

  const OvercookedRecipeMarkdownPage({
    super.key,
    required this.recipeName,
    required this.markdown,
  });

  @override
  State<OvercookedRecipeMarkdownPage> createState() =>
      _OvercookedRecipeMarkdownPageState();
}

class _OvercookedRecipeMarkdownPageState
    extends State<OvercookedRecipeMarkdownPage> {
  final GlobalKey _captureKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: l10n.overcooked_recipe_markdown_page_title,
        showBackButton: true,
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: IOS26Theme.minimumTapSize,
            onPressed: _exporting ? null : _exportAsImage,
            child: _exporting
                ? const CupertinoActivityIndicator(radius: 10)
                : const Icon(
                    CupertinoIcons.arrow_down_doc,
                    color: IOS26Theme.primaryColor,
                  ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            IOS26Theme.spacingLg,
            IOS26Theme.spacingMd,
            IOS26Theme.spacingLg,
            IOS26Theme.spacingLg,
          ),
          child: GlassContainer(
            borderRadius: IOS26Theme.radiusXl,
            padding: const EdgeInsets.all(IOS26Theme.spacingLg),
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: _captureKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.recipeName,
                      style: IOS26Theme.titleLarge.copyWith(
                        color: IOS26Theme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: IOS26Theme.spacingMd),
                    OvercookedMarkdownBody(data: widget.markdown),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportAsImage() async {
    if (_exporting) return;

    setState(() => _exporting = true);
    try {
      final boundary =
          _captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        final l10n = AppLocalizations.of(context)!;
        await OvercookedDialogs.showMessage(
          context,
          title: l10n.overcooked_recipe_markdown_export_failed_title,
          content: l10n.overcooked_recipe_markdown_export_failed_no_content,
        );
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        await OvercookedDialogs.showMessage(
          context,
          title: l10n.overcooked_recipe_markdown_export_failed_title,
          content: l10n.overcooked_recipe_markdown_export_failed_no_content,
        );
        return;
      }

      final bytes = Uint8List.view(byteData.buffer);
      final filename = _buildImageFileName();
      final savedPath = await FileSaver.instance.saveFile(
        name: filename,
        bytes: bytes,
        ext: 'png',
        mimeType: MimeType.png,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;

      await OvercookedDialogs.showMessage(
        context,
        title: l10n.overcooked_recipe_markdown_export_done_title,
        content: l10n.overcooked_recipe_markdown_export_done_content(savedPath),
      );
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await OvercookedDialogs.showMessage(
        context,
        title: l10n.overcooked_recipe_markdown_export_failed_title,
        content: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _buildImageFileName() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final safeName = widget.recipeName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    final normalized = safeName.isEmpty ? 'recipe' : safeName;
    return '${normalized}_markdown_$y$m${d}_$h$min';
  }
}

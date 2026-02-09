import 'package:flutter/material.dart';

import '../../../../core/theme/ios26_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../widgets/overcooked_markdown.dart';

class OvercookedRecipeMarkdownPage extends StatelessWidget {
  final String recipeName;
  final String markdown;

  const OvercookedRecipeMarkdownPage({
    super.key,
    required this.recipeName,
    required this.markdown,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: l10n.overcooked_recipe_markdown_page_title,
        showBackButton: true,
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
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingLg,
              IOS26Theme.spacingLg,
              IOS26Theme.spacingLg,
              IOS26Theme.spacingSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipeName,
                  style: IOS26Theme.titleLarge.copyWith(
                    color: IOS26Theme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: IOS26Theme.spacingMd),
                Expanded(child: OvercookedMarkdownView(data: markdown)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

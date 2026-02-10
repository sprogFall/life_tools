import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('业务代码不应直接使用 Markdown/MarkdownBody', () async {
    const allowedFiles = <String>{
      'lib/core/widgets/ios26_markdown.dart',
      'lib\\core\\widgets\\ios26_markdown.dart',
    };

    final violations = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final pattern = RegExp(r'\bMarkdown(Body)?\s*\(');

    for (final file in dartFiles) {
      if (allowedFiles.contains(file.path)) continue;
      final content = await file.readAsString();
      if (pattern.hasMatch(content)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下文件仍直接使用 Markdown 组件，请改为 IOS26MarkdownBody / IOS26MarkdownView：\n${violations.join('\n')}',
    );
  });
}

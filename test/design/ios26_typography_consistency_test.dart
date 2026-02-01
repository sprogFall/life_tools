import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib 目录不应存在业务 TextStyle 硬编码', () async {
    final allowedFiles = <String>{'lib/core/theme/ios26_theme.dart'};
    final root = Directory('lib');
    final dartFiles = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = <String>[];

    for (final file in dartFiles) {
      if (allowedFiles.contains(file.path)) {
        continue;
      }
      final content = await file.readAsString();
      if (RegExp(r'TextStyle\s*\(').hasMatch(content)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下文件仍存在 TextStyle 硬编码，请统一替换为 IOS26Theme 文本样式：\n${violations.join('\n')}',
    );
  });
}

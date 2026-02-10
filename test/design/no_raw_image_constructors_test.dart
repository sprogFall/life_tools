import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('业务代码不应直接使用 Image.file/Image.network/Image.memory', () async {
    const allowedFiles = <String>{
      'lib/core/widgets/ios26_image.dart',
      'lib\\core\\widgets\\ios26_image.dart',
    };

    final violations = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final pattern = RegExp(r'\bImage\.(file|network|memory)\s*\(');

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
          '以下文件仍直接使用 Image.xxx 构造器，请改为 IOS26Image.xxx：\n${violations.join('\n')}',
    );
  });
}

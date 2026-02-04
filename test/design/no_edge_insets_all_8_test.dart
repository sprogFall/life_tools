import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib 目录不应存在 EdgeInsets.all(8) 硬编码', () async {
    final root = Directory('lib');
    final dartFiles = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = <String>[];
    final regExp = RegExp(r'EdgeInsets\.all\(\s*8\s*\)');

    for (final file in dartFiles) {
      final content = await file.readAsString();
      if (regExp.hasMatch(content)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下文件仍存在 EdgeInsets.all(8) 硬编码，请统一替换为 IOS26Theme.spacingSm：\n${violations.join('\n')}',
    );
  });
}


import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib 目录不应存在空的 catch (_) {} 块', () async {
    final root = Directory('lib');
    final dartFiles = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = <String>[];
    final emptyCatchRegExp = RegExp(r'catch\s*\(_\)\s*\{\s*\}');

    for (final file in dartFiles) {
      final content = await file.readAsString();
      if (emptyCatchRegExp.hasMatch(content)) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '以下文件仍存在空 catch 块（必须记录日志或显式处理）：\n${violations.join('\n')}',
    );
  });
}


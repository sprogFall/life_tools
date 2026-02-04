import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib 目录不应存在 Colors.white 硬编码', () async {
    final root = Directory('lib');
    final dartFiles = root
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final violations = <String>[];
    const allowedFiles = <String>{
      // 允许在主题层做最底层的色彩定义/兼容（若未来需要）。
      // 当前目标是业务侧不再直接依赖 Colors.white。
    };

    for (final file in dartFiles) {
      if (allowedFiles.contains(file.path)) continue;
      final content = await file.readAsString();
      if (content.contains('Colors.white')) {
        violations.add(file.path);
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下文件仍存在 Colors.white 硬编码，请改用 IOS26Theme.surfaceColor 或语义化颜色常量：\n${violations.join('\n')}',
    );
  });
}


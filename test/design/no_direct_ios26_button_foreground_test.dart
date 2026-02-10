import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('业务页面不应直接引用 buttonColors(...).foreground', () async {
    final targetFiles = <String>{
      ..._collectDartFiles('lib/pages'),
      ..._collectDartFiles('lib/tools'),
      ..._collectDartFiles('lib/core/backup/pages'),
      ..._collectDartFiles('lib/core/messages/pages'),
      ..._collectDartFiles('lib/core/sync/pages'),
      ..._collectDartFiles('lib/core/tags/widgets'),
    };

    final violations = <String>[];
    final regex = RegExp(r'\b\w+Button\.foreground\b');

    for (final path in targetFiles) {
      final lines = await File(path).readAsLines();
      for (var i = 0; i < lines.length; i++) {
        if (regex.hasMatch(lines[i])) {
          violations.add('$path:${i + 1} -> ${lines[i].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          '以下页面仍直接引用按钮 foreground，请改为 IOS26ButtonLabel / IOS26ButtonIcon / IOS26ButtonLoadingIndicator：\n${violations.join('\n')}',
    );
  });
}

Set<String> _collectDartFiles(String rootPath) {
  final root = Directory(rootPath);
  if (!root.existsSync()) {
    return {};
  }

  return root
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path.replaceAll('\\', '/'))
      .toSet();
}

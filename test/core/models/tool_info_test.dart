import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/models/tool_info.dart';
import 'package:flutter/material.dart';

void main() {
  group('ToolInfo', () {
    test('应该正确创建工具信息', () {
      final tool = ToolInfo(
        id: 'test_tool',
        name: '测试工具',
        description: '这是一个测试工具',
        icon: Icons.build,
        color: Colors.blue,
        pageBuilder: () => const SizedBox(),
      );

      expect(tool.id, 'test_tool');
      expect(tool.name, '测试工具');
      expect(tool.description, '这是一个测试工具');
      expect(tool.icon, Icons.build);
      expect(tool.color, Colors.blue);
    });

    test('pageBuilder 应该返回 Widget', () {
      final tool = ToolInfo(
        id: 'test_tool',
        name: '测试工具',
        description: '测试描述',
        icon: Icons.build,
        color: Colors.blue,
        pageBuilder: () => const Text('Test'),
      );

      final widget = tool.pageBuilder();
      expect(widget, isA<Widget>());
    });
  });
}

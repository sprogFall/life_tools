import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/models/tool_info.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('ToolRegistry', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      // 每次测试前清空注册表并注册默认工具
      ToolRegistry.instance.registerAll();
    });

    test('应该是单例模式', () {
      final instance1 = ToolRegistry.instance;
      final instance2 = ToolRegistry.instance;
      expect(identical(instance1, instance2), true);
    });

    test('registerAll 应该注册默认工具', () {
      final tools = ToolRegistry.instance.tools;
      expect(tools.isNotEmpty, true);
      expect(tools.any((t) => t.id == 'work_log'), true);
      expect(tools.any((t) => t.id == 'stockpile_assistant'), true);
      expect(tools.any((t) => t.id == 'tag_manager'), true);
    });

    test('getById 应该返回正确的工具', () {
      final tool = ToolRegistry.instance.getById('work_log');
      expect(tool, isNotNull);
      expect(tool!.name, '工作记录');
    });

    test('getById 查询不存在的工具应返回 null', () {
      final tool = ToolRegistry.instance.getById('non_existent');
      expect(tool, isNull);
    });

    test('tools 列表应该是不可修改的', () {
      final tools = ToolRegistry.instance.tools;
      expect(
        () => tools.add(
          ToolInfo(
            id: 'test',
            name: 'test',
            description: 'test',
            icon: Icons.abc,
            color: Colors.red,
            pageBuilder: () => const SizedBox(),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('stockpile_assistant 默认排序应在 work_log 之后且在 tag_manager 之前', () {
      final ids = ToolRegistry.instance.tools.map((t) => t.id).toList();
      final workIndex = ids.indexOf('work_log');
      final stockIndex = ids.indexOf('stockpile_assistant');
      final tagIndex = ids.indexOf('tag_manager');

      expect(workIndex, isNonNegative);
      expect(stockIndex, workIndex + 1);
      expect(tagIndex, ids.length - 1);
      expect(stockIndex, lessThan(tagIndex));
    });
  });
}

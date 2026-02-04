import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/logic/sync_diff_presenter.dart';

void main() {
  group('SyncDiffPresenter', () {
    test('Should format tool names correctly', () {
      expect(SyncDiffPresenter.getToolName('work_log'), '工作记录');
      expect(SyncDiffPresenter.getToolName('stockpile_assistant'), '囤货助手');
      expect(SyncDiffPresenter.getToolName('overcooked_kitchen'), '胡闹厨房');
      expect(SyncDiffPresenter.getToolName('unknown_tool'), 'unknown_tool');
    });

    test('Should format added tag correctly', () {
      final rawDiff = {
        'change': 'added',
        'path': 'tags[0]',
        'client': {
          'name': '新标签',
          'category_id': 'location',
          'color': 123456
        },
        'server': null,
      };

      final display = SyncDiffPresenter.formatDiffItem('stockpile_assistant', rawDiff);
      
      // We expect something like: "新增了囤货助手下location类型的标签：【新标签】"
      // Or based on the specific requirement: "新增了xx工具下xx类型的标签：【标签名】"
      // The presenter might just return the detail string, and the UI combines it.
      // Let's assume the presenter returns a rich object or just the description.
      // For now, let's check the description part.
      
      expect(display.label, '新增');
      expect(display.details, contains('标签：【新标签】'));
      expect(display.details, contains('位置类型'));
    });

    test('Should format removed tag correctly', () {
      final rawDiff = {
        'change': 'removed',
        'path': 'tags[1]',
        'client': null,
        'server': {
          'name': '旧标签',
          'category_id': 'item_type',
        },
      };

      final display = SyncDiffPresenter.formatDiffItem('overcooked_kitchen', rawDiff);

      expect(display.label, '删除');
      expect(display.details, contains('标签：【旧标签】'));
      expect(display.details, contains('物品类型'));
    });

    test('Should format value changed correctly', () {
       final rawDiff = {
        'change': 'value_changed',
        'path': 'title',
        'client': 'New Title',
        'server': 'Old Title',
      };

      final display = SyncDiffPresenter.formatDiffItem('work_log', rawDiff);
      expect(display.label, '修改');
      expect(display.details, 'Old Title → New Title');
    });
    
    test('Should format path correctly', () {
       final rawDiff = {
        'change': 'value_changed',
        'path': 'items[0].name',
        'client': 'B',
        'server': 'A',
      };
      
      final display = SyncDiffPresenter.formatDiffItem('tool', rawDiff);
      expect(display.path, 'items > 第1项 > name');
    });
  });
}

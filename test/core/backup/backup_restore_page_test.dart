import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/backup/pages/backup_restore_page.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  testWidgets('备份与还原页应包含 TXT 文件导出/导入入口', (tester) async {
    await tester.pumpWidget(
      const TestAppWrapper(
        child: BackupRestorePage(),
      ),
    );

    expect(find.text('导出 JSON 到剪切板'), findsOneWidget);
    expect(find.text('导出为 TXT 文件'), findsOneWidget);
    expect(find.text('从剪切板粘贴'), findsOneWidget);
    expect(find.text('从 TXT 文件导入'), findsOneWidget);
    expect(find.text('开始还原（覆盖本地）'), findsOneWidget);
  });
}


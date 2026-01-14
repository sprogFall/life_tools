import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/backup/pages/backup_restore_page.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  testWidgets('备份与还原页应包含导出/导入功能', (tester) async {
    await tester.pumpWidget(const TestAppWrapper(child: BackupRestorePage()));

    // 导出功能
    expect(find.text('导出并分享'), findsOneWidget);
    expect(find.text('保存到指定目录'), findsOneWidget);
    expect(find.text('复制到剪切板'), findsOneWidget);

    // 导入功能
    expect(find.text('从剪切板粘贴'), findsOneWidget);
    expect(find.text('从 TXT 文件导入'), findsOneWidget);
    expect(find.text('开始还原（覆盖本地）'), findsOneWidget);
  });
}

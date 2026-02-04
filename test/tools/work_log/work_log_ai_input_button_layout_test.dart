import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/floating_icon_button_expectations.dart';
import '../../test_helpers/fake_work_log_repository.dart';
import '../../test_helpers/test_app_wrapper.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('工作记录 AI 录入按钮应为右下角纯图标', (tester) async {
    await tester.pumpWidget(
      TestAppWrapper(
        child: WorkLogToolPage(repository: FakeWorkLogRepository()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expectBottomRightFloatingIconButton(
      tester,
      buttonKey: const ValueKey('work_log_ai_input_button'),
      icon: CupertinoIcons.sparkles,
      shouldNotFindText: 'AI录入',
    );
  });
}

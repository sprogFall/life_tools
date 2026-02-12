import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/pages/calendar/work_log_calendar_view.dart';
import 'package:life_tools/tools/work_log/services/work_log_service.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/fake_work_log_repository.dart';
import '../../test_helpers/test_app_wrapper.dart';

import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  testWidgets('月视图日期格应采用极简无边界风格', (tester) async {
    final service = WorkLogService(repository: FakeWorkLogRepository());
    addTearDown(service.dispose);

    await tester.pumpWidget(
      TestAppWrapper(
        child: ChangeNotifierProvider.value(
          value: service,
          child: const CupertinoPageScaffold(child: WorkLogCalendarView()),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    // 1. 验证不存在旧的立体风格装饰（渐变 + 多层阴影）
    final containers = tester.widgetList<Container>(find.byType(Container));
    final hasOldStyle = containers.any((container) {
      final decoration = container.decoration;
      if (decoration is! BoxDecoration) return false;
      final hasGradient = decoration.gradient != null;
      final hasLayeredShadow = (decoration.boxShadow?.length ?? 0) >= 2;
      return hasGradient && hasLayeredShadow;
    });
    expect(hasOldStyle, isFalse, reason: '不应存在旧的立体风格装饰');

    // 2. 验证选中日期格的样式（单层阴影 + 主色背景 + 无渐变）
    // 默认选中今天
    // 找到包含今天日期的 Container（通过查找父级或结构可能比较复杂，这里直接遍历所有 Container 检查是否有一个符合选中样式的）
    final hasSelectedStyle = containers.any((container) {
      final decoration = container.decoration;
      if (decoration is! BoxDecoration) return false;

      final isPrimaryColor = decoration.color == IOS26Theme.primaryColor;
      final hasSingleShadow = (decoration.boxShadow?.length ?? 0) == 1;
      final noGradient = decoration.gradient == null;

      return isPrimaryColor && hasSingleShadow && noGradient;
    });

    expect(hasSelectedStyle, isTrue, reason: '应存在符合新设计规范的选中日期格');

    // 3. 验证未选中日期格（无背景装饰）
    // 应该有很多 Container 是没有 decoration 的（除了日期格还有其他的，但至少要有一些）
    final hasPlainStyle = containers.any((container) {
      return container.decoration == null;
    });
    expect(hasPlainStyle, isTrue, reason: '应存在无装饰的日期格');
  });
}

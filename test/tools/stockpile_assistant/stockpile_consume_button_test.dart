import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';
import 'package:life_tools/tools/stockpile_assistant/widgets/stockpile_consume_button.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  test('canShowConsumeButton: 剩余数量为 0 时不显示', () {
    final item = StockItem.create(
      name: '抽纸',
      location: '',
      unit: '包',
      totalQuantity: 1,
      remainingQuantity: 0,
      purchaseDate: DateTime(2026, 1, 1),
      expiryDate: null,
      remindDays: 3,
      note: '',
      now: DateTime(2026, 1, 1, 8),
    );

    expect(canShowConsumeButton(item), false);
  });

  testWidgets('StockpileConsumeButton: 应显示「消耗」文案', (tester) async {
    await tester.pumpWidget(
      TestAppWrapper(child: StockpileConsumeButton(onPressed: () {})),
    );
    expect(find.text('消耗'), findsOneWidget);
  });
}


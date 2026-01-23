import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/tabs/overcooked_calendar_tab.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

class _FakeDatabase extends Fake implements Database {}

class _FakeOvercookedRepository extends OvercookedRepository {
  _FakeOvercookedRepository() : super.withDatabase(_FakeDatabase());

  int callCount = 0;

  @override
  Future<Map<int, int>> getMonthlyCookCountsByTypeDistinct({
    required int year,
    required int month,
  }) async {
    callCount++;
    final key = OvercookedRepository.dayKey(DateTime(year, month, 10));
    if (callCount == 1) return {key: 0};
    return {key: 3};
  }
}

void main() {
  testWidgets('refreshToken 变化时日历应重新加载并更新渲染', (tester) async {
    final repo = _FakeOvercookedRepository();
    var token = 0;

    Widget build() {
      return Provider<OvercookedRepository>.value(
        value: repo,
        child: MaterialApp(
          home: OvercookedCalendarTab(
            month: DateTime(2026, 1, 1),
            refreshToken: token,
            onMonthChanged: (_) {},
            onOpenDay: (_) {},
          ),
        ),
      );
    }

    await tester.pumpWidget(build());
    await tester.pump();
    expect(repo.callCount, 1);

    final dayKey = OvercookedRepository.dayKey(DateTime(2026, 1, 10));
    final cellFinder = find.byKey(ValueKey('overcooked_calendar_day_$dayKey'));
    expect(cellFinder, findsOneWidget);

    Color? cellColor() {
      final box = tester.widget<Container>(cellFinder);
      final decoration = box.decoration as BoxDecoration;
      return decoration.color;
    }

    final firstColor = cellColor();
    token++;
    await tester.pumpWidget(build());
    await tester.pump();
    expect(repo.callCount, 2);

    final secondColor = cellColor();
    expect(firstColor, isNot(equals(secondColor)));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/tabs/overcooked_calendar_tab.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_helpers/test_app_wrapper.dart';

class _FakeDatabase extends Fake implements Database {}

class _FakeOvercookedRepository extends OvercookedRepository {
  _FakeOvercookedRepository() : super.withDatabase(_FakeDatabase());

  int callCount = 0;
  int recentCallCount = 0;
  List<({DateTime cookedDate, OvercookedRecipe recipe, int cookCount})>
  recentCookedRecipes = const [];

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

  @override
  Future<List<({DateTime cookedDate, OvercookedRecipe recipe, int cookCount})>>
  listRecentCookedRecipesForMonth({
    required int year,
    required int month,
    int limit = 5,
  }) async {
    recentCallCount++;
    return recentCookedRecipes;
  }
}

OvercookedRecipe _buildRecipe({required int id, required String name}) {
  final now = DateTime(2026, 1, 1, 12);
  return OvercookedRecipe.create(
    name: name,
    coverImageKey: null,
    typeTagId: null,
    ingredientTagIds: const [],
    sauceTagIds: const [],
    flavorTagIds: const [],
    intro: '',
    content: '',
    detailImageKeys: const [],
    now: now,
  ).copyWith(id: id);
}

void main() {
  testWidgets('refreshToken 变化时日历应重新加载并更新渲染', (tester) async {
    final repo = _FakeOvercookedRepository();
    var token = 0;

    Widget build() {
      return Provider<OvercookedRepository>.value(
        value: repo,
        child: TestAppWrapper(
          child: OvercookedCalendarTab(
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

  testWidgets('本月有做菜时应显示最近做的菜模块', (tester) async {
    final repo = _FakeOvercookedRepository();
    repo.recentCookedRecipes = [
      (
        cookedDate: DateTime(2026, 1, 10),
        recipe: _buildRecipe(id: 1, name: '番茄炒蛋'),
        cookCount: 2,
      ),
      (
        cookedDate: DateTime(2026, 1, 8),
        recipe: _buildRecipe(id: 2, name: '红烧肉'),
        cookCount: 1,
      ),
    ];

    await tester.pumpWidget(
      Provider<OvercookedRepository>.value(
        value: repo,
        child: TestAppWrapper(
          child: OvercookedCalendarTab(
            month: DateTime(2026, 1, 1),
            onMonthChanged: _noopMonthChanged,
            onOpenDay: _noopDayOpen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.recentCallCount, 1);

    final recentCard = find.byKey(
      const ValueKey('overcooked_calendar_recent_recipes_card'),
    );
    for (var i = 0; i < 6 && recentCard.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }

    expect(recentCard, findsOneWidget);
    expect(find.text('最近做的菜'), findsOneWidget);
    expect(find.text('番茄炒蛋'), findsOneWidget);
    expect(find.text('红烧肉'), findsOneWidget);
  });

  testWidgets('本月没有做菜时不显示最近做的菜模块', (tester) async {
    final repo = _FakeOvercookedRepository();

    await tester.pumpWidget(
      Provider<OvercookedRepository>.value(
        value: repo,
        child: TestAppWrapper(
          child: OvercookedCalendarTab(
            month: DateTime(2026, 1, 1),
            onMonthChanged: _noopMonthChanged,
            onOpenDay: _noopDayOpen,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('overcooked_calendar_recent_recipes_card')),
      findsNothing,
    );
    expect(find.text('最近做的菜'), findsNothing);
  });
}

void _noopMonthChanged(DateTime _) {}

void _noopDayOpen(DateTime _) {}

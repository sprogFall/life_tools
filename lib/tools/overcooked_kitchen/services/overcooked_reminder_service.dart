import '../../../core/messages/message_service.dart';
import '../../../core/tags/tag_repository.dart';
import '../models/overcooked_recipe.dart';
import '../repository/overcooked_repository.dart';

class OvercookedReminderService {
  final OvercookedRepository _repository;
  final TagRepository _tagRepository;

  OvercookedReminderService({
    OvercookedRepository? repository,
    TagRepository? tagRepository,
  }) : _repository = repository ?? OvercookedRepository(),
       _tagRepository = tagRepository ?? TagRepository();

  static String dedupeKeyForDayKey(int dayKey) {
    return 'overcooked:wish:$dayKey';
  }

  static int notificationIdForDayKey(int dayKey) {
    return 3000000 + dayKey;
  }

  Future<void> pushDueReminders({
    required MessageService messageService,
    DateTime? now,
  }) async {
    final time = now ?? DateTime.now();
    final today = DateTime(time.year, time.month, time.day);
    final expiresAt = today.add(const Duration(days: 1));
    final key = OvercookedRepository.dayKey(today);
    final wishes = await _repository.listWishesForDate(today);
    final dedupeKey = dedupeKeyForDayKey(key);

    await messageService.cancelSystemNotification(notificationIdForDayKey(key));

    if (wishes.isEmpty) {
      await messageService.deleteMessageByDedupeKey(dedupeKey);
      return;
    }

    final recipeIds = wishes.map((e) => e.recipeId).toList();
    final recipes = await _repository.listRecipesByIds(recipeIds);

    final body = await _buildBody(today: today, recipes: recipes);

    await messageService.upsertMessage(
      toolId: 'overcooked_kitchen',
      title: '胡闹厨房',
      body: body,
      dedupeKey: dedupeKey,
      route: 'tool://overcooked_kitchen',
      createdAt: time,
      expiresAt: expiresAt,
      notify: true,
      markUnreadOnUpdate: false,
    );
  }

  Future<String> _buildBody({
    required DateTime today,
    required List<OvercookedRecipe> recipes,
  }) async {
    final dateText =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final recipeNames = recipes
        .map((e) => e.name.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final ingredientIds = <int>{};
    final sauceIds = <int>{};
    for (final r in recipes) {
      ingredientIds.addAll(r.ingredientTagIds);
      sauceIds.addAll(r.sauceTagIds);
    }

    final tagNames = await _listTagNamesByIds([...ingredientIds, ...sauceIds]);
    final ingredientNames = ingredientIds
        .map((id) => tagNames[id])
        .whereType<String>()
        .toList();
    final sauceNames = sauceIds
        .map((id) => tagNames[id])
        .whereType<String>()
        .toList();

    final lines = <String>[
      '【今日愿望单】$dateText',
      if (recipeNames.isNotEmpty) '想吃：${recipeNames.join('、')}',
      if (ingredientNames.isNotEmpty) '主料：${ingredientNames.join('、')}',
      if (sauceNames.isNotEmpty) '调味：${sauceNames.join('、')}',
    ];
    return lines.join('\n');
  }

  Future<Map<int, String>> _listTagNamesByIds(List<int> ids) async {
    final list = await _tagRepository.listTagsByIds(ids);
    return {
      for (final t in list)
        if (t.id != null) t.id!: t.name,
    };
  }
}

import 'dart:math';

import '../models/overcooked_recipe.dart';
import '../repository/overcooked_repository.dart';

class OvercookedGachaService {
  final OvercookedRepository _repository;

  OvercookedGachaService({OvercookedRepository? repository})
    : _repository = repository ?? OvercookedRepository();

  Future<List<OvercookedRecipe>> pick({
    required List<int> typeTagIds,
    int? seed,
  }) async {
    final ids =
        typeTagIds.map((e) => e).where((e) => e > 0).toSet().toList()..sort();
    if (ids.isEmpty) return const [];

    final recipes = await _repository.listRecipesByTypeTagIds(ids);
    final byType = <int, List<OvercookedRecipe>>{};
    for (final r in recipes) {
      final t = r.typeTagId;
      if (t == null) continue;
      (byType[t] ??= <OvercookedRecipe>[]).add(r);
    }

    final rnd = Random(seed);
    final picked = <OvercookedRecipe>[];
    for (final typeId in ids) {
      final candidates = byType[typeId];
      if (candidates == null || candidates.isEmpty) continue;
      picked.add(candidates[rnd.nextInt(candidates.length)]);
    }
    return picked;
  }
}


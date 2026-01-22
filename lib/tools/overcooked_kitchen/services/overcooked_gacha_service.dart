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
    final normalized =
        typeTagIds.map((e) => e).where((e) => e > 0).toSet().toList()..sort();
    return pickByTypeCounts(
      typeCounts: {for (final id in normalized) id: 1},
      seed: seed,
    );
  }

  Future<List<OvercookedRecipe>> pickByTypeCounts({
    required Map<int, int> typeCounts,
    int? seed,
  }) async {
    final normalized = <int, int>{};
    for (final entry in typeCounts.entries) {
      final typeId = entry.key;
      final count = entry.value;
      if (typeId <= 0 || count <= 0) continue;
      normalized[typeId] = count;
    }
    if (normalized.isEmpty) return const [];

    final ids = normalized.keys.toList()..sort();
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
      final count = normalized[typeId] ?? 0;
      if (count <= 0) continue;
      picked.addAll(_pickDistinct(candidates, count, rnd));
    }
    return picked;
  }

  static List<OvercookedRecipe> _pickDistinct(
    List<OvercookedRecipe> candidates,
    int count,
    Random rnd,
  ) {
    if (candidates.isEmpty || count <= 0) return const [];
    if (count >= candidates.length) {
      final copied = [...candidates];
      copied.shuffle(rnd);
      return copied;
    }

    final indices = <int>{};
    while (indices.length < count) {
      indices.add(rnd.nextInt(candidates.length));
    }
    return indices.map((i) => candidates[i]).toList();
  }
}

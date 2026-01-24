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
    bool useRatingWeight = true,
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

    // 获取评分统计用于权重计算
    Map<int, ({int cookCount, double avgRating, int ratingCount})>? stats;
    if (useRatingWeight) {
      stats = await _repository.getRecipeStats();
    }

    final rnd = Random(seed);
    final picked = <OvercookedRecipe>[];
    for (final typeId in ids) {
      final candidates = byType[typeId];
      if (candidates == null || candidates.isEmpty) continue;
      final count = normalized[typeId] ?? 0;
      if (count <= 0) continue;
      picked.addAll(_pickWeighted(candidates, count, rnd, stats));
    }
    return picked;
  }

  /// 带权重的抽取，高分菜谱有更高的抽取概率
  static List<OvercookedRecipe> _pickWeighted(
    List<OvercookedRecipe> candidates,
    int count,
    Random rnd,
    Map<int, ({int cookCount, double avgRating, int ratingCount})>? stats,
  ) {
    if (candidates.isEmpty || count <= 0) return const [];
    if (count >= candidates.length) {
      final copied = [...candidates];
      copied.shuffle(rnd);
      return copied;
    }

    // 如果没有统计数据，使用均匀分布
    if (stats == null || stats.isEmpty) {
      return _pickDistinct(candidates, count, rnd);
    }

    // 计算权重：基础权重 1.0，每 1 分平均分增加 0.5 权重
    // 例如：0分=1.0, 3分=2.5, 5分=3.5
    final weights = <double>[];
    for (final r in candidates) {
      final stat = r.id != null ? stats[r.id!] : null;
      final avgRating = stat?.avgRating ?? 0.0;
      final weight = 1.0 + avgRating * 0.5;
      weights.add(weight);
    }

    final picked = <OvercookedRecipe>[];
    final available = List<int>.generate(candidates.length, (i) => i);
    final availableWeights = List<double>.from(weights);

    while (picked.length < count && available.isNotEmpty) {
      final totalWeight = availableWeights.fold(0.0, (a, b) => a + b);
      final target = rnd.nextDouble() * totalWeight;

      var cumulative = 0.0;
      int selectedIdx = 0;
      for (int i = 0; i < available.length; i++) {
        cumulative += availableWeights[i];
        if (cumulative >= target) {
          selectedIdx = i;
          break;
        }
      }

      picked.add(candidates[available[selectedIdx]]);
      available.removeAt(selectedIdx);
      availableWeights.removeAt(selectedIdx);
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

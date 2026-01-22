enum OvercookedFlavor {
  sour(1 << 0, '酸'),
  sweet(1 << 1, '甜'),
  spicy(1 << 2, '辣'),
  salty(1 << 3, '咸'),
  bitter(1 << 4, '苦');

  final int bit;
  final String label;
  const OvercookedFlavor(this.bit, this.label);

  static int toMask(Iterable<OvercookedFlavor> values) {
    var mask = 0;
    for (final v in values) {
      mask |= v.bit;
    }
    return mask;
  }

  static Set<OvercookedFlavor> fromMask(int mask) {
    final result = <OvercookedFlavor>{};
    for (final v in OvercookedFlavor.values) {
      if ((mask & v.bit) != 0) result.add(v);
    }
    return result;
  }
}


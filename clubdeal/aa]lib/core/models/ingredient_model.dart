class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.baseUnit,
    required this.stockQuantity,
    required this.averageUnitCost,
    this.lowStockThreshold = 0,
  });
  final String id, name, baseUnit;
  final double stockQuantity, averageUnitCost, lowStockThreshold;

  factory Ingredient.fromMap(String id, Map<String, dynamic> m) => Ingredient(
    id: id,
    name: m['name'] as String? ?? '',
    baseUnit: m['baseUnit'] as String? ?? 'g',
    stockQuantity: (m['stockQuantity'] as num? ?? 0).toDouble(),
    averageUnitCost: (m['averageUnitCost'] as num? ?? 0).toDouble(),
    lowStockThreshold: (m['lowStockThreshold'] as num? ?? 0).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'baseUnit': baseUnit,
    'stockQuantity': stockQuantity,
    'averageUnitCost': averageUnitCost,
    'lowStockThreshold': lowStockThreshold,
  };
}

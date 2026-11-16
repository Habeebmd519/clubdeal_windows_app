class StockItem {
  final String id;
  final String name;
  final String category;
  final String unit;
  final double quantity;
  final double lowStockThreshold;
  final double unitCost;
  final DateTime createdAt;

  const StockItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.lowStockThreshold,
    required this.unitCost,
    required this.createdAt,
  });

  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity > 0 && quantity <= lowStockThreshold;
  double get stockValue => quantity * unitCost;

  StockItem copyWith({
    String? name,
    String? category,
    String? unit,
    double? quantity,
    double? lowStockThreshold,
    double? unitCost,
  }) => StockItem(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    quantity: quantity ?? this.quantity,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    unitCost: unitCost ?? this.unitCost,
    createdAt: createdAt,
  );
}

class RecipeLine {
  const RecipeLine({required this.ingredientId, required this.quantity});
  final String ingredientId;
  final double quantity;
  factory RecipeLine.fromMap(Map<String, dynamic> m) => RecipeLine(
    ingredientId: m['ingredientId'] as String,
    quantity: (m['quantity'] as num).toDouble(),
  );
  Map<String, dynamic> toMap() => {
    'ingredientId': ingredientId,
    'quantity': quantity,
  };
}

class MenuRecipe {
  const MenuRecipe({required this.menuItemId, required this.lines});
  final String menuItemId;
  final List<RecipeLine> lines;
  factory MenuRecipe.fromMap(String id, Map<String, dynamic> m) => MenuRecipe(
    menuItemId: id,
    lines: ((m['lines'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RecipeLine.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
  );
  Map<String, dynamic> toMap() => {
    'lines': lines.map((e) => e.toMap()).toList(),
  };
}

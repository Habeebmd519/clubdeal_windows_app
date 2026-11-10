import 'package:cloud_firestore/cloud_firestore.dart';

enum StockMovementType { purchase, consumption, adjustment }

class StockMovement {
  const StockMovement({
    required this.id,
    required this.ingredientId,
    required this.type,
    required this.quantity,
    required this.unitCost,
    required this.createdAt,
    this.referenceId,
  });
  final String id, ingredientId;
  final StockMovementType type;
  final double quantity, unitCost;
  final DateTime createdAt;
  final String? referenceId;

  factory StockMovement.fromMap(String id, Map<String, dynamic> m) =>
      StockMovement(
        id: id,
        ingredientId: m['ingredientId'] as String? ?? '',
        type: StockMovementType.values.firstWhere(
          (e) => e.name == m['type'],
          orElse: () => StockMovementType.adjustment,
        ),
        quantity: (m['quantity'] as num? ?? 0).toDouble(),
        unitCost: (m['unitCost'] as num? ?? 0).toDouble(),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        referenceId: m['referenceId'] as String?,
      );
  Map<String, dynamic> toMap() => {
    'ingredientId': ingredientId,
    'type': type.name,
    'quantity': quantity,
    'unitCost': unitCost,
    'createdAt': Timestamp.fromDate(createdAt),
    'referenceId': referenceId,
  };
}

import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseType { purchase, operating }

class Expense {
  const Expense({
    required this.id, required this.title, required this.amount,
    required this.type, required this.createdAt,
    this.category = 'General', this.ingredientId, this.quantity,
    this.unit, this.notes = '',
  });

  final String id, title, category, notes;
  final double amount;
  final ExpenseType type;
  final DateTime createdAt;
  final String? ingredientId, unit;
  final double? quantity;

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['createdAt'];
    final date = rawDate is Timestamp ? rawDate.toDate()
        : rawDate is DateTime ? rawDate : DateTime.now();
    final rawType = map['type'];
    return Expense(
      id: id,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num? ?? 0).toDouble(),
      type: rawType == 'purchase' ? ExpenseType.purchase : ExpenseType.operating,
      createdAt: date,
      category: map['category'] as String? ?? 'General',
      ingredientId: map['ingredientId'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title, 'amount': amount,
    'type': type == ExpenseType.purchase ? 'purchase' : 'operating',
    'createdAt': Timestamp.fromDate(createdAt),
    'category': category, 'ingredientId': ingredientId,
    'quantity': quantity, 'unit': unit, 'notes': notes,
  };
}

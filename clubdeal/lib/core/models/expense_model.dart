import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseType { purchase, operating }

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.category = 'General',
    this.ingredientId,
    this.quantity,
    this.unit,
    this.notes = '',
  });

  final String id;
  final String title;
  final double amount;
  final ExpenseType type;
  final DateTime createdAt;
  final String category;
  final String? ingredientId;
  final double? quantity;
  final String? unit;
  final String notes;

  factory Expense.fromMap(String id, Map<String, dynamic> map) => Expense(
    id: id,
    title: map['title'] as String? ?? '',
    amount: (map['amount'] as num? ?? 0).toDouble(),
    type: map['type'] == 'purchase' ? ExpenseType.purchase : ExpenseType.operating,
    createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    category: map['category'] as String? ?? 'General',
    ingredientId: map['ingredientId'] as String?,
    quantity: (map['quantity'] as num?)?.toDouble(),
    unit: map['unit'] as String?,
    notes: map['notes'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'title': title, 'amount': amount,
    'type': type == ExpenseType.purchase ? 'purchase' : 'operating',
    'createdAt': Timestamp.fromDate(createdAt),
    'category': category, 'ingredientId': ingredientId,
    'quantity': quantity, 'unit': unit, 'notes': notes,
  };
}

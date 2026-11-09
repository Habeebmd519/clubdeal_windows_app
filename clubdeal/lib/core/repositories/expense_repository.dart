import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  ExpenseRepository(this._db);
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _items => _db.collection('expenses');

  Stream<List<Expense>> watchForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return _items.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
      .where('createdAt', isLessThan: Timestamp.fromDate(end))
      .orderBy('createdAt', descending: true).snapshots().map((s) =>
        s.docs.map((d) => Expense.fromMap(d.id, d.data())).toList());
  }

  Future<void> add(Expense expense) async {
    await _items.add(expense.toMap());
  }

  Future<void> delete(String id) => _items.doc(id).delete();
}

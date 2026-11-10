import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  ExpenseRepository(this._db);
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _items => _db.collection('expenses');

  Stream<List<Expense>> watchSince(DateTime from) {
    return _items
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Expense.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> add(Expense expense) async {
    await _items.add(expense.toMap());
  }

  Future<void> delete(String id) => _items.doc(id).delete();
}

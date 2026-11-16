import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../models/financial_summary_model.dart';

class ReportRepository {
  ReportRepository(this._db);
  final FirebaseFirestore _db;

  Future<FinancialSummary> summarize(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    // Adapt this query/status filter to the actual order schema before production.
    final results = await Future.wait([
      _db.collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end)).get(),
      _db.collection('expenses')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end)).get(),
    ]);
    double sales = 0, purchases = 0, operating = 0;
    for (final d in results[0].docs) {
      final m = d.data();
      sales += (m['total'] as num? ?? m['totalAmount'] as num? ?? 0).toDouble();
    }
    for (final d in results[1].docs) {
      final e = Expense.fromMap(d.id, d.data());
      if (e.type == ExpenseType.purchase) {
        purchases += e.amount;
      } else {
        operating += e.amount;
      }
    }
    // Consumption cost requires recipe deductions; not inferred from purchases.
    return FinancialSummary(
      sales: sales, purchaseSpend: purchases, consumptionCost: 0,
      operatingExpenses: operating, orderCount: results[0].size,
    );
  }
}

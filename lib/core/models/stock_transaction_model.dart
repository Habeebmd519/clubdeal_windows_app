enum StockTransactionType { purchase, usage, adjustment }

class StockTransaction {
  final String id;
  final String stockId;
  final String stockName;
  final StockTransactionType type;
  final double quantity; // Positive magnitude; type determines direction.
  final double balanceAfter;
  final DateTime date;
  final String note;
  final String supplier;
  final double unitPrice;

  const StockTransaction({
    required this.id,
    required this.stockId,
    required this.stockName,
    required this.type,
    required this.quantity,
    required this.balanceAfter,
    required this.date,
    this.note = '',
    this.supplier = '',
    this.unitPrice = 0,
  });
}

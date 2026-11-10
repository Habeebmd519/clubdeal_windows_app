class FinancialSummary {
  const FinancialSummary({
    required this.sales, required this.purchaseSpend,
    required this.consumptionCost, required this.operatingExpenses,
    required this.orderCount,
  });
  final double sales, purchaseSpend, consumptionCost, operatingExpenses;
  final int orderCount;
  double get grossProfit => sales - consumptionCost;
  double get netProfit => grossProfit - operatingExpenses;
}

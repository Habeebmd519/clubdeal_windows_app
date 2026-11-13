import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/bloc/expense_bloc.dart';
import '../../core/models/expense_model.dart';
import '../../core/utils/currency_utils.dart';
import 'add_expense_page.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});
  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ExpenseBloc>().add(WatchExpenses(DateTime(2000, 1, 1)));
      }
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  double _totalForDay(List<Expense> items, DateTime day) =>
      items.where((e) => _sameDay(e.createdAt, day)).fold(0.0, (sum, e) => sum + e.amount);

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context, initialDate: _selectedDay,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpenseBloc, ExpenseState>(
      builder: (context, state) {
        final daily = state.items.where((e) => _sameDay(e.createdAt, _selectedDay)).toList();
        final total = _totalForDay(state.items, _selectedDay);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Expenses', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                const Text('Daily purchases, operating costs and expense trends'),
              ])),
              OutlinedButton.icon(onPressed: _pickDay, icon: const Icon(Icons.calendar_month), label: Text(DateFormat('dd MMM yyyy').format(_selectedDay))),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddExpensePage())),
                icon: const Icon(Icons.add), label: const Text('Add Expense'),
              ),
            ]),
            const SizedBox(height: 18),
            if (state.error != null)
              MaterialBanner(
                content: Text('Could not load/save expenses: ${state.error}'),
                actions: [TextButton(onPressed: () => context.read<ExpenseBloc>().add(WatchExpenses(DateTime(2000, 1, 1))), child: const Text('Retry'))],
              ),
            Row(children: [
              Expanded(child: _SummaryCard(title: 'Selected day total', value: formatInr(total), icon: Icons.payments_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(title: 'Entries today', value: '${daily.length}', icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _SummaryCard(title: 'Last 7 days', value: formatInr(_lastSevenTotal(state.items)), icon: Icons.bar_chart)),
            ]),
            const SizedBox(height: 18),
            Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 3, child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Daily expense trend · last 7 days', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Expanded(child: state.loading && state.items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _WeeklyExpenseChart(items: state.items)),
                  ]),
                ),
              )),
              const SizedBox(width: 14),
              Expanded(flex: 4, child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Expenses · ${DateFormat('dd MMM').format(_selectedDay)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Expanded(child: state.loading && state.items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : daily.isEmpty
                        ? const Center(child: Text('No expenses recorded for this date'))
                        : ListView.separated(
                            itemCount: daily.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final e = daily[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(e.title),
                                subtitle: Text('${e.category} · ${DateFormat('hh:mm a').format(e.createdAt)} · ${e.type == ExpenseType.purchase ? 'Purchase' : 'Operating'}'),
                                trailing: Text(formatInr(e.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                                onLongPress: () => _confirmDelete(context, e),
                              );
                            },
                          )),
                    const Text('Tip: long-press an entry to delete it.', style: TextStyle(fontSize: 11, color: Colors.white54)),
                  ]),
                ),
              )),
            ])),
          ]),
        );
      },
    );
  }

  double _lastSevenTotal(List<Expense> items) {
    final start = DateTime.now().subtract(const Duration(days: 6));
    return items.where((e) => !e.createdAt.isBefore(DateTime(start.year, start.month, start.day)))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Future<void> _confirmDelete(BuildContext context, Expense expense) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete expense?'),
      content: Text('Delete ${expense.title} (${formatInr(expense.amount)})?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true && context.mounted) context.read<ExpenseBloc>().add(DeleteExpense(expense.id));
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value, required this.icon});
  final String title, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Row(children: [
      Icon(icon, size: 25, color: Theme.of(context).colorScheme.secondary),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 5),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ])),
    ]),
  ));
}

class _WeeklyExpenseChart extends StatelessWidget {
  const _WeeklyExpenseChart({required this.items});
  final List<Expense> items;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) {
      final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i));
      final total = items.where((e) => e.createdAt.year == d.year && e.createdAt.month == d.month && e.createdAt.day == d.day)
          .fold(0.0, (sum, e) => sum + e.amount);
      return (date: d, total: total);
    });
    final maxValue = days.fold<double>(0, (m, d) => d.total > m ? d.total : m);
    return BarChart(BarChartData(
      maxY: maxValue <= 0 ? 100 : maxValue * 1.25,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42, getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 9)))),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= days.length) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 6), child: Text(DateFormat('E').format(days[i].date), style: const TextStyle(fontSize: 9)));
          },
        )),
      ),
      barGroups: List.generate(days.length, (i) => BarChartGroupData(x: i, barRods: [
        BarChartRodData(toY: days[i].total, width: 18, borderRadius: BorderRadius.circular(4), color: Theme.of(context).colorScheme.primary),
      ])),
    ));
  }
}

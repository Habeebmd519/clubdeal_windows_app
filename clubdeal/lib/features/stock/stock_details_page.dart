import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/bloc/stock_bloc.dart';
import '../../core/models/stock_model.dart';
import '../../core/models/stock_transaction_model.dart';

class StockDetailsPage extends StatefulWidget {
  final StockItem item;
  const StockDetailsPage({super.key, required this.item});

  @override
  State<StockDetailsPage> createState() => _StockDetailsPageState();
}

class _StockDetailsPageState extends State<StockDetailsPage> {
  DateTimeRange? range;
  StockTransactionType? type;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.item.name} History')),
      body: BlocBuilder<StockBloc, StockState>(
        builder: (context, state) {
          final current = state.items.where((e) => e.id == widget.item.id).firstOrNull ?? widget.item;
          final records = state.transactions.where((t) {
            if (t.stockId != widget.item.id) return false;
            if (type != null && t.type != type) return false;
            if (range != null && (t.date.isBefore(DateTime(range!.start.year, range!.start.month, range!.start.day)) ||
                t.date.isAfter(DateTime(range!.end.year, range!.end.month, range!.end.day, 23, 59, 59)))) return false;
            return true;
          }).toList()..sort((a, b) => b.date.compareTo(a.date));

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 20, runSpacing: 12, children: [
                _info('Remaining', '${current.quantity} ${current.unit}'),
                _info('Category', current.category.isEmpty ? '—' : current.category),
                _info('Low-stock level', '${current.lowStockThreshold} ${current.unit}'),
                _info('Estimated value', NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(current.stockValue)),
              ]),
              const SizedBox(height: 20),
              Wrap(spacing: 10, children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDateRange: range,
                    );
                    if (picked != null) setState(() => range = picked);
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(range == null ? 'Filter dates' : '${DateFormat('dd MMM yy').format(range!.start)} – ${DateFormat('dd MMM yy').format(range!.end)}'),
                ),
                DropdownButton<StockTransactionType?>(
                  value: type,
                  hint: const Text('All activity'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All activity')),
                    DropdownMenuItem(value: StockTransactionType.purchase, child: Text('Purchases')),
                    DropdownMenuItem(value: StockTransactionType.usage, child: Text('Usage')),
                    DropdownMenuItem(value: StockTransactionType.adjustment, child: Text('Adjustments')),
                  ],
                  onChanged: (v) => setState(() => type = v),
                ),
                TextButton(onPressed: () => setState(() { range = null; type = null; }), child: const Text('Reset')),
              ]),
              const SizedBox(height: 12),
              const Divider(),
              Expanded(child: records.isEmpty
                ? const Center(child: Text('No stock history for this filter.'))
                : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final t = records[i];
                      final purchase = t.type == StockTransactionType.purchase;
                      return ListTile(
                        leading: CircleAvatar(child: Icon(purchase ? Icons.add : Icons.remove)),
                        title: Text('${purchase ? 'Purchased' : t.type == StockTransactionType.usage ? 'Used' : 'Adjusted'} ${t.quantity} ${current.unit}'),
                        subtitle: Text('${DateFormat('EEE, dd MMM yyyy • hh:mm a').format(t.date)}${t.supplier.isEmpty ? '' : ' • ${t.supplier}'}${t.note.isEmpty ? '' : '\n${t.note}'}'),
                        isThreeLine: t.note.isNotEmpty,
                        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${t.balanceAfter} ${current.unit}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Text('Balance', style: TextStyle(fontSize: 11)),
                        ]),
                      );
                    },
                  ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _info(String title, String value) => SizedBox(
    width: 190,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ]),
    )),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

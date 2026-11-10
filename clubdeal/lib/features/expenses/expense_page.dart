import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/expense_bloc.dart';
import '../../core/utils/currency_utils.dart';
import 'add_expense_page.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});
  @override
  State<ExpensePage> createState() => _ExpensePageState();
}
class _ExpensePageState extends State<ExpensePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseBloc>().add(WatchDailyExpenses(DateTime.now()));
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Expenses'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddExpensePage()),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add expense'),
          ),
        ),
      ],
    ),
    body: BlocBuilder<ExpenseBloc, ExpenseState>(
      builder: (context, state) {
        if (state.loading && state.items.isEmpty) return const Center(child: CircularProgressIndicator());
        if (state.error != null) return Center(child: Text('Could not load expenses: ${state.error}'));
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Card(child: ListTile(
              title: const Text("Today's expenses"),
              subtitle: Text('${state.items.length} entries'),
              trailing: Text(formatInr(state.total), style: Theme.of(context).textTheme.titleLarge),
            )),
            const SizedBox(height: 12),
            Expanded(child: state.items.isEmpty
              ? const Center(child: Text('No expenses recorded today'))
              : ListView.builder(
                itemCount: state.items.length,
                itemBuilder: (_, i) {
                  final e = state.items[i];
                  return Card(child: ListTile(
                    title: Text(e.title), subtitle: Text('${e.category} • ${e.type.name}'),
                    trailing: Text(formatInr(e.amount)),
                  ));
                },
              )),
          ]),
        );
      },
    ),
  );
}

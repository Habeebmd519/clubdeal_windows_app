import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/expense_bloc.dart';
import '../../core/models/expense_model.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});
  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}
class _AddExpensePageState extends State<AddExpensePage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(), _amount = TextEditingController(), _category = TextEditingController(text: 'General');
  ExpenseType _type = ExpenseType.purchase;
  @override
  void dispose() { _title.dispose(); _amount.dispose(); _category.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add expense')),
    body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(24), children: [
      TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Expense name'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null),
      TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₹)'), validator: (v) => double.tryParse(v ?? '') == null || double.parse(v!) <= 0 ? 'Enter a valid amount' : null),
      TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
      DropdownButtonFormField<ExpenseType>(value: _type, items: ExpenseType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(), onChanged: (v) => setState(() => _type = v ?? ExpenseType.purchase)),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          context.read<ExpenseBloc>().add(AddExpense(Expense(
            id: '', title: _title.text.trim(), amount: double.parse(_amount.text),
            type: _type, createdAt: DateTime.now(), category: _category.text.trim(),
          )));
          Navigator.pop(context);
        },
        child: const Text('Save expense'),
      ),
    ])),
  );
}

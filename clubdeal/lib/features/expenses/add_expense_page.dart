import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/bloc/expense_bloc.dart';
import '../../core/models/expense_model.dart';

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});
  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController(text: 'General');
  final _notes = TextEditingController();
  ExpenseType _type = ExpenseType.purchase;
  DateTime _dateTime = DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _category.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(
        () => _dateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _dateTime.hour,
          _dateTime.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (picked != null && mounted) {
      setState(
        () => _dateTime = DateTime(
          _dateTime.year,
          _dateTime.month,
          _dateTime.day,
          picked.hour,
          picked.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Expense')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Expense name',
                  hintText: 'e.g. Chicken purchase',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter an expense name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: '0.00',
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  return n == null || n <= 0
                      ? 'Enter an amount greater than zero'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ExpenseType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Expense type'),
                items: ExpenseType.values
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e == ExpenseType.purchase
                              ? 'Purchase'
                              : 'Operating expense',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _type = v ?? ExpenseType.purchase),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(DateFormat('dd MMM yyyy').format(_dateTime)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule),
                      label: Text(DateFormat('hh:mm a').format(_dateTime)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final bloc = context.read<ExpenseBloc>();
                  bloc.add(
                    AddExpense(
                      Expense(
                        id: '',
                        title: _title.text.trim(),
                        amount: double.parse(_amount.text.trim()),
                        type: _type,
                        createdAt: _dateTime,
                        category: _category.text.trim().isEmpty
                            ? 'General'
                            : _category.text.trim(),
                        notes: _notes.text.trim(),
                      ),
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

sealed class ExpenseEvent {
  const ExpenseEvent();
}

class WatchDailyExpenses extends ExpenseEvent {
  const WatchDailyExpenses(this.day);
  final DateTime day;
}

class _ExpensesChanged extends ExpenseEvent {
  const _ExpensesChanged(this.items);
  final List<Expense> items;
}

class _ExpenseFailed extends ExpenseEvent {
  const _ExpenseFailed(this.message);
  final String message;
}

class AddExpense extends ExpenseEvent {
  const AddExpense(this.expense);
  final Expense expense;
}

class ExpenseState {
  const ExpenseState({this.items = const [], this.loading = false, this.error});
  final List<Expense> items;
  final bool loading;
  final String? error;
  double get total => items.fold(0, (sum, e) => sum + e.amount);
}

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  ExpenseBloc(this._repo) : super(const ExpenseState()) {
    on<WatchDailyExpenses>(_watch);
    on<_ExpensesChanged>((e, emit) => emit(ExpenseState(items: e.items)));
    on<_ExpenseFailed>(
      (e, emit) => emit(ExpenseState(items: state.items, error: e.message)),
    );
    on<AddExpense>((e, emit) async {
      try {
        await _repo.add(e.expense);
      } catch (error) {
        emit(ExpenseState(items: state.items, error: error.toString()));
      }
    });
  }
  final ExpenseRepository _repo;
  StreamSubscription<List<Expense>>? _subscription;

  Future<void> _watch(
    WatchDailyExpenses event,
    Emitter<ExpenseState> emit,
  ) async {
    emit(ExpenseState(items: state.items, loading: true));
    await _subscription?.cancel();
    _subscription = _repo
        .watchForDay(event.day)
        .listen(
          (items) => add(_ExpensesChanged(items)),
          onError: (Object e) => add(_ExpenseFailed(e.toString())),
        );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

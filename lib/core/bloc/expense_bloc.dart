import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

sealed class ExpenseEvent { const ExpenseEvent(); }
class WatchExpenses extends ExpenseEvent { const WatchExpenses(this.from); final DateTime from; }
class AddExpense extends ExpenseEvent { const AddExpense(this.expense); final Expense expense; }
class DeleteExpense extends ExpenseEvent { const DeleteExpense(this.id); final String id; }
class _ExpensesChanged extends ExpenseEvent { const _ExpensesChanged(this.items); final List<Expense> items; }
class _ExpenseFailed extends ExpenseEvent { const _ExpenseFailed(this.message); final String message; }

class ExpenseState {
  const ExpenseState({this.items = const [], this.loading = false, this.error, this.saving = false});
  final List<Expense> items;
  final bool loading;
  final String? error;
  final bool saving;
}

class ExpenseBloc extends Bloc<ExpenseEvent, ExpenseState> {
  ExpenseBloc(this._repo) : super(const ExpenseState()) {
    on<WatchExpenses>(_watch);
    on<_ExpensesChanged>((e, emit) => emit(ExpenseState(items: e.items)));
    on<_ExpenseFailed>((e, emit) => emit(ExpenseState(items: state.items, error: e.message)));
    on<AddExpense>((e, emit) async {
      emit(ExpenseState(items: state.items, saving: true));
      try {
        await _repo.add(e.expense);
        emit(ExpenseState(items: state.items));
      } catch (error) {
        emit(ExpenseState(items: state.items, error: error.toString()));
      }
    });
    on<DeleteExpense>((e, emit) async {
      try { await _repo.delete(e.id); }
      catch (error) { emit(ExpenseState(items: state.items, error: error.toString())); }
    });
  }

  final ExpenseRepository _repo;
  StreamSubscription<List<Expense>>? _subscription;

  Future<void> _watch(WatchExpenses event, Emitter<ExpenseState> emit) async {
    emit(ExpenseState(items: state.items, loading: true));
    await _subscription?.cancel();
    _subscription = _repo.watchSince(event.from).listen(
      (items) => add(_ExpensesChanged(items)),
      onError: (Object error) => add(_ExpenseFailed(error.toString())),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

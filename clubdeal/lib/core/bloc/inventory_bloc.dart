import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/ingredient_model.dart';
import '../repositories/inventory_repository.dart';

sealed class InventoryEvent {
  const InventoryEvent();
}

class WatchIngredients extends InventoryEvent {
  const WatchIngredients();
}

class _IngredientsChanged extends InventoryEvent {
  const _IngredientsChanged(this.items);
  final List<Ingredient> items;
}

class _InventoryError extends InventoryEvent {
  const _InventoryError(this.message);
  final String message;
}

class InventoryState {
  const InventoryState({
    this.items = const [],
    this.loading = false,
    this.error,
  });
  final List<Ingredient> items;
  final bool loading;
  final String? error;
}

class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  InventoryBloc(this._repo) : super(const InventoryState()) {
    on<WatchIngredients>((event, emit) async {
      emit(InventoryState(items: state.items, loading: true));
      await _subscription?.cancel();
      _subscription = _repo.watchIngredients().listen(
        (items) => add(_IngredientsChanged(items)),
        onError: (Object e) => add(_InventoryError(e.toString())),
      );
    });
    on<_IngredientsChanged>((e, emit) => emit(InventoryState(items: e.items)));
    on<_InventoryError>(
      (e, emit) => emit(InventoryState(items: state.items, error: e.message)),
    );
  }
  final InventoryRepository _repo;
  StreamSubscription<List<Ingredient>>? _subscription;
  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

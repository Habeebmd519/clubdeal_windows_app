import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/menu_item.dart';
import '../repositories/restaurant_repository.dart';

class MenuState {
  final List<MenuItemModel> items;
  final bool loading;
  final String? error;

  const MenuState({
    this.items = const [],
    this.loading = true,
    this.error,
  });
}

abstract class MenuEvent {
  const MenuEvent();
}

class MenuStarted extends MenuEvent {
  const MenuStarted();
}

class MenuAvailabilityChanged extends MenuEvent {
  final String id;
  final bool available;
  const MenuAvailabilityChanged(this.id, this.available);
}

class MenuItemDeleted extends MenuEvent {
  final String id;
  const MenuItemDeleted(this.id);
}

class _MenuArrived extends MenuEvent {
  final List<MenuItemModel> items;
  const _MenuArrived(this.items);
}

class MenuBloc extends Bloc<MenuEvent, MenuState> {
  final RestaurantRepository repository;
  StreamSubscription<List<MenuItemModel>>? _subscription;

  MenuBloc(this.repository) : super(const MenuState()) {
    on<MenuStarted>(_start);
    on<_MenuArrived>(
      (event, emit) => emit(MenuState(
        items: event.items,
        loading: false,
      )),
    );
    on<_MenuFailed>(
      (event, emit) => emit(MenuState(
        items: state.items,
        loading: false,
        error: event.message,
      )),
    );
    on<MenuAvailabilityChanged>(_availabilityChanged);
    on<MenuItemDeleted>(_delete);
  }

  Future<void> _start(
    MenuStarted event,
    Emitter<MenuState> emit,
  ) async {
    await _subscription?.cancel();
    _subscription = repository.watchMenu().listen(
      (items) => add(_MenuArrived(items)),
      onError: (Object error, StackTrace stack) {
        add(_MenuFailed(error.toString()));
      },
    );
  }

  Future<void> _availabilityChanged(
    MenuAvailabilityChanged event,
    Emitter<MenuState> emit,
  ) async {
    try {
      await repository.setMenuAvailability(event.id, event.available);
    } catch (e) {
      emit(stateForError('Could not change availability: $e'));
    }
  }

  Future<void> _delete(
    MenuItemDeleted event,
    Emitter<MenuState> emit,
  ) async {
    try {
      await repository.deleteMenuItem(event.id);
    } catch (e) {
      emit(stateForError('Could not delete item: $e'));
    }
  }

  MenuState stateForError(String message) {
    return MenuState(
      items: state.items,
      loading: false,
      error: message,
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}


class _MenuFailed extends MenuEvent {
  final String message;
  const _MenuFailed(this.message);
}

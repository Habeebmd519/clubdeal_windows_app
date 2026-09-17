import 'package:flutter_bloc/flutter_bloc.dart';

enum DesktopPage {
  dashboard,
  activeOrders,
  allOrders,
  menu,
  settings,
}

class AppState {
  final DesktopPage page;
  final bool compactMode;

  const AppState({
    this.page = DesktopPage.dashboard,
    this.compactMode = false,
  });

  AppState copyWith({
    DesktopPage? page,
    bool? compactMode,
  }) {
    return AppState(
      page: page ?? this.page,
      compactMode: compactMode ?? this.compactMode,
    );
  }
}

abstract class AppEvent {
  const AppEvent();
}

class AppPageChanged extends AppEvent {
  final DesktopPage page;
  const AppPageChanged(this.page);
}

class AppDensityChanged extends AppEvent {
  final bool compact;
  const AppDensityChanged(this.compact);
}

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(const AppState()) {
    on<AppPageChanged>(
      (event, emit) => emit(state.copyWith(page: event.page)),
    );
    on<AppDensityChanged>(
      (event, emit) => emit(state.copyWith(compactMode: event.compact)),
    );
  }
}

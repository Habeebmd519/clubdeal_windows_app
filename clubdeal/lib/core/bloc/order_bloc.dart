import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/order_model.dart';
import '../repositories/restaurant_repository.dart';
import '../services/printer_service.dart';
import '../services/alert_sound_service.dart';

class OrderState {
  final List<RestaurantOrder> orders;
  final bool loading;
  final String? error;

  const OrderState({this.orders = const [], this.loading = true, this.error});

  OrderState copyWith({
    List<RestaurantOrder>? orders,
    bool? loading,
    String? error,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

abstract class OrderEvent {
  const OrderEvent();
}

class OrdersStarted extends OrderEvent {
  const OrdersStarted();
}

class OrderStatusChanged extends OrderEvent {
  final String orderId;
  final OrderStatus status;
  const OrderStatusChanged(this.orderId, this.status);
}

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final RestaurantRepository repository;
  StreamSubscription<List<RestaurantOrder>>? _subscription;
  final PrinterService? printerService;
  final AlertSoundService? alertSoundService;
  bool _receivedInitialSnapshot = false;
  final Set<String> _knownOrderIds = {};

  OrderBloc(this.repository, {this.printerService, this.alertSoundService}) : super(const OrderState()) {
    on<OrdersStarted>(_start);
    on<OrderStatusChanged>(_changeStatus);
    on<_OrdersArrived>(_ordersArrived);
    on<_OrdersFailed>(
      (event, emit) =>
          emit(state.copyWith(loading: false, error: event.message)),
    );
  }

  Future<void> _start(OrdersStarted event, Emitter<OrderState> emit) async {
    emit(state.copyWith(loading: true, error: null));
    await _subscription?.cancel();

    _subscription = repository.watchOrders().listen(
      (orders) {
        print('🔥 OrderBloc received ${orders.length} orders');
        add(_OrdersArrived(orders));
      },
      onError: (Object error, StackTrace stack) {
        print('❌ FIRESTORE ERROR: $error');
        print(stack);

        add(_OrdersFailed(error.toString()));
      },
    );
  }

  void _ordersArrived(_OrdersArrived event, Emitter<OrderState> emit) {
    final incoming = event.orders;
    if (_receivedInitialSnapshot) {
      final newlyCreated = incoming
          .where((order) => !_knownOrderIds.contains(order.id))
          .toList();
      final printer = printerService;
      if (newlyCreated.isNotEmpty) {
        unawaited(alertSoundService?.playNewOrder() ?? Future<void>.value());
      }
      if (printer != null && printer.autoPrintNewOrders) {
        for (final order in newlyCreated) {
          // Do not block Firestore state updates while the Windows spooler runs.
          printer.printOrder(order).catchError((Object error) {
            print('Automatic receipt print failed for ${order.id}: $error');
          });
        }
      }
    } else {
      _receivedInitialSnapshot = true;
    }
    _knownOrderIds
      ..clear()
      ..addAll(incoming.map((order) => order.id));
    emit(OrderState(orders: incoming, loading: false, error: null));
  }

  Future<void> _changeStatus(
    OrderStatusChanged event,
    Emitter<OrderState> emit,
  ) async {
    try {
      await repository.updateOrderStatus(event.orderId, event.status);
    } catch (e) {
      emit(state.copyWith(error: 'Could not update order: $e'));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

class _OrdersArrived extends OrderEvent {
  final List<RestaurantOrder> orders;
  const _OrdersArrived(this.orders);
}

class _OrdersFailed extends OrderEvent {
  final String message;
  const _OrdersFailed(this.message);
}

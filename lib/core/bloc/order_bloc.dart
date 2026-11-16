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
  OrderState copyWith({List<RestaurantOrder>? orders, bool? loading, String? error}) =>
    OrderState(orders: orders ?? this.orders, loading: loading ?? this.loading, error: error);
}

abstract class OrderEvent { const OrderEvent(); }
class OrdersStarted extends OrderEvent { const OrdersStarted(); }
class OrderStatusChanged extends OrderEvent {
  final String orderId; final OrderStatus status;
  const OrderStatusChanged(this.orderId, this.status);
}
class OrderDeliveredWithPayment extends OrderEvent {
  final String orderId; final PaymentMethod method;
  const OrderDeliveredWithPayment(this.orderId, this.method);
}
class OrderCancelled extends OrderEvent {
  final String orderId; final String reason;
  const OrderCancelled(this.orderId, this.reason);
}
class OrderEdited extends OrderEvent {
  final String orderId, customerName, phone, table, note;
  final List<OrderItem> items;
  const OrderEdited({required this.orderId, required this.customerName, required this.phone,
    required this.table, required this.note, required this.items});
}
class _OrdersArrived extends OrderEvent { final List<RestaurantOrder> orders; const _OrdersArrived(this.orders); }
class _OrdersFailed extends OrderEvent { final String message; const _OrdersFailed(this.message); }

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
    on<OrderDeliveredWithPayment>(_deliver);
    on<OrderCancelled>(_cancel);
    on<OrderEdited>(_edit);
    on<_OrdersArrived>(_ordersArrived);
    on<_OrdersFailed>((event, emit) => emit(state.copyWith(loading: false, error: event.message)));
  }

  Future<void> _start(OrdersStarted event, Emitter<OrderState> emit) async {
    emit(state.copyWith(loading: true, error: null));
    await _subscription?.cancel();
    _subscription = repository.watchOrders().listen(
      (orders) => add(_OrdersArrived(orders)),
      onError: (Object error, StackTrace stack) => add(_OrdersFailed(error.toString())),
    );
  }

  void _ordersArrived(_OrdersArrived event, Emitter<OrderState> emit) {
    final incoming = event.orders;
    if (_receivedInitialSnapshot) {
      final newlyCreated = incoming.where((order) => !_knownOrderIds.contains(order.id)).toList();
      if (newlyCreated.isNotEmpty) {
        unawaited(alertSoundService?.playNewOrder() ?? Future<void>.value());
        // Reserve recipe ingredients as soon as a new order reaches this device.
        // The repository transaction is idempotent, so Firestore retries or
        // repeated snapshots cannot deduct the same order twice.
        for (final order in newlyCreated) {
          if (order.status != OrderStatus.cancelled && order.status != OrderStatus.delivered) {
            unawaited(repository.reserveOrderInventory(order.id).catchError((Object error) {
              add(_OrdersFailed('Stock reservation failed for order ${order.id}: $error'));
            }));
          }
        }
      }
      final printer = printerService;
      if (printer != null && printer.autoPrintNewOrders) {
        for (final order in newlyCreated) {
          printer.printKitchenTicket(order).catchError((Object error) {});
        }
      }
    } else {
      _receivedInitialSnapshot = true;
    }
    // Also reconcile active orders already in Firestore when the desktop
    // starts or reconnects. Reservation is transactionally idempotent.
    for (final order in incoming) {
      if (order.status != OrderStatus.cancelled && order.status != OrderStatus.delivered) {
        unawaited(repository.reserveOrderInventory(order.id).catchError((Object error) {
          add(_OrdersFailed('Stock reservation failed for order ${order.id}: $error'));
        }));
      }
    }
    _knownOrderIds..clear()..addAll(incoming.map((order) => order.id));
    emit(OrderState(orders: incoming, loading: false));
  }

  Future<void> _changeStatus(OrderStatusChanged event, Emitter<OrderState> emit) async {
    try { await repository.updateOrderStatus(event.orderId, event.status); }
    catch (e) { emit(state.copyWith(error: 'Could not update order: $e')); }
  }
  Future<void> _deliver(OrderDeliveredWithPayment event, Emitter<OrderState> emit) async {
    try { await repository.deliverOrder(event.orderId, event.method); }
    catch (e) { emit(state.copyWith(error: 'Could not complete payment: $e')); }
  }
  Future<void> _cancel(OrderCancelled event, Emitter<OrderState> emit) async {
    try {
      await repository.cancelOrder(event.orderId, event.reason);
      RestaurantOrder? order;
      for (final candidate in state.orders) {
        if (candidate.id == event.orderId) { order = candidate; break; }
      }
      // Move it into the cancelled filter immediately; do not wait for the
      // Firestore listener round-trip to repaint the list.
      if (order != null) {
        final cancelled = RestaurantOrder(
          id: order.id, customerName: order.customerName, phone: order.phone,
          table: order.table, items: order.items, total: order.total,
          status: OrderStatus.cancelled, note: order.note, source: order.source,
          createdAt: order.createdAt, paymentMethod: order.paymentMethod,
          deliveredAt: order.deliveredAt, cancelledAt: DateTime.now(),
          cancelReason: event.reason,
        );
        emit(state.copyWith(orders: state.orders.map((item) => item.id == event.orderId ? cancelled : item).toList()));
      }
      final printer = printerService;
      if (printer != null && order != null) {
        try { await printer.printCancellationTicket(order, event.reason); } catch (_) {}
      }
    } catch (e) { emit(state.copyWith(error: 'Could not cancel order: $e')); }
  }
  Future<void> _edit(OrderEdited event, Emitter<OrderState> emit) async {
    try {
      await repository.editOrder(orderId: event.orderId, customerName: event.customerName,
        phone: event.phone, table: event.table, note: event.note, items: event.items);
      RestaurantOrder? previous;
      for (final candidate in state.orders) {
        if (candidate.id == event.orderId) { previous = candidate; break; }
      }
      if (previous != null && printerService != null) {
        final revised = RestaurantOrder(
          id: previous.id, customerName: event.customerName, phone: event.phone,
          table: event.table, items: event.items,
          total: event.items.fold<double>(0, (sum, item) => sum + item.total),
          status: previous.status, note: event.note, source: previous.source,
          createdAt: previous.createdAt, paymentMethod: previous.paymentMethod,
          deliveredAt: previous.deliveredAt, cancelledAt: previous.cancelledAt,
          cancelReason: previous.cancelReason,
        );
        try { await printerService!.printKitchenTicket(revised, revised: true); } catch (_) {}
      }
    } catch (e) { emit(state.copyWith(error: 'Could not edit order: $e')); }
  }
  @override
  Future<void> close() async { await _subscription?.cancel(); return super.close(); }
}

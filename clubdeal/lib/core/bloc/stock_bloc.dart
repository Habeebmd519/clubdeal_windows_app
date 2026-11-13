import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/stock_model.dart';
import '../models/stock_transaction_model.dart';

abstract class StockRepository {
  Future<List<StockItem>> getStocks();
  Future<List<StockTransaction>> getTransactions();
  Future<void> saveStock(StockItem item);
  Future<void> saveTransaction(StockTransaction transaction);
  Future<void> updateStock(StockItem item);
}

/// Replace this with your app's SQLite/Firestore repository.
/// This implementation is intentionally in-memory for a dependency-free demo.
class InMemoryStockRepository implements StockRepository {
  final List<StockItem> _stocks = [];
  final List<StockTransaction> _transactions = [];

  @override
  Future<List<StockItem>> getStocks() async => List.unmodifiable(_stocks);

  @override
  Future<List<StockTransaction>> getTransactions() async =>
      List.unmodifiable(_transactions);

  @override
  Future<void> saveStock(StockItem item) async => _stocks.add(item);

  @override
  Future<void> saveTransaction(StockTransaction transaction) async =>
      _transactions.add(transaction);

  @override
  Future<void> updateStock(StockItem item) async {
    final index = _stocks.indexWhere((e) => e.id == item.id);
    if (index >= 0) _stocks[index] = item;
  }
}

abstract class StockEvent {}

class LoadStocks extends StockEvent {}

class CreateStock extends StockEvent {
  final String name, category, unit;
  final double openingQuantity, lowStockThreshold, unitCost;
  CreateStock({
    required this.name,
    required this.category,
    required this.unit,
    required this.openingQuantity,
    required this.lowStockThreshold,
    required this.unitCost,
  });
}

class PurchaseStock extends StockEvent {
  final String stockId;
  final double quantity, unitPrice;
  final String supplier, note;
  PurchaseStock({
    required this.stockId,
    required this.quantity,
    this.unitPrice = 0,
    this.supplier = '',
    this.note = '',
  });
}

class UseStock extends StockEvent {
  final String stockId;
  final double quantity;
  final String note;
  UseStock({required this.stockId, required this.quantity, this.note = ''});
}

class StockState {
  final List<StockItem> items;
  final List<StockTransaction> transactions;
  final bool loading;
  final String? error;

  const StockState({
    this.items = const [],
    this.transactions = const [],
    this.loading = false,
    this.error,
  });

  StockState copyWith({
    List<StockItem>? items,
    List<StockTransaction>? transactions,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => StockState(
    items: items ?? this.items,
    transactions: transactions ?? this.transactions,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

class StockBloc extends Bloc<StockEvent, StockState> {
  final StockRepository repository;

  StockBloc({required this.repository}) : super(const StockState()) {
    on<LoadStocks>(_onLoad);
    on<CreateStock>(_onCreate);
    on<PurchaseStock>(_onPurchase);
    on<UseStock>(_onUse);
  }

  Future<void> _onLoad(LoadStocks event, Emitter<StockState> emit) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final stocks = await repository.getStocks();
      final transactions = await repository.getTransactions();
      emit(state.copyWith(
        items: stocks,
        transactions: transactions,
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> _onCreate(CreateStock event, Emitter<StockState> emit) async {
    if (event.name.trim().isEmpty || event.openingQuantity < 0) {
      emit(state.copyWith(error: 'Enter a valid stock name and quantity.'));
      return;
    }
    try {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final item = StockItem(
        id: id,
        name: event.name.trim(),
        category: event.category.trim(),
        unit: event.unit.trim(),
        quantity: event.openingQuantity,
        lowStockThreshold: event.lowStockThreshold,
        unitCost: event.unitCost,
        createdAt: DateTime.now(),
      );
      await repository.saveStock(item);
      if (event.openingQuantity > 0) {
        await repository.saveTransaction(StockTransaction(
          id: '${id}_opening',
          stockId: id,
          stockName: item.name,
          type: StockTransactionType.purchase,
          quantity: event.openingQuantity,
          balanceAfter: event.openingQuantity,
          date: DateTime.now(),
          note: 'Opening stock',
          unitPrice: event.unitCost,
        ));
      }
      await _refresh(emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onPurchase(PurchaseStock event, Emitter<StockState> emit) async {
    final item = state.items.where((e) => e.id == event.stockId).firstOrNull;
    if (item == null || event.quantity <= 0) {
      emit(state.copyWith(error: 'Select an item and enter a quantity above zero.'));
      return;
    }
    try {
      final balance = item.quantity + event.quantity;
      final updated = item.copyWith(
        quantity: balance,
        unitCost: event.unitPrice > 0 ? event.unitPrice : item.unitCost,
      );
      await repository.updateStock(updated);
      await repository.saveTransaction(StockTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        stockId: item.id,
        stockName: item.name,
        type: StockTransactionType.purchase,
        quantity: event.quantity,
        balanceAfter: balance,
        date: DateTime.now(),
        supplier: event.supplier,
        note: event.note,
        unitPrice: event.unitPrice,
      ));
      await _refresh(emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUse(UseStock event, Emitter<StockState> emit) async {
    final item = state.items.where((e) => e.id == event.stockId).firstOrNull;
    if (item == null || event.quantity <= 0) {
      emit(state.copyWith(error: 'Select an item and enter a quantity above zero.'));
      return;
    }
    if (event.quantity > item.quantity) {
      emit(state.copyWith(error: 'Not enough stock. Available: ${item.quantity} ${item.unit}.'));
      return;
    }
    try {
      final balance = item.quantity - event.quantity;
      await repository.updateStock(item.copyWith(quantity: balance));
      await repository.saveTransaction(StockTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        stockId: item.id,
        stockName: item.name,
        type: StockTransactionType.usage,
        quantity: event.quantity,
        balanceAfter: balance,
        date: DateTime.now(),
        note: event.note,
      ));
      await _refresh(emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _refresh(Emitter<StockState> emit) async {
    emit(state.copyWith(
      items: await repository.getStocks(),
      transactions: await repository.getTransactions(),
      clearError: true,
    ));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

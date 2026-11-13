import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/inventory_repository.dart';

import '../models/stock_model.dart';
import '../models/stock_transaction_model.dart';

abstract class StockRepository {
  Future<List<StockItem>> getStocks();
  Future<List<StockTransaction>> getTransactions();
  Future<void> saveStock(StockItem item);
  Future<void> saveTransaction(StockTransaction transaction);
  Future<void> updateStock(StockItem item);
  Future<void> deleteStock(String stockId);
  Future<void> purchaseStock({required String stockId, required double quantity, required double totalCost, required String supplier, required String note});
  Future<void> useStock({required String stockId, required double quantity, required String note});
}

/// Firestore is the single source for Stock Management and Menu recipe ingredients.
class FirestoreStockRepository implements StockRepository {
  FirestoreStockRepository(this.db) : inventory = InventoryRepository(db);
  final FirebaseFirestore db;
  final InventoryRepository inventory;
  CollectionReference<Map<String,dynamic>> get _stocks => db.collection('ingredients');
  CollectionReference<Map<String,dynamic>> get _moves => db.collection('stock_movements');

  @override
  Future<List<StockItem>> getStocks() async {
    final s = await _stocks.orderBy('name').get();
    return s.docs.map((d) { final m=d.data(); return StockItem(
      id:d.id, name:m['name']?.toString()??'', category:m['category']?.toString()??'General',
      unit:m['baseUnit']?.toString()??'pcs', quantity:(m['stockQuantity'] as num? ?? 0).toDouble(),
      lowStockThreshold:(m['lowStockThreshold'] as num? ?? 0).toDouble(),
      unitCost:(m['averageUnitCost'] as num? ?? 0).toDouble(),
      createdAt:(m['createdAt'] as Timestamp?)?.toDate()??DateTime.now()); }).toList();
  }
  @override
  Future<List<StockTransaction>> getTransactions() async {
    final s=await _moves.orderBy('createdAt',descending:true).limit(500).get();
    final stock= {for(final x in await getStocks()) x.id:x.name};
    return s.docs.map((d) {final m=d.data(); final t=m['type']?.toString();
      final date=m['createdAt']; return StockTransaction(id:d.id,stockId:m['ingredientId']?.toString()??'',
      stockName:stock[m['ingredientId']?.toString()]??'Stock',
      type:t=='purchase'?StockTransactionType.purchase:(t=='consumption'||t=='usage'?StockTransactionType.usage:StockTransactionType.adjustment),
      quantity:(m['quantity'] as num? ?? 0).toDouble(),balanceAfter:(m['balanceAfter'] as num? ?? 0).toDouble(),
      date:date is Timestamp?date.toDate():DateTime.now(),note:m['reason']?.toString()??m['note']?.toString()??'',
      supplier:m['supplier']?.toString()??'',unitPrice:(m['unitCost'] as num? ?? 0).toDouble());}).toList();
  }
  @override
  Future<void> saveStock(StockItem x) async {
    await _stocks.doc(x.id).set({'name':x.name,'category':x.category,'baseUnit':x.unit,
      'stockQuantity':0.0,'averageUnitCost':x.unitCost,'lowStockThreshold':x.lowStockThreshold,
      'createdAt':Timestamp.fromDate(x.createdAt)});
    if(x.quantity>0) await inventory.setOpeningStock(ingredientId:x.id,name:x.name,unit:x.unit,quantity:x.quantity);
  }
  @override
  Future<void> saveTransaction(StockTransaction x) async {
    await _moves.doc(x.id).set({'ingredientId':x.stockId,'type':x.type==StockTransactionType.purchase?'purchase':x.type==StockTransactionType.usage?'consumption':'adjustment',
      'quantity':x.quantity,'unitCost':x.unitPrice,'createdAt':Timestamp.fromDate(x.date),
      'balanceAfter':x.balanceAfter,'reason':x.note,'supplier':x.supplier});
  }
  @override
  Future<void> updateStock(StockItem x) => _stocks.doc(x.id).update({'name':x.name,'category':x.category,'baseUnit':x.unit,
    'stockQuantity':x.quantity,'averageUnitCost':x.unitCost,'lowStockThreshold':x.lowStockThreshold});
  @override
  Future<void> purchaseStock({required String stockId,required double quantity,required double totalCost,required String supplier,required String note}) =>
    inventory.recordPurchase(ingredientId:stockId,quantity:quantity,totalCost:totalCost,movementId:_moves.doc().id,supplier:supplier,notes:note);
  @override
  Future<void> useStock({required String stockId,required double quantity,required String note}) =>
    inventory.consumeStock(ingredientId:stockId,quantity:quantity,reason:note);
  @override
  Future<void> deleteStock(String id) async {
    final history=await _moves.where('ingredientId',isEqualTo:id).get();
    final batch=db.batch(); batch.delete(_stocks.doc(id));
    for(final d in history.docs){batch.delete(d.reference);}
    await batch.commit();
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

class DeleteStock extends StockEvent {
  final String stockId;

  DeleteStock(this.stockId);
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
    on<DeleteStock>(_onDelete);
  }

  Future<void> _onDelete(DeleteStock event, Emitter<StockState> emit) async {
    try {
      await repository.deleteStock(event.stockId);

      await _refresh(emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLoad(LoadStocks event, Emitter<StockState> emit) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final stocks = await repository.getStocks();
      final transactions = await repository.getTransactions();
      emit(
        state.copyWith(
          items: stocks,
          transactions: transactions,
          loading: false,
        ),
      );
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
        await repository.saveTransaction(
          StockTransaction(
            id: '${id}_opening',
            stockId: id,
            stockName: item.name,
            type: StockTransactionType.purchase,
            quantity: event.openingQuantity,
            balanceAfter: event.openingQuantity,
            date: DateTime.now(),
            note: 'Opening stock',
            unitPrice: event.unitCost,
          ),
        );
      }
      await _refresh(emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onPurchase(
    PurchaseStock event,
    Emitter<StockState> emit,
  ) async {
    final item = state.items.where((e) => e.id == event.stockId).firstOrNull;
    if (item == null || event.quantity <= 0) {
      emit(
        state.copyWith(
          error: 'Select an item and enter a quantity above zero.',
        ),
      );
      return;
    }
    try {
      await repository.purchaseStock(stockId:item.id, quantity:event.quantity,
        totalCost:event.quantity*event.unitPrice, supplier:event.supplier, note:event.note);
      await _refresh(emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUse(UseStock event, Emitter<StockState> emit) async {
    final item = state.items.where((e) => e.id == event.stockId).firstOrNull;
    if (item == null || event.quantity <= 0) {
      emit(
        state.copyWith(
          error: 'Select an item and enter a quantity above zero.',
        ),
      );
      return;
    }
    if (event.quantity > item.quantity) {
      emit(
        state.copyWith(
          error: 'Not enough stock. Available: ${item.quantity} ${item.unit}.',
        ),
      );
      return;
    }
    try {
      await repository.useStock(stockId:item.id, quantity:event.quantity, note:event.note);
      await _refresh(emit);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _refresh(Emitter<StockState> emit) async {
    emit(
      state.copyWith(
        items: await repository.getStocks(),
        transactions: await repository.getTransactions(),
        clearError: true,
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

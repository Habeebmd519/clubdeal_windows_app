import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_item.dart';
import '../models/order_model.dart';
import '../models/stock_movement_model.dart';

class RestaurantRepository {
  final FirebaseFirestore _firestore;
  RestaurantRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');
  CollectionReference<Map<String, dynamic>> get _menu => _firestore.collection('menu2');

  Stream<List<RestaurantOrder>> watchOrders() => _orders.snapshots().map((snapshot) {
    final orders = snapshot.docs.map(RestaurantOrder.fromDocument).toList();
    orders.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
    return orders;
  });

  Stream<List<MenuItemModel>> watchMenu() => _menu.snapshots().map((snapshot) {
    final items = snapshot.docs.map(MenuItemModel.fromDocument).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  });

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final changes = <String, dynamic>{'status': status.name, 'updatedAt': FieldValue.serverTimestamp()};
    if (status == OrderStatus.delivered) changes['deliveredAt'] = FieldValue.serverTimestamp();
    if (status == OrderStatus.cancelled) changes['cancelledAt'] = FieldValue.serverTimestamp();
    await _orders.doc(orderId).update(changes);
  }

  Future<void> deliverOrder(String orderId, PaymentMethod method) async {
    final orderRef = _orders.doc(orderId);
    final orderSnapshot = await orderRef.get();
    if (!orderSnapshot.exists) throw StateError('Order not found.');
    final order = RestaurantOrder.fromDocument(orderSnapshot);

    // Resolve the recipe usage from menu2 before the transaction. Existing
    // menu items without ingredientUsage safely contribute zero.
    double chickenUsed = 0, friesUsed = 0;
    for (final item in order.items) {
      final matches = await _menu.where('name', isEqualTo: item.name).limit(1).get();
      if (matches.docs.isEmpty) continue;
      final raw = matches.docs.first.data()['ingredientUsage'];
      if (raw is Map) {
        final usage = Map<String, dynamic>.from(raw);
        chickenUsed += ((usage['chickenGrams'] as num?)?.toDouble() ?? 0) * item.qty;
        friesUsed += ((usage['friesGrams'] as num?)?.toDouble() ?? 0) * item.qty;
      }
    }

    final ingredientRefs = <String, DocumentReference<Map<String, dynamic>>>{
      if (chickenUsed > 0) 'chicken': _firestore.collection('ingredients').doc('chicken'),
      if (friesUsed > 0) 'fries': _firestore.collection('ingredients').doc('fries'),
    };
    final movementRefs = <String, DocumentReference<Map<String, dynamic>>>{
      for (final id in ingredientRefs.keys) id: _firestore.collection('stock_movements').doc(),
    };

    await _firestore.runTransaction((tx) async {
      final currentOrder = await tx.get(orderRef);
      if (!currentOrder.exists) throw StateError('Order not found.');
      final data = currentOrder.data() ?? <String, dynamic>{};
      if (data['inventoryDeducted'] == true) {
        tx.update(orderRef, {
          'status': OrderStatus.delivered.name, 'paymentMethod': method.name,
          'deliveredAt': data['deliveredAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final stockSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in ingredientRefs.entries) {
        stockSnapshots[entry.key] = await tx.get(entry.value);
      }

      for (final entry in ingredientRefs.entries) {
        if (!stockSnapshots[entry.key]!.exists) {
          final label = entry.key == 'chicken' ? 'Chicken' : 'Fries';
          throw StateError('Set opening stock for $label before delivering this order.');
        }
      }

      for (final entry in ingredientRefs.entries) {
        final id = entry.key;
        final quantity = id == 'chicken' ? chickenUsed : friesUsed;
        final stock = stockSnapshots[id]!;
        if (!stock.exists) continue;
        final old = (stock.data()?['stockQuantity'] as num? ?? 0).toDouble();
        tx.update(entry.value, {
          'stockQuantity': old - quantity,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final movement = movementRefs[id]!;
        tx.set(movement, StockMovement(
          id: movement.id, ingredientId: id,
          type: StockMovementType.consumption, quantity: quantity,
          unitCost: (stock.data()?['averageUnitCost'] as num? ?? 0).toDouble(),
          createdAt: DateTime.now(), referenceId: orderId,
        ).toMap());
      }

      tx.update(orderRef, {
        'status': OrderStatus.delivered.name, 'paymentMethod': method.name,
        'deliveredAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
        'inventoryDeducted': true,
      });
    });
  }

  Future<void> cancelOrder(String orderId, String reason) async {
    await _orders.doc(orderId).update({
      'status': OrderStatus.cancelled.name,
      'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> editOrder({
    required String orderId, required String customerName, required String phone,
    required String table, required String note, required List<OrderItem> items,
  }) async {
    if (items.isEmpty) throw ArgumentError('An order must contain at least one item.');
    final total = items.fold<double>(0, (sum, item) => sum + item.total);
    await _orders.doc(orderId).update({
      'customerName': customerName, 'phone': phone, 'table': table,
      'note': note.isEmpty ? null : note,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total, 'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createManualOrder({
    required String customerName, required String phone, required String table,
    required String note, required List<OrderItem> items,
  }) async {
    final total = items.fold<double>(0, (sum, item) => sum + item.total);
    await _orders.add({
      'customerName': customerName, 'phone': phone, 'table': table.isEmpty ? 'main' : table,
      'items': items.map((item) => item.toMap()).toList(), 'total': total,
      'status': OrderStatus.pending.name, 'note': note.isEmpty ? null : note,
      'category': 'Manual', 'source': 'manual', 'createdAt': FieldValue.serverTimestamp(),
      'kocPrinted': false, 'kocPrintedAt': null, 'paymentMethod': null,
    });
  }

  Future<void> saveMenuItem({
    String? id, required String name, required double price, required String category,
    required String description, required String emoji, required String tag,
    required bool isAvailable, double chickenGrams = 0, double friesGrams = 0,
  }) async {
    final doc = id == null ? _menu.doc() : _menu.doc(id);
    await doc.set({
      'name': name, 'price': price, 'category': category, 'description': description,
      'emoji': emoji.isEmpty ? '🍽️' : emoji, 'tag': tag, 'isAvailable': isAvailable,
      'ingredientUsage': {'chickenGrams': chickenGrams, 'friesGrams': friesGrams},
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setMenuAvailability(String id, bool available) => _menu.doc(id).update({'isAvailable': available});
  Future<void> deleteMenuItem(String id) => _menu.doc(id).delete();
}

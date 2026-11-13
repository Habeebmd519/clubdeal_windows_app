import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_item.dart';
import '../models/order_model.dart';

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
    await _orders.doc(orderId).update({
      'status': OrderStatus.delivered.name,
      'paymentMethod': method.name,
      'deliveredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
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

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/menu_item.dart';
import '../models/order_model.dart';

class RestaurantRepository {
  final FirebaseFirestore _firestore;

  RestaurantRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  CollectionReference<Map<String, dynamic>> get _menu =>
      _firestore.collection('menu2');

  Stream<List<RestaurantOrder>> watchOrders() {
    return _orders.snapshots().map((snapshot) {
      final orders = snapshot.docs.map(RestaurantOrder.fromDocument).toList();

      orders.sort((a, b) {
        final aa = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bb = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bb.compareTo(aa);
      });

      return orders;
    });
  }

  Stream<List<MenuItemModel>> watchMenu() {
    return _menu.snapshots().map((snapshot) {
      final items = snapshot.docs.map(MenuItemModel.fromDocument).toList();

      items.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return items;
    });
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    await _orders.doc(orderId).update({'status': status.name});
  }

  Future<void> createManualOrder({
    required String customerName,
    required String phone,
    required String table,
    required String note,
    required List<OrderItem> items,
  }) async {
    final total = items.fold<double>(0, (sum, item) => sum + item.total);

    await _orders.add({
      'customerName': customerName,
      'phone': phone,
      'table': table.isEmpty ? 'main' : table,
      'items': items.map((item) => item.toMap()).toList(),
      'total': total,
      'status': OrderStatus.pending.name,
      'note': note.isEmpty ? null : note,
      'category': 'Manual',
      'source': 'manual',
      'createdAt': FieldValue.serverTimestamp(),
      'kocPrinted': false,
      'kocPrintedAt': null,
    });
  }

  Future<void> saveMenuItem({
    String? id,
    required String name,
    required double price,
    required String category,
    required String description,
    required String emoji,
    required String tag,
    required bool isAvailable,
  }) async {
    final doc = id == null ? _menu.doc() : _menu.doc(id);

    await doc.set({
      'name': name,
      'price': price,
      'category': category,
      'description': description,
      'emoji': emoji.isEmpty ? '🍽️' : emoji,
      'tag': tag,
      'isAvailable': isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
      if (id == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setMenuAvailability(String id, bool available) async {
    await _menu.doc(id).update({'isAvailable': available});
  }

  Future<void> deleteMenuItem(String id) async {
    await _menu.doc(id).delete();
  }
}

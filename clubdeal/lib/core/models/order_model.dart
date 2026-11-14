import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending, preparing, ready, delivered, cancelled;

  static OrderStatus fromString(String? value) => OrderStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => OrderStatus.pending,
  );
}

enum PaymentMethod {
  cash, card, online;

  static PaymentMethod? fromString(String? value) {
    for (final method in values) {
      if (method.name == value) return method;
    }
    return null;
  }
}

class OrderItem {
  final String name;
  final int qty;
  final double price;
  final String emoji;
  final String category;

  const OrderItem({
    required this.name, required this.qty, required this.price,
    this.emoji = '🍽️', this.category = '',
  });

  double get total => qty * price;

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
    name: '${map['name'] ?? ''}',
    qty: _toInt(map['qty']),
    price: _toDouble(map['price']),
    emoji: '${map['emoji'] ?? '🍽️'}',
    category: '${map['cat'] ?? map['category'] ?? ''}',
  );

  Map<String, dynamic> toMap() => {
    'name': name, 'qty': qty, 'price': price, 'emoji': emoji, 'cat': category,
  };
}

class RestaurantOrder {
  final String id, customerName, phone, table, note, source;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final DateTime? createdAt, deliveredAt, cancelledAt;
  final PaymentMethod? paymentMethod;
  final String cancelReason;

  const RestaurantOrder({
    required this.id, required this.customerName, required this.phone,
    required this.table, required this.items, required this.total,
    required this.status, required this.note, required this.source,
    required this.createdAt, this.paymentMethod, this.deliveredAt,
    this.cancelledAt, this.cancelReason = '',
  });

  factory RestaurantOrder.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawItems = data['items'];
    final items = rawItems is List ? rawItems.whereType<Map>()
      .map((item) => OrderItem.fromMap(Map<String, dynamic>.from(item))).toList() : <OrderItem>[];
    DateTime? date(dynamic value) => value is Timestamp ? value.toDate() : null;
    return RestaurantOrder(
      id: doc.id,
      customerName: '${data['customerName'] ?? 'Walk-in'}',
      phone: '${data['phone'] ?? ''}',
      table: '${data['table'] ?? 'main'}',
      items: items,
      total: _toDouble(data['total']),
      status: OrderStatus.fromString('${data['status'] ?? 'pending'}'),
      note: '${data['note'] ?? ''}',
      source: '${data['source'] ?? 'online'}',
      createdAt: date(data['createdAt']),
      deliveredAt: date(data['deliveredAt']),
      cancelledAt: date(data['cancelledAt']),
      paymentMethod: PaymentMethod.fromString(data['paymentMethod'] as String?),
      cancelReason: '${data['cancelReason'] ?? ''}',
    );
  }
}

double _toDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
int _toInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 1;

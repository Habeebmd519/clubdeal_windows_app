import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  preparing,
  ready,
  delivered,
  cancelled;

  static OrderStatus fromString(String? value) {
    return OrderStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => OrderStatus.pending,
    );
  }
}

class OrderItem {
  final String name;
  final int qty;
  final double price;
  final String emoji;
  final String category;

  const OrderItem({
    required this.name,
    required this.qty,
    required this.price,
    this.emoji = '🍽️',
    this.category = '',
  });

  double get total => qty * price;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      name: '${map['name'] ?? ''}',
      qty: _toInt(map['qty']),
      price: _toDouble(map['price']),
      emoji: '${map['emoji'] ?? '🍽️'}',
      category: '${map['cat'] ?? map['category'] ?? ''}',
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'qty': qty,
        'price': price,
        'emoji': emoji,
        'cat': category,
      };
}

class RestaurantOrder {
  final String id;
  final String customerName;
  final String phone;
  final String table;
  final List<OrderItem> items;
  final double total;
  final OrderStatus status;
  final String note;
  final String source;
  final DateTime? createdAt;

  const RestaurantOrder({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.table,
    required this.items,
    required this.total,
    required this.status,
    required this.note,
    required this.source,
    required this.createdAt,
  });

  factory RestaurantOrder.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawItems = data['items'];

    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => OrderItem.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .toList()
        : <OrderItem>[];

    final timestamp = data['createdAt'];
    DateTime? createdAt;
    if (timestamp is Timestamp) {
      createdAt = timestamp.toDate();
    }

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
      createdAt: createdAt,
    );
  }
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 1;
}

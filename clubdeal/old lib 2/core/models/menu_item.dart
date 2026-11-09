import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItemModel {
  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final String emoji;
  final String tag;
  final bool isAvailable;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    required this.emoji,
    required this.tag,
    required this.isAvailable,
  });

  factory MenuItemModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final price = data['price'];

    return MenuItemModel(
      id: doc.id,
      name: '${data['name'] ?? ''}',
      price: price is num ? price.toDouble() : double.tryParse('$price') ?? 0,
      category: '${data['category'] ?? 'Other'}',
      description: '${data['description'] ?? ''}',
      emoji: '${data['emoji'] ?? '🍽️'}',
      tag: '${data['tag'] ?? ''}',
      isAvailable: data['isAvailable'] != false,
    );
  }
}

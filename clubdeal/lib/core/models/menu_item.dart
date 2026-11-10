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
  final double chickenGrams;
  final double friesGrams;

  const MenuItemModel({
    required this.id, required this.name, required this.price,
    required this.category, required this.description, required this.emoji,
    required this.tag, required this.isAvailable,
    this.chickenGrams = 0, this.friesGrams = 0,
  });

  factory MenuItemModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final usage = data['ingredientUsage'] is Map
        ? Map<String, dynamic>.from(data['ingredientUsage'] as Map)
        : <String, dynamic>{};
    double number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    return MenuItemModel(
      id: doc.id,
      name: '${data['name'] ?? ''}',
      price: number(data['price']),
      category: '${data['category'] ?? 'Other'}',
      description: '${data['description'] ?? ''}',
      emoji: '${data['emoji'] ?? '🍽️'}',
      tag: '${data['tag'] ?? ''}',
      isAvailable: data['isAvailable'] != false,
      chickenGrams: number(usage['chickenGrams']),
      friesGrams: number(usage['friesGrams']),
    );
  }
}

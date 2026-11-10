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
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    required this.emoji,
    required this.tag,
    required this.isAvailable,
    this.chickenGrams = 0,
    this.friesGrams = 0,
  });

  factory MenuItemModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final price = data['price'];
    final usage = data['ingredientUsage'];
    final ingredientUsage = usage is Map
        ? Map<String, dynamic>.from(usage)
        : <String, dynamic>{};
    final chicken =
        ingredientUsage['chickenGrams'] ?? data['chickenGrams'] ?? 0;
    final fries = ingredientUsage['friesGrams'] ?? data['friesGrams'] ?? 0;

    return MenuItemModel(
      id: doc.id,
      name: '${data['name'] ?? ''}',
      price: price is num ? price.toDouble() : double.tryParse('$price') ?? 0,
      category: '${data['category'] ?? 'Other'}',
      description: '${data['description'] ?? ''}',
      emoji: '${data['emoji'] ?? '🍽️'}',
      tag: '${data['tag'] ?? ''}',
      isAvailable: data['isAvailable'] != false,
      chickenGrams: chicken is num
          ? chicken.toDouble()
          : double.tryParse('$chicken') ?? 0,
      friesGrams: fries is num
          ? fries.toDouble()
          : double.tryParse('$fries') ?? 0,
    );
  }
}

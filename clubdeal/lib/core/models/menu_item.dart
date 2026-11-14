import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItemModel {
  final String id, name, category, description, emoji, tag;
  final double price, chickenGrams, friesGrams;
  final bool isAvailable;
  final List<Map<String, dynamic>> recipeLines;

  const MenuItemModel({
    required this.id, required this.name, required this.price,
    required this.category, required this.description, required this.emoji,
    required this.tag, required this.isAvailable,
    this.chickenGrams = 0, this.friesGrams = 0,
    this.recipeLines = const [],
  });

  factory MenuItemModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final usage = data['ingredientUsage'] is Map
        ? Map<String, dynamic>.from(data['ingredientUsage'] as Map)
        : <String, dynamic>{};
    double number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    final rawLines = data['recipeLines'];
    final lines = rawLines is List ? rawLines.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
    return MenuItemModel(
      id: doc.id, name: '${data['name'] ?? ''}', price: number(data['price']),
      category: '${data['category'] ?? 'Other'}',
      description: '${data['description'] ?? ''}', emoji: '${data['emoji'] ?? '🍽️'}',
      tag: '${data['tag'] ?? ''}', isAvailable: data['isAvailable'] != false,
      chickenGrams: number(usage['chickenGrams']),
      friesGrams: number(usage['friesGrams']), recipeLines: lines,
    );
  }
}

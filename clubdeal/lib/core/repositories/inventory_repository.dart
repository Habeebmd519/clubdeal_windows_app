import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ingredient_model.dart';
import '../models/recipe_model.dart';
import '../models/stock_movement_model.dart';

class InventoryRepository {
  InventoryRepository(this._db);
  final FirebaseFirestore _db;
  CollectionReference<Map<String, dynamic>> get _ingredients => _db.collection('ingredients');
  CollectionReference<Map<String, dynamic>> get _recipes => _db.collection('menu_recipes');
  CollectionReference<Map<String, dynamic>> get _movements => _db.collection('stock_movements');

  Stream<List<Ingredient>> watchIngredients() => _ingredients.orderBy('name').snapshots()
    .map((s) => s.docs.map((d) => Ingredient.fromMap(d.id, d.data())).toList());

  Stream<List<StockMovement>> watchMovements({String? ingredientId}) {
    Query<Map<String, dynamic>> q = _movements.orderBy('createdAt', descending: true).limit(500);
    if (ingredientId != null) q = q.where('ingredientId', isEqualTo: ingredientId);
    return q.snapshots().map((s) => s.docs.map((d) => StockMovement.fromMap(d.id, d.data())).toList());
  }

  Future<void> saveIngredient(Ingredient item) async {
    await _ingredients.doc(item.id).set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> createIngredient({required String name, required String unit,
    required String category, double lowStockThreshold = 0}) async {
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('Ingredient name is required.');
    final id = clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
    if (id.isEmpty) throw ArgumentError('Use a name containing letters or numbers.');
    final ref = _ingredients.doc(id);
    final existing = await ref.get();
    if (existing.exists) throw StateError('An ingredient with this name already exists.');
    await ref.set({
      'name': clean, 'baseUnit': unit, 'stockQuantity': 0.0,
      'averageUnitCost': 0.0, 'lowStockThreshold': lowStockThreshold,
      'category': category, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveRecipe(MenuRecipe recipe) => _recipes.doc(recipe.menuItemId)
    .set(recipe.toMap(), SetOptions(merge: true));

  Future<MenuRecipe?> getRecipe(String menuItemId) async {
    final d = await _recipes.doc(menuItemId).get();
    return d.exists ? MenuRecipe.fromMap(d.id, d.data()!) : null;
  }

  Future<void> setOpeningStock({required String ingredientId, required String name,
    required String unit, required double quantity}) async {
    if (quantity < 0) throw ArgumentError('Opening stock cannot be negative.');
    final ingredient = _ingredients.doc(ingredientId);
    final movement = _movements.doc();
    await _db.runTransaction((tx) async {
      tx.set(ingredient, {
        'name': name, 'baseUnit': unit, 'stockQuantity': quantity,
        'averageUnitCost': 0, 'openingStock': quantity,
        'openingAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      tx.set(movement, StockMovement(
        id: movement.id, ingredientId: ingredientId,
        type: StockMovementType.adjustment, quantity: quantity,
        unitCost: 0, createdAt: DateTime.now(),
      ).toMap()..['reason'] = 'Opening stock');
    });
  }

  Future<void> addStock({required String ingredientId, required double quantity,
    required double totalCost}) async {
    if (quantity <= 0 || totalCost < 0) throw ArgumentError('Enter a valid quantity and cost.');
    await recordPurchase(ingredientId: ingredientId, quantity: quantity,
      totalCost: totalCost, movementId: _movements.doc().id);
  }

  Future<void> recordPurchase({required String ingredientId, required double quantity,
    required double totalCost, required String movementId}) async {
    final ref = _ingredients.doc(ingredientId);
    final movement = _movements.doc(movementId);
    final expense = _db.collection('expenses').doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Ingredient not found. Create it first.');
      final data = snap.data()!;
      final oldQty = (data['stockQuantity'] as num? ?? 0).toDouble();
      final oldCost = (data['averageUnitCost'] as num? ?? 0).toDouble();
      final nextQty = oldQty + quantity;
      final average = nextQty <= 0 ? 0 : ((oldQty * oldCost) + totalCost) / nextQty;
      tx.update(ref, {'stockQuantity': nextQty, 'averageUnitCost': average});
      tx.set(movement, StockMovement(id: movement.id, ingredientId: ingredientId,
        type: StockMovementType.purchase, quantity: quantity,
        unitCost: quantity == 0 ? 0 : totalCost / quantity,
        createdAt: DateTime.now()).toMap());
      tx.set(expense, {
        'title': 'Stock purchase - ${data['name'] ?? ingredientId}',
        'amount': totalCost, 'type': 'purchase', 'category': 'Inventory',
        'ingredientId': ingredientId, 'quantity': quantity,
        'unit': data['baseUnit'] ?? 'g',
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'notes': 'Added from Inventory',
      });
    });
  }

  Future<void> adjustStock({required String ingredientId, required double countedQuantity,
    required String reason}) async {
    if (countedQuantity < 0 || reason.trim().isEmpty) throw ArgumentError('Enter a valid count and reason.');
    final ref = _ingredients.doc(ingredientId);
    final movement = _movements.doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Ingredient not found.');
      final old = (snap.data()?['stockQuantity'] as num? ?? 0).toDouble();
      final delta = countedQuantity - old;
      tx.update(ref, {'stockQuantity': countedQuantity, 'lastCountAt': FieldValue.serverTimestamp()});
      tx.set(movement, StockMovement(id: movement.id, ingredientId: ingredientId,
        type: StockMovementType.adjustment, quantity: delta.abs(), unitCost: 0,
        createdAt: DateTime.now()).toMap()..addAll({'reason': reason.trim(), 'direction': delta >= 0 ? 'in' : 'out', 'balanceAfter': countedQuantity}));
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ingredient_model.dart';
import '../models/recipe_model.dart';
import '../models/stock_movement_model.dart';

class InventoryRepository {
  InventoryRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _ingredients =>
      _db.collection('ingredients');

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _db.collection('menu_recipes');

  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stock_movements');

  // WATCH ALL STOCK ITEMS
  Stream<List<Ingredient>> watchIngredients() {
    return _ingredients
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Ingredient.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // WATCH STOCK MOVEMENTS
  Stream<List<StockMovement>> watchMovements({String? ingredientId}) {
    Query<Map<String, dynamic>> query = _movements
        .orderBy('createdAt', descending: true)
        .limit(500);

    if (ingredientId != null) {
      query = query.where('ingredientId', isEqualTo: ingredientId);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => StockMovement.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  // SAVE INGREDIENT
  Future<void> saveIngredient(Ingredient item) async {
    await _ingredients.doc(item.id).set(item.toMap(), SetOptions(merge: true));
  }

  // CREATE INGREDIENT
  Future<void> createIngredient({
    required String name,
    required String unit,
    required String category,
    double lowStockThreshold = 0,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw ArgumentError('Ingredient name is required.');
    }

    final id = cleanName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (id.isEmpty) {
      throw ArgumentError('Use a name containing letters or numbers.');
    }

    final ingredientRef = _ingredients.doc(id);
    final existing = await ingredientRef.get();

    if (existing.exists) {
      throw StateError('An ingredient with this name already exists.');
    }

    await ingredientRef.set({
      'name': cleanName,
      'baseUnit': unit,
      'stockQuantity': 0.0,
      'averageUnitCost': 0.0,
      'lowStockThreshold': lowStockThreshold,
      'category': category,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // SAVE MENU RECIPE
  Future<void> saveRecipe(MenuRecipe recipe) async {
    await _recipes
        .doc(recipe.menuItemId)
        .set(recipe.toMap(), SetOptions(merge: true));
  }

  // GET MENU RECIPE
  Future<MenuRecipe?> getRecipe(String menuItemId) async {
    final doc = await _recipes.doc(menuItemId).get();

    if (!doc.exists) return null;

    return MenuRecipe.fromMap(doc.id, doc.data()!);
  }

  // SET OPENING STOCK
  Future<void> setOpeningStock({
    required String ingredientId,
    required String name,
    required String unit,
    required double quantity,
  }) async {
    if (quantity < 0) {
      throw ArgumentError('Opening stock cannot be negative.');
    }

    final ingredientRef = _ingredients.doc(ingredientId);
    final movementRef = _movements.doc();

    await _db.runTransaction((transaction) async {
      transaction.set(ingredientRef, {
        'name': name,
        'baseUnit': unit,
        'stockQuantity': quantity,
        'averageUnitCost': 0,
        'openingStock': quantity,
        'openingAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(
        movementRef,
        StockMovement(
          id: movementRef.id,
          ingredientId: ingredientId,
          type: StockMovementType.adjustment,
          quantity: quantity,
          unitCost: 0,
          createdAt: DateTime.now(),
        ).toMap()..['reason'] = 'Opening stock',
      );
    });
  }

  // ADD STOCK
  Future<void> addStock({
    required String ingredientId,
    required double quantity,
    required double totalCost,
  }) async {
    if (quantity <= 0 || totalCost < 0) {
      throw ArgumentError('Enter a valid quantity and cost.');
    }

    await recordPurchase(
      ingredientId: ingredientId,
      quantity: quantity,
      totalCost: totalCost,
      movementId: _movements.doc().id,
    );
  }

  // RECORD STOCK PURCHASE + AUTOMATIC EXPENSE
  Future<void> recordPurchase({
    required String ingredientId,
    required double quantity,
    required double totalCost,
    required String movementId,
    String supplier = '',
    String notes = '',
    DateTime? purchasedAt,
  }) async {
    if (quantity <= 0 || totalCost < 0) {
      throw ArgumentError('Enter a valid quantity and cost.');
    }

    final purchaseDate = purchasedAt ?? DateTime.now();

    final ingredientRef = _ingredients.doc(ingredientId);
    final movementRef = _movements.doc(movementId);
    final expenseRef = _db.collection('expenses').doc();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ingredientRef);

      if (!snapshot.exists) {
        throw StateError('Ingredient not found. Create it first.');
      }

      final data = snapshot.data()!;

      final oldQuantity = (data['stockQuantity'] as num? ?? 0).toDouble();

      final oldAverageCost = (data['averageUnitCost'] as num? ?? 0).toDouble();

      final newQuantity = oldQuantity + quantity;

      final newAverageCost =
          ((oldQuantity * oldAverageCost) + totalCost) / newQuantity;

      // UPDATE STOCK
      transaction.update(ingredientRef, {
        'stockQuantity': newQuantity,
        'averageUnitCost': newAverageCost,
      });

      // SAVE STOCK MOVEMENT
      transaction.set(
        movementRef,
        StockMovement(
          id: movementRef.id,
          ingredientId: ingredientId,
          type: StockMovementType.purchase,
          quantity: quantity,
          unitCost: totalCost / quantity,
          createdAt: purchaseDate,
        ).toMap()..addAll({'supplier': supplier, 'note': notes}),
      );

      // AUTOMATICALLY CREATE EXPENSE
      transaction.set(expenseRef, {
        'title': 'Purchase (${data['name'] ?? ingredientId})',
        'amount': totalCost,
        'type': 'purchase',
        'category': 'Inventory',
        'ingredientId': ingredientId,
        'quantity': quantity,
        'unit': data['baseUnit'] ?? 'g',
        'createdAt': Timestamp.fromDate(purchaseDate),
        'supplier': supplier,
        'notes': notes.isEmpty ? 'Added from Stock Management' : notes,
      });
    });
  }

  // CONSUME STOCK
  Future<void> consumeStock({
    required String ingredientId,
    required double quantity,
    required String reason,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be above zero.');
    }

    final ingredientRef = _ingredients.doc(ingredientId);
    final movementRef = _movements.doc();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ingredientRef);

      if (!snapshot.exists) {
        throw StateError('Stock item not found.');
      }

      final oldQuantity = (snapshot.data()?['stockQuantity'] as num? ?? 0)
          .toDouble();

      if (quantity > oldQuantity) {
        throw StateError('Not enough stock. Available: $oldQuantity.');
      }

      final remainingQuantity = oldQuantity - quantity;

      transaction.update(ingredientRef, {'stockQuantity': remainingQuantity});

      transaction.set(
        movementRef,
        StockMovement(
            id: movementRef.id,
            ingredientId: ingredientId,
            type: StockMovementType.consumption,
            quantity: quantity,
            unitCost: 0,
            createdAt: DateTime.now(),
          ).toMap()
          ..addAll({'reason': reason, 'balanceAfter': remainingQuantity}),
      );
    });
  }

  // ADJUST STOCK
  Future<void> adjustStock({
    required String ingredientId,
    required double countedQuantity,
    required String reason,
  }) async {
    if (countedQuantity < 0 || reason.trim().isEmpty) {
      throw ArgumentError('Enter a valid count and reason.');
    }

    final ingredientRef = _ingredients.doc(ingredientId);
    final movementRef = _movements.doc();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ingredientRef);

      if (!snapshot.exists) {
        throw StateError('Ingredient not found.');
      }

      final oldQuantity = (snapshot.data()?['stockQuantity'] as num? ?? 0)
          .toDouble();

      final difference = countedQuantity - oldQuantity;

      transaction.update(ingredientRef, {
        'stockQuantity': countedQuantity,
        'lastCountAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        movementRef,
        StockMovement(
          id: movementRef.id,
          ingredientId: ingredientId,
          type: StockMovementType.adjustment,
          quantity: difference.abs(),
          unitCost: 0,
          createdAt: DateTime.now(),
        ).toMap()..addAll({
          'reason': reason.trim(),
          'direction': difference >= 0 ? 'in' : 'out',
          'balanceAfter': countedQuantity,
        }),
      );
    });
  }
}

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

  Future<void> saveIngredient(Ingredient item) async =>
    _ingredients.doc(item.id).set(item.toMap(), SetOptions(merge: true));

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

  Future<void> recordPurchase({
    required String ingredientId, required double quantity,
    required double totalCost, required String movementId,
  }) async {
    final ref = _ingredients.doc(ingredientId);
    final movement = _movements.doc(movementId);
    final expense = _db.collection('expenses').doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Ingredient not found. Set opening stock first.');
      final data = snap.data()!;
      final oldQty = (data['stockQuantity'] as num? ?? 0).toDouble();
      final oldCost = (data['averageUnitCost'] as num? ?? 0).toDouble();
      final nextQty = oldQty + quantity;
      final average = nextQty <= 0 ? 0 : ((oldQty * oldCost) + totalCost) / nextQty;
      tx.update(ref, {'stockQuantity': nextQty, 'averageUnitCost': average});
      tx.set(movement, StockMovement(
        id: movement.id, ingredientId: ingredientId,
        type: StockMovementType.purchase, quantity: quantity,
        unitCost: quantity == 0 ? 0 : totalCost / quantity,
        createdAt: DateTime.now(),
      ).toMap());
      // Stock purchases also appear in Expenses automatically, avoiding
      // a second manual entry and keeping the daily dashboard in sync.
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
}

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

  Future<void> saveIngredient(Ingredient item) async {
    await _ingredients.doc(item.id).set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> saveRecipe(MenuRecipe recipe) => _recipes.doc(recipe.menuItemId)
    .set(recipe.toMap(), SetOptions(merge: true));

  Future<MenuRecipe?> getRecipe(String menuItemId) async {
    final d = await _recipes.doc(menuItemId).get();
    return d.exists ? MenuRecipe.fromMap(d.id, d.data()!) : null;
  }

  Future<void> recordPurchase({
    required String ingredientId, required double quantity,
    required double totalCost, required String movementId,
  }) async {
    final ref = _ingredients.doc(ingredientId);
    final movement = _movements.doc(movementId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Ingredient not found');
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
    });
  }
}

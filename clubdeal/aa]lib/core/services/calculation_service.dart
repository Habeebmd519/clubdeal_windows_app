import '../models/ingredient_model.dart';
import '../models/recipe_model.dart';

class CalculationService {
  double recipeCost(MenuRecipe recipe, Map<String, Ingredient> ingredients) {
    var total = 0.0;
    for (final line in recipe.lines) {
      final ingredient = ingredients[line.ingredientId];
      if (ingredient != null)
        total += line.quantity * ingredient.averageUnitCost;
    }
    return total;
  }

  double netProfit({
    required double sales,
    required double consumedIngredientCost,
    required double operatingExpenses,
  }) => sales - consumedIngredientCost - operatingExpenses;
}

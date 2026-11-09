# Clubdeal library upgrade package

This ZIP preserves the uploaded `lib/` files and adds the first-pass expense,
inventory, costing, reporting, and audio foundations. It is an integration
starter, not a verified drop-in replacement: the existing order/menu schema
and desktop navigation must be checked in the actual application.

## Dependencies

From the Flutter project root:

```bash
flutter pub add fl_chart
flutter pub add audioplayers
flutter pub get
```

`fl_chart` is included for the next chart UI phase. The current starter screens
do not require it yet.

## Asset

Create `assets/sound/alert.mp3`, then add to `pubspec.yaml`:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/sound/alert.mp3
```

## New Firestore collections

The new code uses these collections and does not modify existing `orders` or
menu collections:

- `expenses`
- `ingredients`
- `menu_recipes`
- `stock_movements`

Suggested fields are represented in the model `toMap()` methods.

## Integration steps

1. Merge this `lib/` directory into your existing project (make a backup first).
2. Add `ExpenseRepository` and `ExpenseBloc` to your app's dependency/provider setup.
3. Add `InventoryRepository` and `InventoryBloc` when the inventory screen is wired.
4. Add `ExpensePage` to the desktop navigation.
5. Add `AddExpensePage` from an Add button.
6. Configure Firestore security rules for the new collections before production.
7. Create any required composite indexes when Firestore reports them.

## Accounting notes

Purchase spend is not the same as consumed ingredient cost. `ReportRepository`
currently reports purchase spend and operating expenses; it deliberately sets
consumption cost to zero until recipe deductions are implemented against your
actual order item schema. Do not present the resulting net profit as final
accounting profit yet.

## Performance

- BLoC owns Firestore subscriptions and cancels them in `close()`.
- Expense list is restricted to one day and ordered by timestamp.
- Avoid subscribing to all historical orders for dashboard totals.
- Add pagination to historical lists before production-scale data grows.
- Add idempotency (order ID + recipe deduction marker) before automatic stock
  deduction, so reconnects/retries cannot consume stock twice.

## Compatibility warning

The uploaded source did not include the complete app root, Firestore rules,
actual menu/order document examples, or the current desktop navigation wiring.
Check imports and run `flutter analyze` after merging. The report's sales field
fallbacks (`total` / `totalAmount`) may need to be adapted to the actual
`RestaurantOrder` schema.

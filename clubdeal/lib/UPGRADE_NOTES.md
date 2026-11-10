# Clubdeal integration notes

This upgrade preserves the existing Dashboard, Orders, Menu, Settings, Firebase setup,
and current Firestore collections.

## Added integration
- Registers ExpenseRepository / ExpenseBloc and InventoryRepository / InventoryBloc.
- Adds Expenses (F5) and Inventory (F6) to the desktop sidebar.
- Adds a basic ingredient stock overview.
- Adds an Add Expense action to the Expenses page.

## Firestore collections used by the existing foundation
- `orders` (existing)
- `menu2` (existing)
- `expenses` (new expense records)
- `ingredients` (ingredient stock records)
- `menu_recipes` (recipe definitions)
- `stock_movements` (inventory movement history)

## Important safety boundary
This integration does NOT automatically deduct ingredient stock when an order arrives.
It also does NOT claim a complete profit figure: recipe-to-menu mapping, unit conversions,
order lifecycle rules, and historical corrections must be confirmed against the live
Firestore documents before stock deduction or cost-of-goods calculations are enabled.
No existing order/menu documents are modified by this UI integration.

Before production:
1. Verify Firestore security rules allow the intended users to read/write the new collections.
2. Confirm ingredient quantities use consistent base units (for example, grams).
3. Confirm each recipe document ID matches the corresponding `menu2` document ID.
4. Implement idempotent stock deduction using a transaction and a unique order/ingredient movement key.
5. Add and verify required Firestore indexes if Firebase reports a missing-index error.

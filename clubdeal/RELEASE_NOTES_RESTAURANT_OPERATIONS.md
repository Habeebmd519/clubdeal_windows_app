# Clubdeal Restaurant Operations Update

This update is isolated on the `feature/restaurant-operations` branch. The existing `main` branch and its current working version are unchanged.

## Included in this update

- Order editing for active orders: customer, phone, table/token, note and item quantities.
- Order cancellation with a recorded reason.
- Kitchen receives a revised ticket after an order edit and a cancellation notice after an order is cancelled.
- New orders continue to trigger the automatic kitchen ticket when automatic printing is enabled.
- When an order is ready, the cashier chooses Cash, Card or Online / UPI, confirms payment, and Clubdeal marks the order delivered.
- Customer bill is printed after payment is saved; bills can also be reprinted manually.
- Dashboard shows today's order count, active orders, cash/card/online collections, total income, expenses and income after expenses.
- Opening cash float can be recorded for the current business date.
- Inventory supports opening quantities for Chicken and Fries, adding purchases, and showing live stock balances.
- Stock purchases are also entered in Expenses automatically.
- Recipe usage from the existing `menu2.ingredientUsage` fields is deducted once when an order is delivered. The order stores an `inventoryDeducted` marker to avoid duplicate deduction on repeated updates.
- Replaced the obsolete counter widget test with a currency-format test.
- Windows build workflow runs on pushes to this feature branch as well as manual dispatch.

## Firestore collections and fields

Existing collections retained:
- `orders`
- `menu2`
- `expenses`
- `app_confige`

Inventory collections used:
- `ingredients` — document IDs `chicken` and `fries`, fields include `name`, `baseUnit`, `stockQuantity`, `averageUnitCost`, `openingStock`.
- `stock_movements` — opening adjustments, purchases and recipe consumption.
- `menu_recipes` remains available for the earlier inventory repository, but this delivery reads the existing recipe quantities from `menu2.ingredientUsage`.

New collection:
- `cash_sessions` — daily opening cash float, document ID `YYYYMMDD`, field `openingCash`.

Orders gain optional fields:
- `paymentMethod`: `cash`, `card`, or `online`
- `deliveredAt`, `cancelledAt`, `cancelReason`
- `inventoryDeducted`

Old orders without payment fields remain readable. Their payment totals are not guessed or assigned a payment method.

## Firestore rules

Add access for the new `cash_sessions` collection to the rules currently deployed in Firebase. The app also needs the existing inventory permissions for `ingredients` and `stock_movements`, plus read/write access to `orders`, `menu2` and `expenses`.

Do not deploy public `allow read, write: if true` rules to production. Use Firebase Authentication and owner/staff role checks before using real customer or sales data.

## Important operating notes

1. Set opening stock for Chicken and Fries before delivering orders that use those ingredients. Clubdeal blocks delivery if a recipe needs an ingredient whose stock record has not been initialized.
2. Keep menu ingredient quantities in grams in `menu2.ingredientUsage.chickenGrams` and `friesGrams`.
3. Dashboard payment totals include orders recorded as delivered with a payment method. Historical orders without a payment method are intentionally not classified.
4. Opening cash + cash sales is a calculated counter estimate. It does not subtract cash expenses because expense payment method is not yet recorded separately.
5. Automatic KOT and bill printing still require the VEER B41 to be installed and selected as a Windows printer. Always test a real receipt and kitchen ticket on the target PC.

## Verification still required before production

- Run `flutter pub get`, `flutter analyze`, `flutter test` and `flutter build windows --release` from `clubdeal/`.
- Verify Firebase rules and Firestore indexes against the actual project.
- Test order creation, edit, cancellation, payment and duplicate delivery.
- Test stock deduction with known menu recipes and check that retrying delivery does not deduct twice.
- Test kitchen ticket, cancellation ticket and customer bill on the actual VEER B41 printer.
- Reconcile the dashboard against the physical cash drawer and card/UPI settlement reports for a test day.

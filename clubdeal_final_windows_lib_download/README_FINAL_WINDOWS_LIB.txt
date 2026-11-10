CLUB DEAL — UPDATED WINDOWS LIB
================================

Included improvements
---------------------
1. Manual Order popup:
   - Search menu items by item name, category, or tag.
   - Live filtering while typing, with a clear-search button.
   - Quantity controls continue to work while the list is filtered.

2. New order alerts and automatic printing:
   - Plays the configured new-order alert sound when Firestore delivers newly
     created order IDs after the initial order snapshot.
   - Automatically submits each newly detected order to the selected Windows
     printer when "Automatically print new orders" is enabled (enabled by
     default).
   - Existing order history is deliberately not batch-printed at app startup.
   - New order IDs are tracked during the current app session to avoid
     duplicate printing on ordinary subsequent Firestore snapshots.

3. Order cards:
   - Active Orders and All Orders cards expand/collapse when tapped.
   - Expanded cards show every ordered item, quantity, line total, customer
     details and note (where available).
   - Print Bill is available directly on the card and in its expanded details.

4. Windows printer settings:
   - Lists printers installed in Windows.
   - Remembers selected printer and auto-print preference using the existing
     shared_preferences dependency.
   - Refreshes printer list and provides a test receipt.
   - Uses the Windows GDI print pipeline via PowerShell/.NET System.Drawing.
     This relies on the installed Windows printer driver. It is not a raw
     ESC/POS USB implementation.

POS58 / USB SETUP
-----------------
1. Connect the POS58 by USB.
2. Install the correct Windows driver supplied by the printer manufacturer.
3. Confirm the printer appears in Windows Settings > Bluetooth & devices >
   Printers & scanners (or Control Panel > Devices and Printers).
4. Open Club Deal > Settings > Printer and press Refresh.
5. Select the installed POS58 printer, leave automatic printing enabled if
   desired, and press Test Print.
6. In Windows printer preferences, set the correct 58mm roll/paper size and
   cut/feed options supported by your driver.

IMPORTANT PRINTING NOTES
------------------------
- A USB device appearing in Device Manager is not sufficient by itself. The
  printer must also be installed as a Windows printer queue with a working
  driver.
- The print service submits jobs through the Windows spooler. A success
  message means Windows accepted the job; it cannot prove that paper physically
  came out. Check the queue, cable, paper, printer status and driver if it
  does not print.
- Automatic printing begins after the first Firestore snapshot has loaded.
  Orders already present in that initial snapshot are not automatically
  printed, to prevent a large reprint after every app restart.
- If the app is closed, it cannot receive orders or print them.
- Automatic printing is session-deduplicated. For durable exactly-once
  printing across crashes/restarts, a server-side print-job queue or a
  Firestore printedAt/print-status transaction is required.

BUILD
-----
This archive contains the updated lib folder, not the complete Flutter
project. Keep your existing pubspec.yaml, windows/, assets/, Firebase setup
and other project files.

The source uses dependencies already present in the supplied codebase:
cloud_firestore, flutter_bloc, intl, audioplayers, shared_preferences and
file_picker. No new pubspec dependency was added.

From the root of your existing Flutter project:
  flutter pub get
  dart format lib
  flutter analyze
  flutter build windows

Run flutter analyze and test on the target Windows PC before replacing the
production app. A successful Flutter build could not be run in this sandbox
because the Flutter/Dart SDK and the complete project were not provided.

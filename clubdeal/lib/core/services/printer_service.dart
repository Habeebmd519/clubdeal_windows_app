import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';

class WindowsPrinter {
  final String name;
  final bool isDefault;
  const WindowsPrinter(this.name, {this.isDefault = false});
}

/// Uses the Windows-installed printer driver. The POS58 should be installed
/// in Windows first; USB printers are not Bluetooth devices in this workflow.
class PrinterService extends ChangeNotifier {
  PrinterService() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadPreferences();
    await refreshPrinters();
  }

  static const _printerKey = 'clubdeal_windows_printer_name';
  static const _autoPrintKey = 'clubdeal_auto_print_new_orders';

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      selectedPrinterName = prefs.getString(_printerKey);
      autoPrintNewOrders = prefs.getBool(_autoPrintKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Continue with defaults if preferences are unavailable.
    }
  }

  List<WindowsPrinter> printers = const [];
  String? selectedPrinterName;
  bool isLoading = false;
  bool autoPrintNewOrders = true;
  String? lastError;

  bool get isConnected =>
      selectedPrinterName != null &&
      printers.any((p) => p.name == selectedPrinterName);

  Future<void> refreshPrinters() async {
    if (!Platform.isWindows) {
      printers = const [];
      lastError =
          'Windows printing is available only in the Windows desktop build.';
      notifyListeners();
      return;
    }
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      const script = r'''
$ErrorActionPreference = 'Stop'
try {
  $items = @(Get-CimInstance Win32_Printer | ForEach-Object {
    [PSCustomObject]@{ name = $_.Name; isDefault = [bool]$_.Default }
  })
  ConvertTo-Json -InputObject $items -Compress
} catch {
  Add-Type -AssemblyName System.Drawing
  $items = @()
  foreach ($name in [System.Drawing.Printing.PrinterSettings]::InstalledPrinters) {
    $items += [PSCustomObject]@{ name = [string]$name; isDefault = $false }
  }
  ConvertTo-Json -InputObject $items -Compress
}
''';
      final result = await _runPowerShell(script);
      final output = result.stdout.toString().trim();
      final decoded = output.isEmpty ? <dynamic>[] : jsonDecode(output);
      final rows = decoded is List ? decoded : [decoded];
      printers =
          rows
              .whereType<Map>()
              .map(
                (row) => WindowsPrinter(
                  '${row['name'] ?? ''}',
                  isDefault: row['isDefault'] == true,
                ),
              )
              .where((p) => p.name.isNotEmpty)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      if (selectedPrinterName == null ||
          !printers.any((p) => p.name == selectedPrinterName)) {
        final defaults = printers.where((p) => p.isDefault);
        selectedPrinterName = defaults.isNotEmpty
            ? defaults.first.name
            : (printers.isNotEmpty ? printers.first.name : null);
        if (selectedPrinterName != null) {
          SharedPreferences.getInstance().then(
            (prefs) => prefs.setString(_printerKey, selectedPrinterName!),
          );
        }
      }
      if (printers.isEmpty) {
        lastError = 'No Windows printers found. Install the printer driver and reconnect it.';
      }
    } catch (e) {
      lastError = 'Could not list Windows printers: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectPrinter(String? name) {
    selectedPrinterName = name;
    lastError = null;
    notifyListeners();
    SharedPreferences.getInstance().then((prefs) {
      if (name == null) {
        prefs.remove(_printerKey);
      } else {
        prefs.setString(_printerKey, name);
      }
    });
  }

  void setAutoPrintNewOrders(bool enabled) {
    autoPrintNewOrders = enabled;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setBool(_autoPrintKey, enabled),
    );
  }

  Future<void> testPrint() async {
    final name = selectedPrinterName;
    if (name == null || !isConnected) {
      throw StateError('Select an installed Windows printer first.');
    }
    await _printLines(name, [
      'CLUB DEAL',
      'PRINTER TEST',
      '------------------------------',
      'POS printer is connected.',
      'Test print successful.',
      DateTime.now().toString(),
      '',
      '',
    ]);
  }

  Future<void> printKitchenTicket(RestaurantOrder order, {bool revised = false}) async {
    final name = selectedPrinterName;
    if (name == null || !isConnected) {
      throw StateError('Select an installed Windows printer in Settings.');
    }
    final lines = <String>[
      'CLUB DEAL - KITCHEN',
      revised ? 'UPDATED KITCHEN TICKET' : 'KITCHEN ORDER TICKET',
      '------------------------------',
      'Order: ${order.id}',
      'Table / Token: ${order.table}',
      'Customer: ${order.customerName}',
      if (order.createdAt != null) 'Time: ${order.createdAt}',
      '------------------------------',
      ...order.items.map((item) => '${item.qty} x ${item.name}'),
      if (order.note.trim().isNotEmpty) ...['------------------------------', 'NOTE: ${order.note}'],
      '------------------------------',
      '', '',
    ];
    await _printLines(name, lines);
  }

  Future<void> printCancellationTicket(RestaurantOrder order, String reason) async {
    final name = selectedPrinterName;
    if (name == null || !isConnected) return;
    await _printLines(name, [
      '*** ORDER CANCELLED ***',
      'Order: ${order.id}',
      'Table / Token: ${order.table}',
      'Customer: ${order.customerName}',
      'Reason: $reason',
      'Do not prepare this order.',
      '', '',
    ]);
  }

  Future<void> printOrder(RestaurantOrder order, {PaymentMethod? paymentMethod}) async {
    final name = selectedPrinterName;
    if (name == null || !isConnected) {
      throw StateError('Select an installed Windows printer in Settings.');
    }
    final lines = <String>[
      'CLUB DEAL',
      'ORDER BILL',
      '------------------------------',
      'Order: ${order.id}',
      'Customer: ${order.customerName}',
      if (order.phone.isNotEmpty) 'Phone: ${order.phone}',
      'Table: ${order.table}',
      'Status: ${paymentMethod != null || order.paymentMethod != null ? 'PAID' : order.status.name.toUpperCase()}',
      if (order.createdAt != null) 'Date: ${order.createdAt}',
      '------------------------------',
      'ITEM             QTY       AMT',
      ...order.items.map(
        (item) =>
            '${item.name}  x${item.qty}  Rs.${item.total.toStringAsFixed(2)}',
      ),
      '------------------------------',
      'TOTAL: Rs.${order.total.toStringAsFixed(2)}',
      if (paymentMethod != null) 'PAID BY: ${paymentMethod.name.toUpperCase()}',
      if (order.paymentMethod != null && paymentMethod == null) 'PAID BY: ${order.paymentMethod!.name.toUpperCase()}',
      if (order.note.trim().isNotEmpty) 'Note: ${order.note}',
      '',
      'Thank you!',
      '',
      '',
    ];
    await _printLines(name, lines);
  }

  Future<void> _printLines(String printerName, List<String> lines) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Printing is supported in the Windows desktop app.',
      );
    }
    final payload = base64Encode(utf8.encode(jsonEncode(lines)));
    final printer = base64Encode(utf8.encode(printerName));
    final script =
        r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$printerName = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__PRINTER__'))
$lines = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__LINES__')) | ConvertFrom-Json
$doc = New-Object System.Drawing.Printing.PrintDocument
$doc.PrinterSettings.PrinterName = $printerName
if (-not $doc.PrinterSettings.IsValid) { throw "Printer not available: $printerName" }
$doc.DocumentName = 'Club Deal Receipt'
$doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(8,8,8,8)
$script:receiptLines = @($lines)
$doc.add_PrintPage({
  param($sender, $e)
  $font = New-Object System.Drawing.Font('Consolas', 8)
  $y = 8
  foreach ($line in $script:receiptLines) {
    $e.Graphics.DrawString([string]$line, $font, [System.Drawing.Brushes]::Black, 5, $y)
    $y += 14
  }
  $font.Dispose()
  $e.HasMorePages = $false
})
$doc.Print()
$doc.Dispose()
Write-Output 'PRINT_SUBMITTED'
'''
            .replaceAll('__PRINTER__', printer)
            .replaceAll('__LINES__', payload);
    try {
      final result = await _runPowerShell(script);
      if (!result.stdout.toString().contains('PRINT_SUBMITTED')) {
        throw StateError(
          result.stderr.toString().trim().isEmpty
              ? 'Windows did not confirm the print job.'
              : result.stderr.toString().trim(),
        );
      }
      lastError = null;
    } catch (e) {
      lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<ProcessResult> _runPowerShell(String script) async {
    final units = script.codeUnits;
    final utf16le = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      utf16le[i * 2] = units[i] & 0xff;
      utf16le[i * 2 + 1] = (units[i] >> 8) & 0xff;
    }
    final encoded = base64Encode(utf16le);
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      encoded,
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell.exe',
        const [],
        '${result.stderr}'.trim().isEmpty
            ? '${result.stdout}'.trim()
            : '${result.stderr}'.trim(),
        result.exitCode,
      );
    }
    return result;
  }
}

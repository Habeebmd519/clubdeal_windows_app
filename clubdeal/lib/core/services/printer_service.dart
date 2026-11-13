import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:qr/qr.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';

class WindowsPrinter {
  final String name;
  final bool isDefault;
  const WindowsPrinter(this.name, {this.isDefault = false});
}

class PrinterService extends ChangeNotifier {
  PrinterService() {
    _initialize();
  }
  static const _printerKey = 'clubdeal_windows_printer_name';
  static const _autoPrintKey = 'clubdeal_auto_print_new_orders';
  List<WindowsPrinter> printers = const [];
  String? selectedPrinterName;
  bool isLoading = false;
  bool autoPrintNewOrders = true;
  String? lastError;
  bool get isConnected =>
      selectedPrinterName != null &&
      printers.any((p) => p.name == selectedPrinterName);

  Future<void> _initialize() async {
    await _loadPreferences();
    await refreshPrinters();
  }

  Future<void> _loadPreferences() async {
    try {
      final p = await SharedPreferences.getInstance();
      selectedPrinterName = p.getString(_printerKey);
      autoPrintNewOrders = p.getBool(_autoPrintKey) ?? true;
      notifyListeners();
    } catch (_) {}
  }

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
                (r) => WindowsPrinter(
                  r['name']?.toString() ?? '',
                  isDefault: r['isDefault'] == true,
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
            (p) => p.setString(_printerKey, selectedPrinterName!),
          );
        }
      }
      if (printers.isEmpty) lastError = 'No Windows printers found. Install the printer driver and reconnect it.';
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
    SharedPreferences.getInstance().then((p) {
      if (name == null) {
        p.remove(_printerKey);
      } else {
        p.setString(_printerKey, name);
      }
    });
  }

  void setAutoPrintNewOrders(bool enabled) {
    autoPrintNewOrders = enabled;
    notifyListeners();
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_autoPrintKey, enabled),
    );
  }

  String _requirePrinter() {
    final name = selectedPrinterName;
    if (name == null || !isConnected)
      throw StateError('Select an installed Windows printer in Settings.');
    return name;
  }

  Future<void> testPrint() => _printTextTicket(_requirePrinter(), [
    'CLUB DEAL',
    '58MM PRINTER TEST',
    '------------------------------',
    'Printer connection is working.',
    DateTime.now().toString(),
    '',
    '',
  ], 'Club Deal Printer Test');

  Future<void> printKitchenTicket(
    RestaurantOrder order, {
    bool revised = false,
  }) async {
    final lines = <String>[
      'CLUB DEAL - KITCHEN',
      revised ? 'UPDATED KITCHEN TICKET' : 'KITCHEN ORDER TICKET',
      '------------------------------',
      'Order: ' + order.id,
      'Table / Token: ' + order.table,
      'Customer: ' + order.customerName,
      if (order.createdAt != null)
        'Time: ' + order.createdAt!.toLocal().toString(),
      '------------------------------',
      ...order.items.map((i) => i.qty.toString() + ' x ' + i.name),
      if (order.note.trim().isNotEmpty) 'NOTE: ' + order.note,
      '------------------------------',
      '',
      '',
    ];
    await _printTextTicket(_requirePrinter(), lines, 'Club Deal Kitchen');
  }

  Future<void> printCancellationTicket(
    RestaurantOrder order,
    String reason,
  ) async {
    final name = selectedPrinterName;
    if (name == null || !isConnected) return;
    await _printTextTicket(name, [
      '*** ORDER CANCELLED ***',
      'Order: ' + order.id,
      'Table / Token: ' + order.table,
      'Customer: ' + order.customerName,
      'Reason: ' + reason,
      'DO NOT PREPARE THIS ORDER.',
      '',
      '',
    ], 'Club Deal Cancellation');
  }

  /// UPI QR encodes the exact order total as a fixed payment amount.
  Future<void> printOrder(
    RestaurantOrder order, {
    PaymentMethod? paymentMethod,
  }) async {
    final printer = _requirePrinter();
    final vpa = await _loadPaymentVpa();
    List<List<bool>>? matrix;
    if (vpa != null && order.total > 0) {
      final uri = Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: {
          'pa': vpa,
          'pn': 'Club Deal',
          'am': order.total.toStringAsFixed(2),
          'cu': 'INR',
          'tn': 'Club Deal order ' + order.id,
          'tr': order.id,
        },
      ).toString();
      final code = QrCode.fromData(
        data: uri,
        errorCorrectLevel: QrErrorCorrectLevel.M,
      );
      final image = QrImage(code);
      matrix = List.generate(
        image.moduleCount,
        (r) => List.generate(image.moduleCount, (c) => image.isDark(r, c)),
      );
    }
    final date = order.createdAt?.toLocal() ?? DateTime.now();
    final paidBy = paymentMethod ?? order.paymentMethod;
    await _printReceipt(printer, {
      'kind': 'bill',
      'restaurant': 'CLUB DEAL',
      'tagline': 'FRESH & FIRED UP',
      'billNo': order.id,
      'date':
          date.day.toString().padLeft(2, '0') +
          '/' +
          date.month.toString().padLeft(2, '0') +
          '/' +
          date.year.toString(),
      'time':
          date.hour.toString().padLeft(2, '0') +
          ':' +
          date.minute.toString().padLeft(2, '0'),
      'customer': order.customerName,
      'phone': order.phone,
      'table': order.table,
      'items': order.items
          .map(
            (i) => <String, dynamic>{
              'name': i.name,
              'qty': i.qty,
              'price': i.price,
              'total': i.total,
            },
          )
          .toList(),
      'subtotal': order.total,
      'discount': 0,
      'total': order.total,
      'status': paidBy != null ? 'PAID' : order.status.name.toUpperCase(),
      'payment': paidBy?.name.toUpperCase() ?? 'PAYMENT DUE',
      'note': order.note,
      'vpa': vpa ?? '',
      'qr': matrix,
      'upiAmount': order.total.toStringAsFixed(2),
      'footer': 'Thank you! Visit again.',
    });
  }

  Future<String?> _loadPaymentVpa() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('paymentBankId')
          .get();
      final value = doc.data()?['bankId']?.toString().trim();
      if (value == null ||
          !RegExp(r'^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$').hasMatch(value))
        return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  Future<void> _printTextTicket(
    String printer,
    List<String> lines,
    String title,
  ) => _printReceipt(printer, {
    'kind': 'text',
    'lines': lines,
    'documentName': title,
  });

  Future<void> _printReceipt(
    String printerName,
    Map<String, dynamic> data,
  ) async {
    if (!Platform.isWindows)
      throw UnsupportedError(
        'Printing is supported in the Windows desktop app.',
      );
    final payload = base64Encode(utf8.encode(jsonEncode(data)));
    final encodedPrinter = base64Encode(utf8.encode(printerName));
    final script =
        r'''
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$printerName = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__PRINTER__'))
$r = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__DATA__')) | ConvertFrom-Json
$doc = New-Object System.Drawing.Printing.PrintDocument
$doc.PrinterSettings.PrinterName = $printerName
if (-not $doc.PrinterSettings.IsValid) { throw "Printer not available: $printerName" }
$doc.DocumentName = if ($r.documentName) { [string]$r.documentName } else { 'Club Deal Receipt' }
$doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0,0,0,0)
$height = 900
if ($r.items) { $height = 650 + (@($r.items).Count * 58) + $(if ($r.qr) { 210 } else { 0 }) }
$doc.DefaultPageSettings.PaperSize = New-Object System.Drawing.Printing.PaperSize('ClubDeal58mm', 228, [Math]::Min(2000, $height))
$script:r = $r
$doc.add_PrintPage({
 param($sender,$e)
 $g=$e.Graphics; $g.PageUnit=[System.Drawing.GraphicsUnit]::Display
 $width=228; $left=8; $right=220; $y=8
 $center=New-Object System.Drawing.StringFormat; $center.Alignment=[System.Drawing.StringAlignment]::Center
 $rf=New-Object System.Drawing.StringFormat; $rf.Alignment=[System.Drawing.StringAlignment]::Far
 $black=[System.Drawing.Brushes]::Black
 if ($script:r.kind -eq 'text') {
   $font=New-Object System.Drawing.Font('Arial',8)
   foreach($line in $script:r.lines) { $g.DrawString([string]$line,$font,$black,$left,$y); $y+=15 }
   $font.Dispose()
 } else {
   $brand=New-Object System.Drawing.Font('Arial',16,[System.Drawing.FontStyle]::Bold)
   $tag=New-Object System.Drawing.Font('Arial',7,[System.Drawing.FontStyle]::Bold)
   $head=New-Object System.Drawing.Font('Arial',8,[System.Drawing.FontStyle]::Bold)
   $normal=New-Object System.Drawing.Font('Arial',7)
   $small=New-Object System.Drawing.Font('Arial',6)
   $bold=New-Object System.Drawing.Font('Arial',8,[System.Drawing.FontStyle]::Bold)
   $g.DrawString([string]$script:r.restaurant,$brand,$black,[single]114,[single]$y,$center); $y+=23
   $g.DrawString([string]$script:r.tagline,$tag,$black,[single]114,[single]$y,$center); $y+=20
   $g.DrawLine([System.Drawing.Pens]::Black,$left,$y,$right,$y); $y+=7
   $g.DrawString('BILL / RECEIPT',$head,$black,[single]114,[single]$y,$center); $y+=17
   $g.DrawString(('Bill: '+[string]$script:r.billNo),$normal,$black,$left,$y); $y+=14
   $g.DrawString(('Date: '+[string]$script:r.date),$normal,$black,$left,$y)
   $g.DrawString(('Time: '+[string]$script:r.time),$normal,$black,[single]$right,[single]$y,$rf); $y+=14
   $g.DrawString(('Customer: '+[string]$script:r.customer),$normal,$black,$left,$y); $y+=14
   if([string]$script:r.phone) { $g.DrawString(('Phone: '+[string]$script:r.phone),$normal,$black,$left,$y); $y+=14 }
   $g.DrawString(('Table: '+[string]$script:r.table),$normal,$black,$left,$y); $y+=17
   $g.DrawLine([System.Drawing.Pens]::Black,$left,$y,$right,$y); $y+=6
   $g.DrawString('ITEM',$head,$black,$left,$y)
   $g.DrawString('AMOUNT',$head,$black,[single]$right,[single]$y,$rf); $y+=16
   foreach($item in $script:r.items) {
     $g.DrawString([string]$item.name,$bold,$black,$left,$y); $y+=13
     $g.DrawString(([string]$item.qty+' x Rs.'+([double]$item.price).ToString('0.00')),$small,$black,$left+5,$y)
     $g.DrawString(('Rs.'+([double]$item.total).ToString('0.00')),$normal,$black,[single]$right,[single]$y,$rf); $y+=17
   }
   $g.DrawLine([System.Drawing.Pens]::Black,$left,$y,$right,$y); $y+=7
   $g.DrawString('Subtotal',$normal,$black,$left,$y)
   $g.DrawString(('Rs.'+([double]$script:r.subtotal).ToString('0.00')),$normal,$black,[single]$right,[single]$y,$rf); $y+=15
   if([double]$script:r.discount -gt 0) {
     $g.DrawString('Discount',$normal,$black,$left,$y)
     $g.DrawString(('- Rs.'+([double]$script:r.discount).ToString('0.00')),$normal,$black,[single]$right,[single]$y,$rf); $y+=15
   }
   $g.DrawString('GRAND TOTAL',$head,$black,$left,$y)
   $g.DrawString(('Rs.'+([double]$script:r.total).ToString('0.00')),$bold,$black,[single]$right,[single]$y,$rf); $y+=18
   $g.DrawString(([string]$script:r.status+' / '+[string]$script:r.payment),$normal,$black,[single]114,[single]$y,$center); $y+=18
   if([string]$script:r.note) { $g.DrawString(('Note: '+[string]$script:r.note),$small,$black,$left,$y); $y+=15 }
   if($script:r.qr) {
     $g.DrawLine([System.Drawing.Pens]::Black,$left,$y,$right,$y); $y+=7
     $g.DrawString('SCAN TO PAY',$head,$black,[single]114,[single]$y,$center); $y+=15
     $g.DrawString(('Amount: Rs.'+[string]$script:r.upiAmount),$bold,$black,[single]114,[single]$y,$center); $y+=10
     $matrix=@($script:r.qr); $count=$matrix.Count
     $module=[Math]::Max(2,[Math]::Min(4,[Math]::Floor(132/$count)))
     $size=$count*$module; $qx=[single](($width-$size)/2)
     for($row=0;$row -lt $count;$row++) {
       $bits=@($matrix[$row])
       for($col=0;$col -lt $count;$col++) {
         if($bits[$col] -eq $true) {
           $g.FillRectangle($black,[single]($qx+$col*$module),[single]($y+$row*$module),[single]$module,[single]$module)
         }
       }
     }
     $y+=$size+7
     $g.DrawString(('UPI: '+[string]$script:r.vpa),$small,$black,[single]114,[single]$y,$center); $y+=16
   } elseif([string]$script:r.vpa -eq '') {
     $g.DrawString('UPI QR not configured',$small,$black,[single]114,[single]$y,$center); $y+=14
   }
   $g.DrawLine([System.Drawing.Pens]::Black,$left,$y,$right,$y); $y+=8
   $g.DrawString([string]$script:r.footer,$head,$black,[single]114,[single]$y,$center); $y+=15
   $g.DrawString('Powered by Club Deal',$small,$black,[single]114,[single]$y,$center)
   $brand.Dispose();$tag.Dispose();$head.Dispose();$normal.Dispose();$small.Dispose();$bold.Dispose()
 }
 $center.Dispose();$rf.Dispose();$e.HasMorePages=$false
})
$doc.Print(); $doc.Dispose()
Write-Output 'PRINT_SUBMITTED'
'''
            .replaceAll('__PRINTER__', encodedPrinter)
            .replaceAll('__DATA__', payload);
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
    final bytes = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      bytes[i * 2] = units[i] & 0xff;
      bytes[i * 2 + 1] = (units[i] >> 8) & 0xff;
    }
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      base64Encode(bytes),
    ], runInShell: false);
    if (result.exitCode != 0) {
      throw ProcessException(
        'powershell.exe',
        const [],
        result.stderr.toString().trim().isEmpty
            ? result.stdout.toString().trim()
            : result.stderr.toString().trim(),
        result.exitCode,
      );
    }
    return result;
  }
}

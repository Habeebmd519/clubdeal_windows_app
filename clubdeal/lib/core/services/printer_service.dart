import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
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

  // --------------------------------------------------
  // INITIALIZATION
  // --------------------------------------------------

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

  // --------------------------------------------------
  // PRINTER MANAGEMENT
  // --------------------------------------------------

  Future<void> refreshPrinters() async {
    if (!Platform.isWindows) {
      printers = const [];

      lastError =
          'Windows printing is available only in Windows desktop build.';

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
    [PSCustomObject]@{
      name = $_.Name
      isDefault = [bool]$_.Default
    }
  })

  ConvertTo-Json -InputObject $items -Compress

} catch {

  Add-Type -AssemblyName System.Drawing

  $items = @()

  foreach ($name in [System.Drawing.Printing.PrinterSettings]::InstalledPrinters) {
    $items += [PSCustomObject]@{
      name = [string]$name
      isDefault = $false
    }
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
            : printers.isNotEmpty
            ? printers.first.name
            : null;

        if (selectedPrinterName != null) {
          final prefs = await SharedPreferences.getInstance();

          await prefs.setString(_printerKey, selectedPrinterName!);
        }
      }

      if (printers.isEmpty) {
        lastError = 'No Windows printers found. Install the printer driver.';
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

    if (name == null || !isConnected) {
      throw StateError('Select an installed Windows printer in Settings.');
    }

    return name;
  }

  // --------------------------------------------------
  // TEST PRINT
  // --------------------------------------------------

  Future<void> testPrint() {
    return _printTextTicket(_requirePrinter(), [
      'CLUB DEAL',
      'KOCHI',
      '58MM PRINTER TEST',
      '------------------------------',
      'Printer connection is working.',
      DateTime.now().toString(),
      '',
      '',
    ], 'Club Deal Printer Test');
  }

  // --------------------------------------------------
  // KITCHEN TICKET
  // --------------------------------------------------

  Future<void> printKitchenTicket(
    RestaurantOrder order, {
    bool revised = false,
  }) async {
    final date = order.createdAt?.toLocal() ?? DateTime.now();
    final lines = <String>[
      'KOC',
      revised ? 'Updated Kitchen Order Copy' : 'Kitchen Order Copy',
      '--------------------------------',
      'Bill ID : ${order.id}',
      'Table   : ${order.table.toUpperCase()}',
      'Name    : ${order.customerName}',
      'Time    : ${DateFormat('hh:mm a').format(date)}',
      '--------------------------------',
      'ITEMS',
      '--------------------------------',
      ...order.items.map((item) => '${item.qty} x ${item.name}'),
      if (order.note.trim().isNotEmpty) ...[
        '--------------------------------',
        'Note: ${order.note.trim()}',
      ],
      '--------------------------------',
      'Prepare Order',
      '',
      '',
    ];

    await _printTextTicket(_requirePrinter(), lines, 'Club Deal Kitchen');
  }

  // --------------------------------------------------
  // CANCELLATION TICKET
  // --------------------------------------------------

  Future<void> printCancellationTicket(
    RestaurantOrder order,
    String reason,
  ) async {
    final name = selectedPrinterName;

    if (name == null || !isConnected) return;

    await _printTextTicket(name, [
      '*** ORDER CANCELLED ***',
      'CLUB DEAL',
      'Order: ${order.id}',
      'Table / Token: ${order.table}',
      'Customer: ${order.customerName}',
      'Reason: $reason',
      'DO NOT PREPARE THIS ORDER.',
      '',
      '',
    ], 'Club Deal Cancellation');
  }

  // --------------------------------------------------
  // CUSTOMER RECEIPT + UPI QR
  // --------------------------------------------------

  Future<void> printOrder(
    RestaurantOrder order, {
    PaymentMethod? paymentMethod,
  }) async {
    final printer = _requirePrinter();

    final vpa = await _loadPaymentVpa();

    List<List<bool>>? matrix;

    // Generate QR with exact order amount.
    if (vpa != null && order.total > 0) {
      final uri = Uri(
        scheme: 'upi',
        host: 'pay',
        queryParameters: {
          'pa': vpa,
          'pn': 'CLUBDEAL',
          'am': order.total.toStringAsFixed(2),
          'cu': 'INR',
          'tn': 'Bill',
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

      // BUSINESS HEADER
      'restaurant': 'CLUB DEAL',
      'city': 'Kochi',
      'address1': 'Kaloor - Kadavanthra Road',
      'address2': 'Kathrikadavu, Opp. Popees',
      'email': 'kochiclubdeal@gmail.com',
      'phone1': '+91 95622 08806',
      'phone2': '+91 96057 91139',

      // BILL DETAILS
      'billNo': order.id,

      'date': DateFormat('dd MMM yyyy').format(date),

      'time': DateFormat('hh:mm a').format(date),

      'customer': order.customerName,
      'phone': order.phone,
      'table': order.table,

      // ITEMS
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

      // TOTALS
      'subtotal': order.total,
      'discount': 0,
      'total': order.total,

      // PAYMENT
      'status': paidBy != null ? 'PAID' : order.status.name.toUpperCase(),

      'payment': paidBy?.name.toUpperCase() ?? 'PAYMENT DUE',

      'note': order.note,

      // UPI QR
      'vpa': vpa ?? '',
      'qr': matrix,
      'upiAmount': order.total.toStringAsFixed(2),

      // FOOTER
      'footer': 'Thank you! Visit again.',
    });
  }

  // --------------------------------------------------
  // LOAD UPI ID
  // --------------------------------------------------

  Future<String?> _loadPaymentVpa() async {
    try {
      final db = FirebaseFirestore.instance;
      var doc = await db.collection('app_config').doc('paymentBankId').get();
      var value = doc.data()?['bankId']?.toString().trim();

      if (value == null || value.isEmpty) {
        doc = await db.collection('app_confige').doc('paymentBankId').get();
        value = doc.data()?['bankId']?.toString().trim();
      }

      if (value == null ||
          !RegExp(r'^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$').hasMatch(value)) {
        return null;
      }
      return value;
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------
  // TEXT PRINT
  // --------------------------------------------------

  Future<void> _printTextTicket(
    String printer,
    List<String> lines,
    String title,
  ) {
    return _printReceipt(printer, {
      'kind': 'text',
      'lines': lines,
      'documentName': title,
    });
  }

  // --------------------------------------------------
  // PRINT RECEIPT
  // --------------------------------------------------

  Future<void> _printReceipt(
    String printerName,
    Map<String, dynamic> data,
  ) async {
    if (!Platform.isWindows) {
      throw UnsupportedError(
        'Printing is supported in the Windows desktop app.',
      );
    }

    final payload = base64Encode(utf8.encode(jsonEncode(data)));

    final encodedPrinter = base64Encode(utf8.encode(printerName));

    final script =
        r'''
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$printerName = [Text.Encoding]::UTF8.GetString(
  [Convert]::FromBase64String('__PRINTER__')
)

$r = [Text.Encoding]::UTF8.GetString(
  [Convert]::FromBase64String('__DATA__')
) | ConvertFrom-Json

$doc = New-Object System.Drawing.Printing.PrintDocument

$doc.PrinterSettings.PrinterName = $printerName

if (-not $doc.PrinterSettings.IsValid) {
  throw "Printer not available: $printerName"
}

$doc.DocumentName = 'Club Deal Receipt'

$doc.DefaultPageSettings.Margins =
  New-Object System.Drawing.Printing.Margins(0,0,0,0)

# EXTRA HEIGHT FOR BUSINESS HEADER AND QR
$height = 900

if ($r.items) {
  $height = 850 + (@($r.items).Count * 58)

  if ($r.qr) {
    $height += 210
  }
}

# Extra tail feed so the QR code and final line clear the printer outlet.
# PaperSize is in hundredths of an inch; 100 adds about 25 mm of blank paper.
$height += 100

$doc.DefaultPageSettings.PaperSize =
  New-Object System.Drawing.Printing.PaperSize(
    'ClubDeal58mm',
    228,
    [Math]::Min(3000, $height)
  )

$script:r = $r

$doc.add_PrintPage({

  param($sender,$e)

  $g = $e.Graphics

  $g.PageUnit = [System.Drawing.GraphicsUnit]::Display

  # Use the printer driver's real printable width, capped to a safe
  # 58mm receipt column. POS-58 drivers often expose less than the nominal
  # roll width; drawing to x=220 clips right-aligned prices and totals.
  $clip = $g.VisibleClipBounds
  $pageLeft = [Math]::Ceiling($clip.Left)
  $width = [Math]::Min(190, [Math]::Floor($clip.Width))
  if ($width -lt 120) { $width = 190 }
  $left = $pageLeft + 3
  $right = $pageLeft + $width - 3
  $centerX = ($left + $right) / 2
  $contentWidth = $right - $left
  $y = 8

  $center = New-Object System.Drawing.StringFormat
  $center.Alignment = [System.Drawing.StringAlignment]::Center

  $rf = New-Object System.Drawing.StringFormat
  $rf.Alignment = [System.Drawing.StringAlignment]::Far

  $black = [System.Drawing.Brushes]::Black

  if ($script:r.kind -eq 'text') {

    $font = New-Object System.Drawing.Font('Arial',8)

    foreach ($line in $script:r.lines) {
      $lineText = [string]$line
      $lineLayout = New-Object System.Drawing.RectangleF($left, $y, $contentWidth, 1000)
      $lineMeasure = $g.MeasureString($lineText, $font, $contentWidth)
      $g.DrawString($lineText, $font, $black, $lineLayout)
      $y += [Math]::Max(15, [Math]::Ceiling($lineMeasure.Height) + 2)
    }

    $font.Dispose()

  } else {

    # --------------------------------
    # FONTS
    # --------------------------------

    $brand = New-Object System.Drawing.Font(
      'Arial',16,[System.Drawing.FontStyle]::Bold
    )

    $head = New-Object System.Drawing.Font(
      'Arial',8,[System.Drawing.FontStyle]::Bold
    )

    $normal = New-Object System.Drawing.Font('Arial',7)

    $small = New-Object System.Drawing.Font('Arial',6)

    $bold = New-Object System.Drawing.Font(
      'Arial',8,[System.Drawing.FontStyle]::Bold
    )

    # --------------------------------
    # BUSINESS HEADER
    # --------------------------------

    $g.DrawString(
      [string]$script:r.restaurant,
      $brand,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 24

    $g.DrawString(
      [string]$script:r.city,
      $head,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 16

    $g.DrawString(
      [string]$script:r.address1,
      $normal,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 14

    $g.DrawString(
      [string]$script:r.address2,
      $normal,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 16

    $g.DrawString(
      [string]$script:r.email,
      $normal,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 14

    $g.DrawString(
      [string]$script:r.phone1,
      $normal,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 14

    $g.DrawString(
      [string]$script:r.phone2,
      $normal,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 18

    $g.DrawLine(
      [System.Drawing.Pens]::Black,
      $left,$y,$right,$y
    )

    $y += 8

    # --------------------------------
    # BILL DETAILS
    # --------------------------------

    $g.DrawString(
      'BILL / RECEIPT',
      $head,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 17

    $g.DrawString(
      ('Bill: ' + [string]$script:r.billNo),
      $normal,
      $black,
      $left,
      $y
    )

    $y += 14

    $g.DrawString(
      ('Date: ' + [string]$script:r.date),
      $normal,
      $black,
      $left,
      $y
    )
    $y += 14

    $g.DrawString(
      ('Time: ' + [string]$script:r.time),
      $normal,
      $black,
      $left,
      $y
    )

    $y += 15

    $customerText = 'Customer: ' + [string]$script:r.customer
    $customerLayout = New-Object System.Drawing.RectangleF($left, $y, $contentWidth, 1000)
    $customerMeasure = $g.MeasureString($customerText, $normal, $contentWidth)
    $g.DrawString($customerText, $normal, $black, $customerLayout)
    $y += [Math]::Max(14, [Math]::Ceiling($customerMeasure.Height) + 2)

    if ([string]$script:r.phone) {

      $g.DrawString(
        ('Phone: ' + [string]$script:r.phone),
        $normal,
        $black,
        $left,
        $y
      )

      $y += 14
    }

    $g.DrawString(
      ('Table: ' + [string]$script:r.table),
      $normal,
      $black,
      $left,
      $y
    )

    $y += 17

    $g.DrawLine(
      [System.Drawing.Pens]::Black,
      $left,$y,$right,$y
    )

    $y += 7

    # --------------------------------
    # ITEM HEADER
    # --------------------------------

    $g.DrawString(
      'ITEM',
      $head,
      $black,
      $left,
      $y
    )

    $g.DrawString(
      'AMOUNT',
      $head,
      $black,
      [single]$right,
      [single]$y,
      $rf
    )

    $y += 16

    # --------------------------------
    # ITEMS
    # --------------------------------

    foreach ($item in $script:r.items) {

      $itemName = [string]$item.name
      $itemLayout = New-Object System.Drawing.RectangleF($left, $y, $contentWidth, 1000)
      $itemMeasure = $g.MeasureString($itemName, $bold, $contentWidth)
      $g.DrawString($itemName, $bold, $black, $itemLayout)
      $y += [Math]::Max(13, [Math]::Ceiling($itemMeasure.Height) + 1)

      $g.DrawString(
        (
          [string]$item.qty +
          ' x Rs.' +
          ([double]$item.price).ToString('0.##')
        ),
        $small,
        $black,
        $left + 5,
        $y
      )

      $g.DrawString(
        (
          'Rs.' +
          ([double]$item.total).ToString('0.##')
        ),
        $normal,
        $black,
        [single]$right,
        [single]$y,
        $rf
      )

      $y += 17
    }

    $g.DrawLine(
      [System.Drawing.Pens]::Black,
      $left,$y,$right,$y
    )

    $y += 8

    # --------------------------------
    # TOTALS
    # --------------------------------

    $g.DrawString(
      'Subtotal',
      $normal,
      $black,
      $left,
      $y
    )

    $g.DrawString(
      (
        'Rs.' +
        ([double]$script:r.subtotal).ToString('0.##')
      ),
      $normal,
      $black,
      [single]$right,
      [single]$y,
      $rf
    )

    $y += 15

    if ([double]$script:r.discount -gt 0) {

      $g.DrawString(
        'Discount',
        $normal,
        $black,
        $left,
        $y
      )

      $g.DrawString(
        (
          '- Rs.' +
          ([double]$script:r.discount).ToString('0.##')
        ),
        $normal,
        $black,
        [single]$right,
        [single]$y,
        $rf
      )

      $y += 15
    }

    $g.DrawString(
      'GRAND TOTAL',
      $head,
      $black,
      $left,
      $y
    )

    $g.DrawString(
      (
        'Rs.' +
        ([double]$script:r.total).ToString('0.##')
      ),
      $bold,
      $black,
      [single]$right,
      [single]$y,
      $rf
    )

    $y += 20

    # --------------------------------
    # PAYMENT STATUS
    # --------------------------------

    $g.DrawString(
      (
        [string]$script:r.status +
        ' / ' +
        [string]$script:r.payment
      ),
      $head,
      $black,
      [single]$centerX,
      [single]$y,
      $center
    )

    $y += 18

    if ([string]$script:r.note) {

      $g.DrawString(
        ('Note: ' + [string]$script:r.note),
        $small,
        $black,
        $left,
        $y
      )

      $y += 15
    }

    # Footer is printed before the QR, as in the Android receipt.
    $g.DrawLine([System.Drawing.Pens]::Black, $left,$y,$right,$y)
    $y += 7
    $g.DrawString([string]$script:r.footer, $head, $black, [single]$centerX, [single]$y, $center)
    $y += 16
    $g.DrawString('Powered by Club Deal', $small, $black, [single]$centerX, [single]$y, $center)
    $y += 22

    # --------------------------------
    # UPI QR CODE — last main content
    # --------------------------------

    if ($script:r.qr) {

      $g.DrawLine(
        [System.Drawing.Pens]::Black,
        $left,$y,$right,$y
      )

      $y += 8

      $g.DrawString(
        'SCAN TO PAY',
        $head,
        $black,
        [single]$centerX,
        [single]$y,
        $center
      )

      $y += 16

      $g.DrawString(
        ('Amount: Rs.' + [string]$script:r.upiAmount),
        $bold,
        $black,
        [single]$centerX,
        [single]$y,
        $center
      )

      $y += 10
      $g.DrawString([string]$script:r.vpa, $small, $black, [single]$centerX, [single]$y, $center)
      $y += 13

      # QR MATRIX
      $matrix = @($script:r.qr)

      $count = $matrix.Count

      # QR size
      $module = [Math]::Max(1, [Math]::Min(4, [Math]::Floor(($contentWidth - 16) / ($count + 8))))
      $size = $count * $module
      $quiet = 4 * $module
      $totalQrSize = $size + (2 * $quiet)
      $qx = [single]($centerX - ($totalQrSize / 2))

      # White QR background
      $g.FillRectangle(
        [System.Drawing.Brushes]::White,
        $qx,
        [single]$y,
        [single]$totalQrSize,
        [single]$totalQrSize
      )

      # Draw QR pixels
      for ($row = 0; $row -lt $count; $row++) {

        $bits = @($matrix[$row])

        for ($col = 0; $col -lt $count; $col++) {

          if ($bits[$col] -eq $true) {

            $g.FillRectangle(
              $black,
              [single]($qx + $quiet + $col * $module),
              [single]($y + $quiet + $row * $module),
              [single]$module,
              [single]$module
            )
          }
        }
      }

      $y += $totalQrSize + 8

    } else {

      $g.DrawLine(
        [System.Drawing.Pens]::Black,
        $left,$y,$right,$y
      )

      $y += 8

      $g.DrawString(
        'UPI QR NOT AVAILABLE',
        $small,
        $black,
        [single]$centerX,
        [single]$y,
        $center
      )

      $y += 16
    }



    $brand.Dispose()
    $head.Dispose()
    $normal.Dispose()
    $small.Dispose()
    $bold.Dispose()
  }

  $center.Dispose()
  $rf.Dispose()

  $e.HasMorePages = $false
})

$doc.Print()

$doc.Dispose()

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

  // --------------------------------------------------
  // POWERSHELL EXECUTION
  // --------------------------------------------------

  Future<ProcessResult> _runPowerShell(String script) async {
    // Order receipts can contain a large QR payload. Passing the complete
    // script through -EncodedCommand can exceed Windows' process command-line
    // length limit (32,767 characters). Write it to a short temporary .ps1
    // file instead, and pass only that file path to powershell.exe.
    final tempDir = await Directory.systemTemp.createTemp('clubdeal_ps_');
    final scriptFile = File(
      '${tempDir.path}${Platform.pathSeparator}print.ps1',
    );

    try {
      final units = script.codeUnits;
      final bytes = Uint8List(2 + units.length * 2);
      // UTF-16 little-endian BOM so Windows PowerShell 5.1 reads the script
      // correctly, including any non-ASCII receipt text.
      bytes[0] = 0xff;
      bytes[1] = 0xfe;

      for (var i = 0; i < units.length; i++) {
        bytes[2 + i * 2] = units[i] & 0xff;
        bytes[3 + i * 2] = (units[i] >> 8) & 0xff;
      }

      await scriptFile.writeAsBytes(bytes, flush: true);

      final args = [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
      ];

      final result = await Process.run(
        'powershell.exe',
        args,
        runInShell: false,
      );

      if (result.exitCode != 0) {
        throw ProcessException(
          'powershell.exe',
          args,
          result.stderr.toString().trim().isEmpty
              ? result.stdout.toString().trim()
              : result.stderr.toString().trim(),
          result.exitCode,
        );
      }

      return result;
    } finally {
      // Clean up the temporary script whether printing succeeds or fails.
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {
        // Do not mask the original printing result with a cleanup error.
      }
    }
  }
}

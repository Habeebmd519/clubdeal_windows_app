import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:printing_ffi/printing_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';

/// Raw ESC/POS printing for 58 mm POS58 thermal printers.
class PrinterService extends ChangeNotifier {
  PrinterService() { _initialize(); }

  static const _printerKey = 'clubdeal_windows_printer_name';
  static const _autoPrintKey = 'clubdeal_auto_print_new_orders';
  static const _upiKey = 'clubdeal_receipt_upi_id';
  static const int _columns = 32;
  static const String _separator = '--------------------------------';

  final PrintingFfi _printing = PrintingFfi.instance;
  List<Printer> printers = const [];
  String? selectedPrinterName;
  bool isLoading = false;
  bool autoPrintNewOrders = true;
  String? lastError;
  String upiId = '';

  Future<void> _initialize() async {
    await _loadPreferences();
    await refreshPrinters();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      selectedPrinterName = prefs.getString(_printerKey);
      autoPrintNewOrders = prefs.getBool(_autoPrintKey) ?? true;
      upiId = prefs.getString(_upiKey) ?? '';
      notifyListeners();
    } catch (error) {
      lastError = 'Could not load printer settings: $error';
      notifyListeners();
    }
  }

  bool get isConnected => selectedPrinterName != null &&
      printers.any((p) => p.name == selectedPrinterName && p.isAvailable);

  Future<void> refreshPrinters() async {
    if (!Platform.isWindows) {
      printers = const [];
      lastError = 'Thermal printing is available only in the Windows desktop build.';
      notifyListeners();
      return;
    }
    isLoading = true;
    lastError = null;
    notifyListeners();
    try {
      printers = _printing.listPrinters();
      if (selectedPrinterName == null ||
          !printers.any((p) => p.name == selectedPrinterName)) {
        final defaults = printers.where((p) => p.isDefault);
        selectedPrinterName = defaults.isNotEmpty
            ? defaults.first.name
            : (printers.isNotEmpty ? printers.first.name : null);
      }
      final prefs = await SharedPreferences.getInstance();
      if (selectedPrinterName != null) {
        await prefs.setString(_printerKey, selectedPrinterName!);
      }
      if (printers.isEmpty) {
        lastError = 'No Windows printers found. Install the POS58 driver, reconnect the printer and refresh.';
      }
    } catch (error) {
      printers = const [];
      lastError = 'Could not list Windows printers: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectPrinter(String? name) async {
    selectedPrinterName = name;
    lastError = null;
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_printerKey);
    } else {
      await prefs.setString(_printerKey, name);
    }
    notifyListeners();
  }

  Future<void> setAutoPrintNewOrders(bool enabled) async {
    autoPrintNewOrders = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoPrintKey, enabled);
    notifyListeners();
  }

  Future<void> saveUpiId(String value) async {
    final normalized = value.trim();
    if (normalized.isNotEmpty &&
        !RegExp(r'^[A-Za-z0-9._-]+@[A-Za-z0-9.-]+$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid UPI ID, for example name@bank.');
    }
    upiId = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_upiKey, normalized);
    notifyListeners();
  }

  Printer _requirePrinter() {
    if (!Platform.isWindows) {
      throw UnsupportedError('Thermal printing is supported in the Windows desktop app.');
    }
    final name = selectedPrinterName;
    if (name == null) {
      throw StateError('Select your POS58 printer in Settings first.');
    }
    for (final printer in printers) {
      if (printer.name == name) {
        if (!printer.isAvailable) {
          throw StateError('Printer "$name" is offline. Check its power and USB connection.');
        }
        return printer;
      }
    }
    throw StateError('Printer "$name" is not available. Refresh the printer list.');
  }

  Future<void> testPrint() async {
    final printer = _requirePrinter();
    final bytes = <int>[
      ..._initializePrinter, ..._center, ..._boldOn,
      ..._ascii('CLUB DEAL'), ..._boldOff,
      ..._ascii('58 mm THERMAL PRINTER TEST'),
      ..._left, ..._ascii(_separator),
      ..._ascii('Printer: ${printer.name}'),
      ..._ascii('32-column receipt layout'),
      ..._ascii('Test print successful.'),
      ..._ascii(_separator), ..._center, ..._ascii('Thank you!'),
      0x0A, 0x0A, 0x0A, ..._cut,
    ];
    await _send(printer, bytes, jobName: 'Club Deal printer test');
  }

  Future<void> printOrder(RestaurantOrder order) async {
    final printer = _requirePrinter();
    final created = order.createdAt ?? DateTime.now();
    final bytes = <int>[
      ..._initializePrinter, ..._center, ..._boldOn,
      ..._ascii('CLUB DEAL'), ..._boldOff,
      ..._ascii('Kochi'),
      ..._ascii('Kaloor - Kadavanthra Road'),
      ..._ascii('Kathrikadavu, Opp. Popees'),
      ..._ascii('kochiclubdeal@gmail.com'),
      ..._ascii('+91 95622 08806'),
      ..._ascii('+91 96057 91139'),
      ..._left, ..._ascii(_separator),
      ..._pair('Bill', order.id),
      ..._pair('Date', DateFormat('dd MMM yyyy').format(created)),
      ..._pair('Time', DateFormat('hh:mm a').format(created)),
      ..._ascii(_separator),
      ..._formatItems(order.items),
      ..._ascii(_separator),
      ..._boldOn, ..._pair('TOTAL', 'Rs ${_money(order.total)}'), ..._boldOff,
      if (order.note.trim().isNotEmpty) ...[
        ..._ascii(_separator), ..._wrap('Note: ${order.note}'),
      ],
      0x0A, ..._center,
      ..._ascii('Thank you! Visit again.'),
      ..._ascii('Powered by Club Deal'),
      0x0A, ..._boldOn, ..._ascii('SCAN TO PAY'), ..._boldOff,
      ..._ascii('Amount: Rs ${_money(order.total)}'),
      if (upiId.isNotEmpty) ...[
        ..._ascii(upiId), ..._qrCode(_upiPayload(order)),
      ] else ...[
        ..._ascii('UPI ID not configured'),
        ..._ascii('Set UPI ID in Settings to print QR'),
      ],
      0x0A, 0x0A, 0x0A, ..._cut,
    ];
    await _send(printer, bytes, jobName: 'Club Deal receipt ${order.id}');
  }

  List<int> _formatItems(List<OrderItem> items) {
    final output = <int>[];
    for (final item in items) {
      output.addAll(_wrap(item.name));
      output.addAll(_ascii(_fitPair(
        '${item.qty} x Rs ${_money(item.price)}',
        'Rs ${_money(item.total)}',
      )));
    }
    return output;
  }

  String _fitPair(String left, String right) {
    final safeRight = right.length >= _columns
        ? right.substring(right.length - _columns) : right;
    final available = _columns - safeRight.length;
    final safeLeft = left.length > available ? left.substring(0, available) : left;
    return safeLeft.padRight(available) + safeRight;
  }

  List<int> _pair(String label, String value) => _ascii(_fitPair(label, value));

  List<int> _wrap(String text) {
    final words = text.replaceAll(RegExp(r'\s+'), ' ').trim().split(' ');
    final lines = <String>[];
    var line = '';
    for (final word in words) {
      if (word.isEmpty) continue;
      if (word.length > _columns) {
        if (line.isNotEmpty) { lines.add(line); line = ''; }
        for (var start = 0; start < word.length; start += _columns) {
          final end = (start + _columns).clamp(0, word.length);
          lines.add(word.substring(start, end));
        }
        continue;
      }
      final candidate = line.isEmpty ? word : '$line $word';
      if (candidate.length > _columns) {
        if (line.isNotEmpty) lines.add(line);
        line = word;
      } else {
        line = candidate;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return <int>[for (final value in lines) ..._ascii(value)];
  }

  String _upiPayload(RestaurantOrder order) {
    final params = <String, String>{
      'pa': upiId, 'pn': 'Club Deal',
      'am': order.total.toStringAsFixed(2), 'cu': 'INR',
      'tn': 'Bill ${order.id}',
    };
    final query = params.entries.map((entry) =>
      '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}'
    ).join('&');
    return 'upi://pay?$query';
  }

  /// ESC/POS QR Code: model 2, module size 6, error correction M.
  List<int> _qrCode(String value) {
    final data = ascii.encode(value);
    if (data.length > 700) {
      throw StateError('UPI QR data is too long for this thermal printer.');
    }
    final length = data.length + 3;
    final low = length & 0xff;
    final high = (length >> 8) & 0xff;
    return <int>[
      0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31,
      0x1D, 0x28, 0x6B, low, high, 0x31, 0x50, 0x30,
      ...data,
      0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30,
    ];
  }

  static const List<int> _initializePrinter = [0x1B, 0x40];
  static const List<int> _left = [0x1B, 0x61, 0x00];
  static const List<int> _center = [0x1B, 0x61, 0x01];
  static const List<int> _boldOn = [0x1B, 0x45, 0x01];
  static const List<int> _boldOff = [0x1B, 0x45, 0x00];
  static const List<int> _cut = [0x1D, 0x56, 0x00];

  List<int> _ascii(String value) => ascii.encode(
    value.replaceAll(RegExp(r'[^\\x00-\\x7F]'), '?'),
  );
  String _money(double value) => value.toStringAsFixed(0);

  Future<void> _send(Printer printer, List<int> bytes, {
    required String jobName,
  }) async {
    lastError = null;
    notifyListeners();
    try {
      final success = await _printing.rawDataToPrinter(
        printer.name, Uint8List.fromList(bytes), docName: jobName,
      );
      if (!success) {
        throw StateError('Windows could not send the receipt to ${printer.name}. Check the printer queue and connection.');
      }
    } catch (error) {
      lastError = '$error';
      notifyListeners();
      rethrow;
    }
  }
}

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:printing_ffi/printing_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';

/// Native Windows spooler integration for POS58/ESC-POS thermal printers.
class PrinterService extends ChangeNotifier {
  static const _printerKey = 'clubdeal_selected_windows_printer';
  final PrintingFfi _printing = PrintingFfi.instance;

  List<Printer> _printers = const [];
  String? _selectedPrinterName;
  bool _loading = false;

  List<Printer> get printers => List.unmodifiable(_printers);
  String? get selectedPrinterName => _selectedPrinterName;
  bool get isConnected =>
      _selectedPrinterName != null &&
      _printers.any((p) => p.name == _selectedPrinterName && p.isAvailable);
  bool get isLoading => _loading;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedPrinterName = prefs.getString(_printerKey);
    try {
      await refreshPrinters();
    } catch (_) {
      // Keep the app usable if the Windows spooler is temporarily unavailable.
      _printers = const [];
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<Printer>> refreshPrinters() async {
    _loading = true;
    notifyListeners();
    try {
      _printers = _printing.listPrinters();
      if (_selectedPrinterName == null ||
          !_printers.any((p) => p.name == _selectedPrinterName)) {
        final defaults = _printers.where((p) => p.isDefault);
        _selectedPrinterName = defaults.isNotEmpty
            ? defaults.first.name
            : (_printers.isNotEmpty ? _printers.first.name : null);
      }
      final prefs = await SharedPreferences.getInstance();
      if (_selectedPrinterName != null) {
        await prefs.setString(_printerKey, _selectedPrinterName!);
      }
      return _printers;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectPrinter(String? name) async {
    _selectedPrinterName = name;
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_printerKey);
    } else {
      await prefs.setString(_printerKey, name);
    }
    notifyListeners();
  }

  Printer _requirePrinter() {
    final name = _selectedPrinterName;
    if (name == null) {
      throw StateError('Select your POS58 printer in Settings first.');
    }
    for (final printer in _printers) {
      if (printer.name == name) {
        if (!printer.isAvailable) {
          throw StateError(
            'Printer "$name" is offline. Check its power and USB connection.',
          );
        }
        return printer;
      }
    }
    throw StateError(
      'Printer "$name" is not installed. Refresh the printer list.',
    );
  }

  Future<void> testPrint() async {
    await _send(_requirePrinter(), [
      _center,
      _boldOn,
      'CLUB DEAL CAFE',
      _boldOff,
      'WINDOWS POS58 TEST',
      _separator,
      'USB thermal printer connected',
      'Test print successful',
      _separator,
      '',
      'Thank you!',
      '',
    ], jobName: 'Club Deal printer test');
  }

  Future<void> printOrder(RestaurantOrder order) async {
    final lines = <String>[
      _center,
      _boldOn,
      'CLUB DEAL CAFE',
      _boldOff,
      'ORDER RECEIPT',
      _left,
      _separator,
      'Order: #${order.id}',
      'Customer: ${order.customerName}',
      if (order.phone.isNotEmpty) 'Phone: ${order.phone}',
      'Table: ${order.table}',
      'Status: ${order.status.name.toUpperCase()}',
      if (order.createdAt != null) 'Date: ${order.createdAt}',
      _separator,
      ...order.items.map(
        (item) =>
            _fit('${item.name} x${item.qty}', 22) +
            'Rs.${item.total.toStringAsFixed(2)}',
      ),
      _separator,
      _boldOn,
      'TOTAL: Rs.${order.total.toStringAsFixed(2)}',
      _boldOff,
      if (order.note.isNotEmpty) 'Note: ${order.note}',
      '',
      _center,
      'Thank you. Visit again!',
      '',
      '',
    ];
    await _send(
      _requirePrinter(),
      lines,
      jobName: 'Club Deal order ${order.id}',
    );
  }

  static const String _center = '\u001b\u0061\u0001';
  static const String _left = '\u001b\u0061\u0000';
  static const String _boldOn = '\u001b\u0045\u0001';
  static const String _boldOff = '\u001b\u0045\u0000';
  static const String _separator = '--------------------------------';

  String _fit(String value, int width) {
    if (value.length >= width) return '${value.substring(0, width)} ';
    return value.padRight(width);
  }

  Future<void> _send(
    Printer printer,
    List<String> lines, {
    required String jobName,
  }) async {
    final bytes = <int>[
      0x1B, 0x40, // Initialize
      ...lines.join('\n').codeUnits,
      0x0A,
      0x0A,
      0x1D, 0x56, 0x00, // Full cut (ignored by printers without a cutter)
    ];
    final success = await _printing.rawDataToPrinter(
      printer.name,
      Uint8List.fromList(bytes),
      docName: jobName,
    );
    if (!success) {
      throw StateError(
        'Windows could not send the receipt to ${printer.name}.',
      );
    }
  }
}

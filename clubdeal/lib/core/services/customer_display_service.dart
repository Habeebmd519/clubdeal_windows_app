import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order_model.dart';

enum CustomerDisplayProtocol { zktecoLed8Digit, escPos, cd5220 }

class CustomerDisplayService extends ChangeNotifier {
  CustomerDisplayService() { _initialize(); }

  static const _enabledKey = 'clubdeal_customer_display_enabled';
  static const _portKey = 'clubdeal_customer_display_port';
  static const _baudKey = 'clubdeal_customer_display_baud';
  static const _protocolKey = 'clubdeal_customer_display_protocol';

  bool enabled = false;
  bool busy = false;
  String selectedPort = 'COM1';
  int baudRate = 9600;
  CustomerDisplayProtocol protocol = CustomerDisplayProtocol.zktecoLed8Digit;
  List<String> ports = const [];
  String? lastError;
  String status = 'Not configured';

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_enabledKey) ?? false;
      selectedPort = prefs.getString(_portKey) ?? 'COM1';
      baudRate = prefs.getInt(_baudKey) ?? 9600;
      final savedProtocol = prefs.getString(_protocolKey);
      // Migrate the former CD5220 default to numeric mode for this terminal's
      // built-in 8-character LED. Preserve an explicitly selected ESC/POS mode.
      protocol = savedProtocol == null || savedProtocol == 'cd5220'
          ? CustomerDisplayProtocol.zktecoLed8Digit
          : CustomerDisplayProtocol.values.firstWhere(
              (value) => value.name == savedProtocol,
              orElse: () => CustomerDisplayProtocol.zktecoLed8Digit,
            );
      if (savedProtocol == null || savedProtocol == 'cd5220') {
        await prefs.setString(_protocolKey, protocol.name);
      }
    } catch (_) {}
    await refreshPorts();
    notifyListeners();
  }

  Future<void> refreshPorts() async {
    if (!Platform.isWindows) {
      ports = const [];
      lastError = 'Serial customer displays are supported in the Windows app.';
      notifyListeners();
      return;
    }
    try {
      final result = await _runPowerShell(r'''
$ErrorActionPreference = 'Stop'
$names = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)
ConvertTo-Json -InputObject $names -Compress
''');
      final output = result.stdout.toString().trim();
      final decoded = output.isEmpty ? <dynamic>[] : jsonDecode(output);
      ports = decoded is List
          ? decoded.map((value) => value.toString()).toList()
          : <String>[decoded.toString()];
      if (ports.isEmpty) {
        status = 'No serial ports detected';
      } else if (!ports.contains(selectedPort)) {
        status = 'Saved port $selectedPort is not currently listed';
      } else {
        status = 'Port available';
      }
      lastError = null;
    } catch (error) {
      lastError = 'Could not list serial ports: $error';
      status = 'Port scan failed';
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    status = value ? 'Enabled (waiting for display test)' : 'Disabled';
    notifyListeners();
  }

  Future<void> configure({
    String? port,
    int? baud,
    CustomerDisplayProtocol? selectedProtocol,
  }) async {
    if (port != null) selectedPort = port;
    if (baud != null) baudRate = baud;
    if (selectedProtocol != null) protocol = selectedProtocol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_portKey, selectedPort);
    await prefs.setInt(_baudKey, baudRate);
    await prefs.setString(_protocolKey, protocol.name);
    lastError = null;
    status = 'Configuration saved';
    notifyListeners();
  }

  Future<void> testConnection() async {
    await _sendBytes(const <int>[], openOnly: true);
    status = 'Serial port opened successfully';
    notifyListeners();
  }

  Future<void> testDisplay() async {
    if (protocol == CustomerDisplayProtocol.zktecoLed8Digit) {
      // Minimal raw numeric probe for the built-in 8-character LED.
      // ZKTeco does not publish this controller's serial frame specification.
      await _sendBytes(ascii.encode('12345678'));
    } else {
      await _showLines('CLUB DEAL', 'DISPLAY TEST OK');
    }
    status = 'Test data sent';
    notifyListeners();
  }

  /// Called after the customer receipt has been successfully queued.
  Future<void> showPrintedTotal(double total) async {
    if (!enabled) return;
    if (!total.isFinite || total < 0) {
      throw ArgumentError.value(total, 'total', 'Must be a valid non-negative amount.');
    }
    if (protocol == CustomerDisplayProtocol.zktecoLed8Digit) {
      var value = total.toStringAsFixed(2);
      if (value.length > 8) value = total.toStringAsFixed(0);
      if (value.length > 8) {
        throw RangeError('Amount \${total.toStringAsFixed(2)} does not fit the 8-character LED display.');
      }
      await _sendBytes(ascii.encode(value.padLeft(8)));
    } else {
      await _showLines('CLUB DEAL', 'TOTAL Rs \${total.toStringAsFixed(2)}');
    }
  }

  Future<void> showOrder(RestaurantOrder order) async {
    if (!enabled) return;
    final item = order.items.isEmpty ? null : order.items.last;
    final first = item == null
        ? 'ORDER ${order.id}'
        : '${item.qty}x ${item.name}';
    final second = 'TOTAL Rs ${order.total.toStringAsFixed(0)}';
    await _showLines(first, second);
  }

  Future<void> showPayment(double total) async {
    if (!enabled) return;
    await _showLines('PAYMENT RECEIVED', 'TOTAL Rs ${total.toStringAsFixed(0)}');
  }

  Future<void> clearDisplay() async {
    if (!enabled) return;
    if (protocol == CustomerDisplayProtocol.zktecoLed8Digit) {
      await _sendBytes(ascii.encode('        '));
    } else {
      await _sendBytes(const <int>[0x0C]);
    }
  }

  Future<void> _showLines(String first, String second) async {
    final line1 = _fitAscii(first, 20);
    final line2 = _fitAscii(second, 20);
    final bytes = <int>[];
    if (protocol == CustomerDisplayProtocol.zktecoLed8Digit) {
      throw StateError('The built-in LED supports numeric totals only.');
    } else if (protocol == CustomerDisplayProtocol.escPos) {
      bytes.addAll([0x1B, 0x40, 0x0C]);
      bytes.addAll(ascii.encode(line1));
      bytes.addAll([0x0D, 0x0A]);
      bytes.addAll(ascii.encode(line2));
      bytes.add(0x0D);
    } else {
      // CD5220 string-display commands: ESC Q A / ESC Q B select row 1 / 2.
      bytes.add(0x0C);
      bytes.addAll([0x1B, 0x51, 0x41, 0x0D]);
      bytes.addAll(ascii.encode(line1));
      bytes.add(0x0D);
      bytes.addAll([0x1B, 0x51, 0x42, 0x0D]);
      bytes.addAll(ascii.encode(line2));
      bytes.add(0x0D);
    }
    await _sendBytes(bytes);
  }

  String _fitAscii(String value, int width) {
    final safe = value
        .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return safe.length > width
        ? safe.substring(0, width)
        : safe.padRight(width);
  }

  Future<void> _sendBytes(List<int> bytes, {bool openOnly = false}) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Customer display requires Windows serial ports.');
    }
    if (!RegExp(r'^COM[1-9][0-9]*$', caseSensitive: false).hasMatch(selectedPort)) {
      throw StateError('Select a valid COM port.');
    }
    if (![2400, 4800, 9600, 19200].contains(baudRate)) {
      throw StateError('Unsupported baud rate.');
    }

    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final encoded = base64Encode(Uint8List.fromList(bytes));
      final script = r'''
$ErrorActionPreference = 'Stop'
$portName = '__PORT__'
$baud = __BAUD__
$data = [Convert]::FromBase64String('__BYTES__')
$serial = [System.IO.Ports.SerialPort]::new(
  $portName, $baud,
  [System.IO.Ports.Parity]::None,
  8,
  [System.IO.Ports.StopBits]::One
)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.ReadTimeout = 500
$serial.WriteTimeout = 1500
try {
  $serial.Open()
  if ($data.Length -gt 0) {
    $serial.Write($data, 0, $data.Length)
    $serial.BaseStream.Flush()
  }
  Start-Sleep -Milliseconds 100
  Write-Output 'CUSTOMER_DISPLAY_OK'
} finally {
  if ($serial.IsOpen) { $serial.Close() }
  $serial.Dispose()
}
'''
          .replaceAll('__PORT__', selectedPort)
          .replaceAll('__BAUD__', baudRate.toString())
          .replaceAll('__BYTES__', encoded);
      await _runPowerShell(script);
      status = openOnly ? 'Serial port opened successfully' : 'Display data sent';
    } catch (error) {
      lastError = '$error';
      status = 'Display operation failed';
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<ProcessResult> _runPowerShell(String script) async {
    final directory = await Directory.systemTemp.createTemp('clubdeal_display_');
    final file = File('${directory.path}${Platform.pathSeparator}display.ps1');
    try {
      final units = script.codeUnits;
      final bytes = Uint8List(2 + units.length * 2)
        ..[0] = 0xff
        ..[1] = 0xfe;
      for (var i = 0; i < units.length; i++) {
        bytes[2 + i * 2] = units[i] & 0xff;
        bytes[3 + i * 2] = (units[i] >> 8) & 0xff;
      }
      await file.writeAsBytes(bytes, flush: true);
      final args = [
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        file.path,
      ];
      final result = await Process.run('powershell.exe', args, runInShell: false);
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
      try {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      } catch (_) {}
    }
  }
}

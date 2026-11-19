import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/order_model.dart';

/// Sends ESC/POS tickets directly to a Wi-Fi/Ethernet thermal printer.
/// The printer must support RAW ESC/POS over TCP (normally port 9100).
class NetworkEscPosPrinter {
  NetworkEscPosPrinter({required this.host, this.port = 9100});
  final String host;
  final int port;
  static const int _columns = 32;

  Future<void> printTest() async {
    final bytes = _begin();
    _center(bytes);
    _bold(bytes, true);
    _large(bytes, true);
    _line(bytes, 'CLUB DEAL');
    _large(bytes, false);
    _bold(bytes, false);
    _line(bytes, 'WI-FI PRINTER TEST');
    _line(bytes, '--------------------------------');
    _left(bytes);
    _line(bytes, 'Network connection is working.');
    _line(bytes, 'Host: $host:$port');
    _line(bytes, DateTime.now().toLocal().toString());
    _finish(bytes);
    await _send(bytes);
  }

  Future<void> printKitchenTicket(RestaurantOrder order, {bool revised = false}) async {
    final bytes = _begin();
    _center(bytes);
    _bold(bytes, true);
    _line(bytes, 'CLUB DEAL - KITCHEN');
    _line(bytes, revised ? 'UPDATED KITCHEN TICKET' : 'KITCHEN ORDER TICKET');
    _bold(bytes, false);
    _line(bytes, '--------------------------------');
    _left(bytes);
    _line(bytes, 'Order: ${order.id}');
    _line(bytes, 'Table / Token: ${order.table}');
    _line(bytes, 'Customer: ${order.customerName}');
    if (order.createdAt != null) _line(bytes, 'Time: ${order.createdAt!.toLocal()}');
    _line(bytes, '--------------------------------');
    for (final item in order.items) {
      _bold(bytes, true);
      _line(bytes, '${item.qty} x ${item.name}');
      _bold(bytes, false);
    }
    if (order.note.trim().isNotEmpty) _line(bytes, 'NOTE: ${order.note}');
    _line(bytes, '--------------------------------');
    _finish(bytes);
    await _send(bytes);
  }

  Future<void> printCancellationTicket(RestaurantOrder order, String reason) async {
    final bytes = _begin();
    _center(bytes);
    _bold(bytes, true);
    _large(bytes, true);
    _line(bytes, 'ORDER CANCELLED');
    _large(bytes, false);
    _line(bytes, 'CLUB DEAL');
    _bold(bytes, false);
    _left(bytes);
    _line(bytes, 'Order: ${order.id}');
    _line(bytes, 'Table / Token: ${order.table}');
    _line(bytes, 'Customer: ${order.customerName}');
    _line(bytes, 'Reason: $reason');
    _center(bytes);
    _bold(bytes, true);
    _line(bytes, 'DO NOT PREPARE THIS ORDER');
    _bold(bytes, false);
    _finish(bytes);
    await _send(bytes);
  }

  Future<void> printOrder(
    RestaurantOrder order, {
    PaymentMethod? paymentMethod,
    String? vpa,
    String? upiUri,
  }) async {
    final date = order.createdAt?.toLocal() ?? DateTime.now();
    final paidBy = paymentMethod ?? order.paymentMethod;
    final bytes = _begin();

    _center(bytes);
    _bold(bytes, true);
    _large(bytes, true);
    _line(bytes, 'CLUB DEAL');
    _large(bytes, false);
    _line(bytes, 'KOCHI');
    _bold(bytes, false);
    _line(bytes, 'Kaloor - Kadavanthra Road');
    _line(bytes, 'Kathrikadavu, Opp. Popees');
    _line(bytes, 'kochiclubdeal@gmail.com');
    _line(bytes, '+91 95622 08806');
    _line(bytes, '+91 96057 91139');
    _rule(bytes);

    _bold(bytes, true);
    _line(bytes, 'BILL / RECEIPT');
    _bold(bytes, false);
    _left(bytes);
    _line(bytes, 'Bill: ${order.id}');
    _line(bytes, 'Date: ${_date(date)}');
    _line(bytes, 'Time: ${_time(date)}');
    _line(bytes, 'Customer: ${order.customerName}');
    if (order.phone.trim().isNotEmpty) _line(bytes, 'Phone: ${order.phone}');
    _line(bytes, 'Table: ${order.table}');
    _rule(bytes);

    _bold(bytes, true);
    _pair(bytes, 'ITEM', 'AMOUNT');
    _bold(bytes, false);
    for (final item in order.items) {
      _bold(bytes, true);
      _line(bytes, item.name);
      _bold(bytes, false);
      _pair(
        bytes,
        '${item.qty} x Rs.${item.price.toStringAsFixed(2)}',
        'Rs.${item.total.toStringAsFixed(2)}',
      );
    }
    _rule(bytes);
    _pair(bytes, 'Subtotal', 'Rs.${order.total.toStringAsFixed(2)}');
    _bold(bytes, true);
    _pair(bytes, 'GRAND TOTAL', 'Rs.${order.total.toStringAsFixed(2)}');
    _bold(bytes, false);

    _center(bytes);
    _bold(bytes, true);
    _line(
      bytes,
      '${paidBy != null ? 'PAID' : order.status.name.toUpperCase()} / ${paidBy?.name.toUpperCase() ?? 'PAYMENT DUE'}',
    );
    _bold(bytes, false);

    if (order.note.trim().isNotEmpty) {
      _left(bytes);
      _line(bytes, 'Note: ${order.note}');
    }

    if (upiUri != null && vpa != null) {
      _rule(bytes);
      _center(bytes);
      _bold(bytes, true);
      _line(bytes, 'SCAN TO PAY');
      _line(bytes, 'Amount: Rs.${order.total.toStringAsFixed(2)}');
      _bold(bytes, false);
      _qr(bytes, upiUri);
      _line(bytes, 'UPI ID: $vpa');
    } else {
      _rule(bytes);
      _center(bytes);
      _line(bytes, 'UPI QR NOT AVAILABLE');
    }

    _rule(bytes);
    _center(bytes);
    _bold(bytes, true);
    _line(bytes, 'Thank you! Visit again.');
    _bold(bytes, false);
    _line(bytes, 'Powered by Club Deal');
    _finish(bytes);
    await _send(bytes);
  }

  List<int> _begin() => <int>[0x1b, 0x40];
  void _finish(List<int> bytes) => bytes.addAll(<int>[0x1b, 0x64, 0x04]);
  void _left(List<int> bytes) => bytes.addAll(<int>[0x1b, 0x61, 0x00]);
  void _center(List<int> bytes) => bytes.addAll(<int>[0x1b, 0x61, 0x01]);
  void _bold(List<int> bytes, bool enabled) =>
      bytes.addAll(<int>[0x1b, 0x45, enabled ? 1 : 0]);
  void _large(List<int> bytes, bool enabled) =>
      bytes.addAll(<int>[0x1d, 0x21, enabled ? 0x11 : 0x00]);
  void _rule(List<int> bytes) => _line(bytes, '-' * _columns);

  void _line(List<int> bytes, String value) {
    for (final row in _wrap(_toPrinterText(value), _columns)) {
      bytes.addAll(ascii.encode(row));
      bytes.add(0x0a);
    }
  }

  void _pair(List<int> bytes, String left, String right) {
    final a = _toPrinterText(left);
    final b = _toPrinterText(right);
    final gap = _columns - a.length - b.length;
    if (gap >= 1) {
      final spaces = List<String>.filled(gap, ' ').join();
      _line(bytes, '$a$spaces$b');
    } else {
      _line(bytes, a);
      _line(bytes, b);
    }
  }

  List<String> _wrap(String value, int width) {
    if (value.isEmpty) return <String>[''];
    final result = <String>[];
    var line = '';
    for (final word in value.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      var remaining = word;
      while (remaining.length > width) {
        if (line.isNotEmpty) {
          result.add(line);
          line = '';
        }
        result.add(remaining.substring(0, width));
        remaining = remaining.substring(width);
      }
      final candidate = line.isEmpty ? remaining : '$line $remaining';
      if (candidate.length <= width) {
        line = candidate;
      } else {
        if (line.isNotEmpty) result.add(line);
        line = remaining;
      }
    }
    if (line.isNotEmpty) result.add(line);
    return result;
  }

  String _toPrinterText(String value) => value
      .replaceAll('₹', 'Rs.')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '?');

  void _qr(List<int> bytes, String data) {
    final payload = ascii.encode(_toPrinterText(data));
    final length = payload.length + 3;
    final pL = length & 0xff;
    final pH = (length >> 8) & 0xff;
    bytes.addAll(<int>[0x1d, 0x28, 0x6b, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    bytes.addAll(<int>[0x1d, 0x28, 0x6b, 0x03, 0x00, 0x31, 0x43, 0x06]);
    bytes.addAll(<int>[0x1d, 0x28, 0x6b, 0x03, 0x00, 0x31, 0x45, 0x31]);
    bytes.addAll(<int>[0x1d, 0x28, 0x6b, pL, pH, 0x31, 0x50, 0x30]);
    bytes.addAll(payload);
    bytes.addAll(<int>[0x1d, 0x28, 0x6b, 0x03, 0x00, 0x31, 0x51, 0x30]);
    bytes.add(0x0a);
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String _time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  Future<void> _send(List<int> bytes) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 6),
      );
      socket.add(bytes);
      await socket.flush().timeout(const Duration(seconds: 12));
    } on SocketException catch (error) {
      throw StateError(
        'Could not reach network printer at $host:$port. Check its Wi-Fi, IP address and RAW/ESC-POS port. Details: $error',
      );
    } on TimeoutException {
      throw StateError(
        'Network printer at $host:$port did not respond before the timeout. Check the IP address and printer network status.',
      );
    } finally {
      await socket?.close();
    }
  }
}

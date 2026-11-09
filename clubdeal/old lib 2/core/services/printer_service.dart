import '../models/order_model.dart';

/// Windows printer abstraction.
///
/// Do not use `blue_thermal_printer` in the Windows build; that package is
/// Android-oriented. This interface keeps the UI independent from the
/// eventual ESC/POS/Windows printer implementation.
class PrinterService {
  bool _connected = false;

  bool get isConnected => _connected;

  Future<void> connect() async {
    throw UnsupportedError(
      'Windows printer driver/ESC-POS integration must be configured.',
    );
  }

  Future<void> disconnect() async {
    _connected = false;
  }

  Future<void> testPrint() async {
    throw UnsupportedError(
      'Windows printer integration is not configured yet.',
    );
  }

  Future<void> printOrder(RestaurantOrder order) async {
    throw UnsupportedError(
      'Windows printer integration is not configured yet.',
    );
  }
}

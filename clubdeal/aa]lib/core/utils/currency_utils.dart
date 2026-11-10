import 'package:intl/intl.dart';

final NumberFormat inrCurrency = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
String formatInr(num value) => inrCurrency.format(value);

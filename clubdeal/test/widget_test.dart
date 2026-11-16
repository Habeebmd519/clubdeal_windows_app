import 'package:flutter_test/flutter_test.dart';
import 'package:clubdeal/core/utils/currency_utils.dart';

void main() {
  test('currency formatter uses Indian rupee formatting', () {
    expect(formatInr(1250), contains('1,250'));
    expect(formatInr(1250), contains('₹'));
  });
}

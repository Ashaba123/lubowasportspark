import 'package:flutter_test/flutter_test.dart';

import 'package:lubowa_sports_park/features/booking/booking_device_store.dart';

void main() {
  test('isValidBookingPhone accepts local and international Ugandan formats', () {
    expect(isValidBookingPhone('0772 123456'), isTrue);
    expect(isValidBookingPhone('772123456'), isTrue);
    expect(isValidBookingPhone('+256 772 123456'), isTrue);
    expect(isValidBookingPhone('12345'), isFalse);
    expect(isValidBookingPhone('abc'), isFalse);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:society_connect/features/auth/presentation/auth_widgets.dart';

void main() {
  group('registration field validation', () {
    test('requires a value and accepts trimmed text', () {
      expect(requiredField(null), 'This field is required.');
      expect(requiredField('   ', label: 'Name'), 'Name is required.');
      expect(requiredField('  Neha  ', label: 'Name'), isNull);
    });

    test('validates email format', () {
      expect(validEmail('member@example.org'), isNull);
      expect(validEmail(' member@example.org '), isNull);
      expect(validEmail('not-an-email'), isNotNull);
      expect(validEmail(''), isNotNull);
    });

    test('requires exactly 10 mobile digits', () {
      expect(validMobile('9876543210'), isNull);
      expect(validMobile(' 9876543210 '), isNull);
      expect(validMobile('+919876543210'), 'Enter a 10-digit mobile number.');
      expect(validMobile('987 654 3210'), isNotNull);
      expect(validMobile('123456789'), isNotNull);
      expect(validMobile('12345678901'), isNotNull);
      expect(validMobile('123'), isNotNull);
      expect(validMobile('phone'), isNotNull);
    });

    test('requires passwords to contain at least eight characters', () {
      expect(validPassword('12345678'), isNull);
      expect(
          validPassword('1234567'), 'Password must be at least 8 characters.');
      expect(validPassword(''), isNotNull);
      expect(validPassword(null), isNotNull);
    });
  });
}

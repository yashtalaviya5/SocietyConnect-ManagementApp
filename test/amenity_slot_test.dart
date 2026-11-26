import 'package:flutter_test/flutter_test.dart';
import 'package:society_connect/features/community/data/society_repository.dart';

void main() {
  group('amenitySlotKeys', () {
    final day = DateTime(2026, 11, 7);

    test('two requests that overlap share a reservation key', () {
      final first = amenitySlotKeys(
        'Party Hall',
        DateTime(day.year, day.month, day.day, 10),
        DateTime(day.year, day.month, day.day, 11),
      );
      final second = amenitySlotKeys(
        'Party Hall',
        DateTime(day.year, day.month, day.day, 10, 30),
        DateTime(day.year, day.month, day.day, 11, 30),
      );

      expect(first.toSet().intersection(second.toSet()), isNotEmpty);
    });

    test('adjacent bookings do not share a reservation key', () {
      final first = amenitySlotKeys(
        'Community Hall',
        DateTime(day.year, day.month, day.day, 10),
        DateTime(day.year, day.month, day.day, 11),
      );
      final second = amenitySlotKeys(
        'Community Hall',
        DateTime(day.year, day.month, day.day, 11),
        DateTime(day.year, day.month, day.day, 12),
      );

      expect(first.toSet().intersection(second.toSet()), isEmpty);
    });

    test('amenities and days reserve independently', () {
      final first = amenitySlotKeys(
        'Party Hall',
        DateTime(day.year, day.month, day.day, 10),
        DateTime(day.year, day.month, day.day, 11),
      );
      final otherAmenity = amenitySlotKeys(
        'Garden',
        DateTime(day.year, day.month, day.day, 10),
        DateTime(day.year, day.month, day.day, 11),
      );
      final otherDay = amenitySlotKeys(
        'Party Hall',
        DateTime(day.year, day.month, day.day + 1, 10),
        DateTime(day.year, day.month, day.day + 1, 11),
      );

      expect(first.toSet().intersection(otherAmenity.toSet()), isEmpty);
      expect(first.toSet().intersection(otherDay.toSet()), isEmpty);
    });
  });
}

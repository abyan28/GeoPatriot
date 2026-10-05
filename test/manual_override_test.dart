import 'package:flutter_test/flutter_test.dart';
import 'package:geotag_camera/capture/manual_override.dart';

void main() {
  group('parseCoordinatePair', () {
    test('menerima format koma, koma+spasi, dan spasi', () {
      for (final input in ['-9.620308,124.879609', '-9.620308, 124.879609', ' -9.620308 124.879609 ']) {
        final pair = parseCoordinatePair(input);
        expect(pair, isNotNull, reason: input);
        expect(pair!.latitude, -9.620308);
        expect(pair.longitude, 124.879609);
      }
    });

    test('menolak format salah dan nilai di luar rentang', () {
      for (final input in ['', 'abc', '10', '91,0', '0,181', '-91,10', '1,2,3']) {
        expect(parseCoordinatePair(input), isNull, reason: input);
      }
    });
  });

  test('ManualOverride kosong dan hasCoordinates', () {
    expect(const ManualOverride().isEmpty, isTrue);
    final manual = ManualOverride(latitude: 1, longitude: 2, timestamp: DateTime(2026, 10, 6));
    expect(manual.isEmpty, isFalse);
    expect(manual.hasCoordinates, isTrue);
    expect(manual.toLocationSnapshot(capturedAt: DateTime(2026, 10, 6)).accuracy, isNull);
  });
}

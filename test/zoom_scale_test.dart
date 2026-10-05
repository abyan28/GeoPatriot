import 'package:flutter_test/flutter_test.dart';
import 'package:geotag_camera/camera/zoom_ruler_control.dart';

void main() {
  test('stops cuma menyertakan kandidat yang berada dalam rentang device', () {
    final scale = ZoomScale(minZoom: 1, maxZoom: 4);

    expect(scale.stops, [1.0, 2.0, 3.0, 4.0]);
  });

  test('stops menyertakan minZoom sendiri walau bukan kandidat umum', () {
    final scale = ZoomScale(minZoom: 0.6, maxZoom: 8);

    expect(scale.stops.first, 0.6);
    expect(scale.stops.last, 8.0);
    expect(scale.stops, contains(1.0));
    expect(scale.stops, contains(2.0));
    expect(scale.stops, contains(3.0));
    expect(scale.stops, contains(5.0));
  });

  test('valueToFraction dan fractionToValue saling berkebalikan', () {
    final scale = ZoomScale(minZoom: 1, maxZoom: 10);

    for (final zoom in [1.0, 2.0, 3.5, 7.0, 10.0]) {
      final fraction = scale.valueToFraction(zoom);
      expect(scale.fractionToValue(fraction), closeTo(zoom, 0.001));
    }
  });

  test('valueToFraction di ujung rentang menghasilkan 0.0 dan 1.0', () {
    final scale = ZoomScale(minZoom: 1, maxZoom: 5);

    expect(scale.valueToFraction(1), 0.0);
    expect(scale.valueToFraction(5), 1.0);
  });

  test('nearestStop memilih stop terdekat tanpa mengubah nilai zoom asli', () {
    final scale = ZoomScale(minZoom: 1, maxZoom: 5);

    expect(scale.nearestStop(1.2), 1.0);
    expect(scale.nearestStop(2.6), 3.0);
    expect(scale.nearestStop(4.9), 5.0);
  });

  group('defaultZoomFor', () {
    test('HP multi-lensa (min 0.6) mulai di 1x, bukan ultra-wide', () {
      expect(defaultZoomFor(minZoom: 0.6, maxZoom: 10), 1.0);
    });

    test('kamera tanpa ultra-wide (min 1) tetap 1x', () {
      expect(defaultZoomFor(minZoom: 1, maxZoom: 4), 1.0);
    });

    test('dijepit ke maxZoom bila kamera tidak bisa sampai 1x', () {
      expect(defaultZoomFor(minZoom: 0.5, maxZoom: 0.8), 0.8);
    });
  });
}

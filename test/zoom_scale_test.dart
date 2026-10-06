import 'package:flutter/material.dart';
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

  group('formatLabel', () {
    test('format label .6 untuk stop di bawah 1.0', () {
      expect(ZoomScale.formatLabel(0.6), '.6');
      expect(ZoomScale.formatLabel(0.5), '.5');
    });

    test('format label 1x untuk 1.0', () {
      expect(ZoomScale.formatLabel(1.0), '1x');
    });

    test('format label angka bulat untuk stop > 1.0', () {
      expect(ZoomScale.formatLabel(2.0), '2');
      expect(ZoomScale.formatLabel(3.0), '3');
      expect(ZoomScale.formatLabel(10.0), '10');
    });
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

  group('ZoomRulerControl Widget', () {
    testWidgets('menampilkan idle pill secara default dengan label preset', (tester) async {
      double currentZoom = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomRulerControl(
              minZoom: 0.6,
              maxZoom: 3.0,
              currentZoom: currentZoom,
              onZoomChanged: (z) => currentZoom = z,
              length: 220,
            ),
          ),
        ),
      );

      // Verifikasi stops muncul
      expect(find.text('.6'), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Tap preset 2
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(currentZoom, 2.0);
    });

    testWidgets('beralih ke expanded ruler saat isPinching = true dan kembali saat tutup', (tester) async {
      double currentZoom = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ZoomRulerControl(
                  minZoom: 0.6,
                  maxZoom: 3.0,
                  currentZoom: currentZoom,
                  onZoomChanged: (z) => setState(() => currentZoom = z),
                  length: 220,
                  isPinching: true,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expanded ruler harus memiliki tombol close (Icons.close) dan badge zoom
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);

      // Tap tombol close
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Kembali ke idle pill
      expect(find.byKey(const ValueKey('idle_pill')), findsOneWidget);
    });
  });
}

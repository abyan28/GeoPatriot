import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Kandidat level zoom yang ditampilkan sebagai tanda/stop di ruler —
/// nilai umum titik transisi lensa (ultra-wide/wide/tele) pada kamera HP
/// modern. Package `camera` TIDAK menyediakan daftar stop diskrit milik
/// device (dicek ke source `camera_controller.dart`: cuma ada
/// `getMinZoomLevel`/`getMaxZoomLevel`/`setZoomLevel`, tidak ada info lensa
/// fisik) — jadi kandidat ini DISARING supaya cuma yang benar-benar berada
/// dalam rentang [minZoom, maxZoom] milik device yang dipakai, bukan
/// ditampilkan buta tanpa memandang kemampuan device.
const _zoomStopCandidates = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0];

/// Zoom awal saat kamera dibuka: 1x (lensa utama), dijepit ke rentang device.
/// Bukan [minZoom] — di HP multi-lensa minZoom adalah ultra-wide (mis. 0.6x),
/// yang kualitasnya lebih rendah dan bukan kebiasaan aplikasi kamera pada
/// umumnya. Kamera yang tidak bisa sampai 1x (maxZoom < 1) memakai maxZoom.
double defaultZoomFor({required double minZoom, required double maxZoom}) {
  return 1.0.clamp(minZoom, maxZoom);
}

/// Logika murni (bukan widget) untuk kontrol zoom ruler: menghitung stop
/// mana yang relevan untuk [minZoom]/[maxZoom] milik device, dan konversi
/// dua arah antara nilai zoom dan posisi relatif (0.0-1.0) di sepanjang
/// ruler. Dipisah dari widget supaya gampang diuji/ditelusuri terpisah
/// dari kode rendering/gesture.
class ZoomScale {
  ZoomScale({required this.minZoom, required this.maxZoom})
      : assert(maxZoom > minZoom, 'maxZoom harus lebih besar dari minZoom'),
        stops = _computeStops(minZoom, maxZoom);

  final double minZoom;
  final double maxZoom;

  /// Level zoom yang ditandai di ruler, terurut naik, selalu menyertakan
  /// [minZoom] sebagai titik awal.
  final List<double> stops;

  static List<double> _computeStops(double minZoom, double maxZoom) {
    final stops = <double>{minZoom};
    for (final candidate in _zoomStopCandidates) {
      if (candidate > minZoom && candidate < maxZoom) {
        stops.add(candidate);
      }
    }
    stops.add(maxZoom);
    final sorted = stops.toList()..sort();
    return sorted;
  }

  /// Konversi nilai zoom ke posisi relatif [0.0, 1.0] di sepanjang ruler,
  /// pakai skala LOGARITMIK supaya jarak antar stop (0.5/1/2/3/5/10)
  /// terlihat proporsional secara visual, bukan numerik linear (yang bikin
  /// 0.5-1 dempet dan 5-10 kepanjangan).
  double valueToFraction(double zoom) {
    final clamped = zoom.clamp(minZoom, maxZoom);
    final logMin = math.log(minZoom);
    final logMax = math.log(maxZoom);
    if (logMax == logMin) return 0;
    return (math.log(clamped) - logMin) / (logMax - logMin);
  }

  /// Kebalikan dari [valueToFraction]: posisi relatif [0.0, 1.0] di ruler
  /// menjadi nilai zoom sesungguhnya.
  double fractionToValue(double fraction) {
    final clampedFraction = fraction.clamp(0.0, 1.0);
    final logMin = math.log(minZoom);
    final logMax = math.log(maxZoom);
    return math.exp(logMin + clampedFraction * (logMax - logMin));
  }

  /// Stop yang paling dekat dengan [zoom], dipakai untuk highlight visual
  /// (BUKAN untuk snapping nilai zoom sungguhan — zoom tetap kontinu/halus).
  double nearestStop(double zoom) {
    return stops.reduce((a, b) => (zoom - a).abs() <= (zoom - b).abs() ? a : b);
  }
}

/// Kontrol zoom ber-gaya ruler (garis + tick + titik level zoom), meniru
/// aplikasi kamera smartphone modern — menggantikan indikator teks sesaat
/// yang sebelumnya cuma muncul saat pinch. Selalu terlihat (persisten)
/// selama kamera aktif.
///
/// SELALU dibangun VERTIKAL (satu tata letak kanonis) — orientasi/rotasi
/// untuk landscape BUKAN ditangani di sini, tapi oleh PEMANGGIL lewat
/// `RotatedBox(quarterTurns: ...)`, pola yang SAMA dengan kontrol lain di
/// app ini (`_RotatedControl` di `camera_screen.dart`). Ini WAJIB karena
/// layar aplikasi ini dikunci portrait secara permanen (`main.dart`/
/// `AndroidManifest.xml`) — piksel layar TIDAK PERNAH benar-benar berputar,
/// jadi "landscape" di sini artinya kontennya yang diputar secara visual.
/// `RotatedBox` menukar lebar/tinggi SAAT LAYOUT (ruler vertikal otomatis
/// jadi tampak horizontal) dan ikut mentransformasi koordinat gesture
/// untuk child-nya, jadi `onVerticalDragUpdate` di dalam sini TETAP BENAR
/// tanpa perlu tahu soal orientasi sama sekali — mencoba membuat versi
/// horizontal terpisah di sini (dicoba sebelumnya) malah SALAH: layar
/// yang tidak pernah berputar membuat versi horizontal buatan tangan
/// tampil dengan teks tegak lurus yang justru miring bagi pengguna yang
/// memiringkan device.
class ZoomRulerControl extends StatelessWidget {
  const ZoomRulerControl({
    super.key,
    required this.minZoom,
    required this.maxZoom,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.length,
  });

  final double minZoom;
  final double maxZoom;
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;

  /// Panjang ruler (selalu di sumbu vertikal-nya sendiri), dalam logical
  /// pixel.
  final double length;

  static const thickness = 56.0;

  @override
  Widget build(BuildContext context) {
    if (maxZoom <= minZoom) return const SizedBox.shrink();

    final scale = ZoomScale(minZoom: minZoom, maxZoom: maxZoom);

    return SizedBox(
      width: thickness,
      height: length,
      child: _ZoomRulerGestureArea(
        scale: scale,
        currentZoom: currentZoom,
        onZoomChanged: onZoomChanged,
      ),
    );
  }
}

/// Area gesture ruler — pisah dari [ZoomRulerControl] supaya penanganan
/// drag (gesture handling) terpisah jelas dari orkestrasi widget publik di
/// atasnya.
class _ZoomRulerGestureArea extends StatelessWidget {
  const _ZoomRulerGestureArea({
    required this.scale,
    required this.currentZoom,
    required this.onZoomChanged,
  });

  final ZoomScale scale;
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;

  void _handleDragUpdate(Offset localPosition, Size size) {
    if (size.height <= 0) return;
    // Ujung ATAS ruler = zoom maksimum (mirip volume/ruler fisik yang
    // "naik" ke atas).
    final rawFraction = 1 - (localPosition.dy / size.height);
    onZoomChanged(scale.fractionToValue(rawFraction));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        void handlePosition(Offset localPosition) => _handleDragUpdate(localPosition, size);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: (details) => handlePosition(details.localPosition),
          onVerticalDragUpdate: (details) => handlePosition(details.localPosition),
          onTapDown: (details) => handlePosition(details.localPosition),
          child: CustomPaint(
            size: size,
            painter: _ZoomRulerPainter(scale: scale, currentZoom: currentZoom),
          ),
        );
      },
    );
  }
}

/// Rendering murni ruler (garis, tick, label, lingkaran indikator) — pisah
/// dari logika gesture/state di atasnya. Selalu digambar VERTIKAL (lihat
/// catatan orientasi di [ZoomRulerControl]), tanpa latar kotak/pil di
/// belakangnya (dihapus atas permintaan user — cukup elemen ruler saja
/// yang menutupi preview, bukan kotaknya).
class _ZoomRulerPainter extends CustomPainter {
  _ZoomRulerPainter({required this.scale, required this.currentZoom});

  final ZoomScale scale;
  final double currentZoom;

  static const _trackColor = Colors.white54;
  static const _tickColor = Colors.white70;
  static const _highlightColor = Colors.amberAccent;
  static const _shadow = [Shadow(color: Colors.black87, blurRadius: 4)];

  @override
  void paint(Canvas canvas, Size size) {
    final crossAxisCenter = size.width / 2;
    final mainAxisExtent = size.height;

    final trackPaint = Paint()
      ..color = _trackColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(crossAxisCenter, 0), Offset(crossAxisCenter, mainAxisExtent), trackPaint);

    final nearest = scale.nearestStop(currentZoom);

    for (final stop in scale.stops) {
      final fraction = scale.valueToFraction(stop);
      final y = (1 - fraction) * mainAxisExtent;
      final isNearest = (stop - nearest).abs() < 0.0001;

      final tickPaint = Paint()
        ..color = isNearest ? _highlightColor : _tickColor
        ..strokeWidth = isNearest ? 3 : 2
        ..strokeCap = StrokeCap.round;
      const tickLength = 10.0;
      canvas.drawLine(
        Offset(crossAxisCenter - tickLength / 2, y),
        Offset(crossAxisCenter + tickLength / 2, y),
        tickPaint,
      );

      final label = stop == stop.roundToDouble() ? '${stop.toInt()}x' : '${stop.toStringAsFixed(1)}x';
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isNearest ? _highlightColor : Colors.white,
            fontSize: 11,
            fontWeight: isNearest ? FontWeight.bold : FontWeight.normal,
            shadows: _shadow,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Label di sisi KIRI tick — ruler menempel di sisi kanan layar saat
      // portrait, jadi ruang di sisi kanannya sendiri sangat terbatas.
      textPainter.paint(
        canvas,
        Offset(crossAxisCenter - 12 - textPainter.width, y - textPainter.height / 2),
      );
    }

    // Lingkaran indikator posisi zoom SAAT INI (bukan cuma stop terdekat).
    final currentFraction = scale.valueToFraction(currentZoom);
    final indicatorCenter = Offset(crossAxisCenter, (1 - currentFraction) * mainAxisExtent);
    canvas.drawCircle(indicatorCenter, 7, Paint()..color = _highlightColor);
    canvas.drawCircle(
      indicatorCenter,
      7,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _ZoomRulerPainter oldDelegate) {
    return oldDelegate.currentZoom != currentZoom ||
        oldDelegate.scale.minZoom != scale.minZoom ||
        oldDelegate.scale.maxZoom != scale.maxZoom;
  }
}

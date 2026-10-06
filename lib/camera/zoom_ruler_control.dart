import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/camera_tokens.dart';

/// Kandidat level zoom yang ditampilkan sebagai tanda/stop di ruler —
/// nilai umum titik transisi lensa (ultra-wide/wide/tele) pada kamera HP
/// modern.
const _zoomStopCandidates = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0];

/// Zoom awal saat kamera dibuka: 1x (lensa utama), dijepit ke rentang device.
double defaultZoomFor({required double minZoom, required double maxZoom}) {
  return 1.0.clamp(minZoom, maxZoom);
}

/// Logika murni (bukan widget) untuk kontrol zoom: menghitung stop mana
/// yang relevan untuk [minZoom]/[maxZoom] milik device, dan konversi dua
/// arah antara nilai zoom dan posisi relatif (0.0-1.0) di sepanjang ruler.
class ZoomScale {
  ZoomScale({required this.minZoom, required this.maxZoom})
      : assert(maxZoom > minZoom, 'maxZoom harus lebih besar dari minZoom'),
        stops = _computeStops(minZoom, maxZoom);

  final double minZoom;
  final double maxZoom;

  /// Level zoom yang ditandai di ruler, terurut naik, selalu menyertakan
  /// [minZoom] sebagai titik awal (bawah) dan [maxZoom] sebagai titik akhir (atas).
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
  /// pakai skala LOGARITMIK supaya proporsional secara visual.
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

  /// Stop yang paling dekat dengan [zoom], dipakai untuk highlight visual.
  double nearestStop(double zoom) {
    return stops.reduce((a, b) => (zoom - a).abs() <= (zoom - b).abs() ? a : b);
  }

  /// Format teks label ringkas ramah tampilan kamera mobile:
  /// - Di bawah 1.0 -> '.6' / '.5' (gaya Samsung Camera)
  /// - 1.0 -> '1x'
  /// - Di atas 1.0 -> '2', '3', '10' (atau '2.5' bila desimal)
  static String formatLabel(double stop, {bool isSelected = false}) {
    if (stop < 1.0) {
      final tenth = (stop * 10).round();
      return '.$tenth';
    }
    if ((stop - 1.0).abs() < 0.05) {
      return '1x';
    }
    if (stop == stop.roundToDouble()) {
      return '${stop.toInt()}';
    }
    return stop.toStringAsFixed(1);
  }
}

/// Kontrol zoom cerdas dua-mode (Samsung Camera style UX):
/// 1. **State Idle (Kapsul Preset):** Kapsul vertikal di sisi kanan dengan
///    pilihan level zoom (.6 di bawah, 1x emas di tengah, 2/3 di atas).
/// 2. **State Active (Penggaris Presisi):** Bertransisi in-place menjadi
///    penggaris vertikal presisi saat dicubit/diseret, menampilkan jarum emas,
///    badge angka zoom (misal '1.6 x'), dan tombol '×' untuk menutup.
/// 3. **Auto-Collapse UX:** Menutup kembali ke kapsul setelah 2.5 detik idle.
class ZoomRulerControl extends StatefulWidget {
  const ZoomRulerControl({
    super.key,
    required this.minZoom,
    required this.maxZoom,
    required this.currentZoom,
    required this.onZoomChanged,
    required this.length,
    this.isPinching = false,
  });

  final double minZoom;
  final double maxZoom;
  final double currentZoom;
  final ValueChanged<double> onZoomChanged;
  final double length;
  final bool isPinching;

  /// Lebar total widget di sisi kanan layar (cukup menampung floating badge
  /// di sebelah kiri dan kapsul/penggaris di sebelah kanan).
  static const thickness = 92.0;

  @override
  State<ZoomRulerControl> createState() => _ZoomRulerControlState();
}

class _ZoomRulerControlState extends State<ZoomRulerControl> {
  bool _isExpanded = false;
  Timer? _collapseTimer;
  double? _lastHapticStop;

  @override
  void initState() {
    super.initState();
    if (widget.isPinching) {
      _isExpanded = true;
    }
  }

  @override
  void didUpdateWidget(covariant ZoomRulerControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPinching && !oldWidget.isPinching) {
      _expand();
    } else if (!widget.isPinching && oldWidget.isPinching) {
      _startCollapseTimer();
    }
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _expand() {
    _collapseTimer?.cancel();
    if (!_isExpanded) {
      setState(() => _isExpanded = true);
    }
  }

  void _collapse() {
    _collapseTimer?.cancel();
    if (_isExpanded) {
      setState(() => _isExpanded = false);
    }
  }

  void _startCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && !widget.isPinching) {
        setState(() => _isExpanded = false);
      }
    });
  }

  void _checkHaptic(double currentZoom, ZoomScale scale) {
    final nearest = scale.nearestStop(currentZoom);
    if ((currentZoom - nearest).abs() < 0.05 && _lastHapticStop != nearest) {
      _lastHapticStop = nearest;
      HapticFeedback.selectionClick();
    } else if ((currentZoom - nearest).abs() > 0.15) {
      _lastHapticStop = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.maxZoom <= widget.minZoom) return const SizedBox.shrink();

    final scale = ZoomScale(minZoom: widget.minZoom, maxZoom: widget.maxZoom);

    return SizedBox(
      width: ZoomRulerControl.thickness,
      height: widget.length,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
              alignment: Alignment.centerRight,
              child: child,
            ),
          );
        },
        child: _isExpanded
            ? _buildExpandedRuler(scale)
            : _buildIdlePill(scale),
      ),
    );
  }

  /// Tampilan State 1: Kapsul preset ringkas vertikal di tepi kanan.
  /// Urutan dari bawah ke atas: .6 di paling bawah, 1x emas di tengah, 2/3 di atas.
  Widget _buildIdlePill(ZoomScale scale) {
    // scale.stops terurut dari minZoom ke maxZoom.
    // Supaya minZoom (.6) di PALING BAWAH, kita balik urutannya di Column
    // (item index 0 Column = atas = maxZoom, item terakhir = bawah = minZoom).
    final reversedStops = scale.stops.reversed.toList();
    final activeStop = scale.nearestStop(widget.currentZoom);

    return Align(
      key: const ValueKey('idle_pill'),
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => _expand(),
        onVerticalDragUpdate: (details) {
          _expand();
        },
        child: Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: BoxDecoration(
            color: CameraTokens.navySurface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: CameraTokens.petrolBlue.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: reversedStops.map((stop) {
              final isSelected = (stop - activeStop).abs() < 0.001;
              final label = ZoomScale.formatLabel(stop, isSelected: isSelected);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onZoomChanged(stop);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutQuad,
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? CameraTokens.brandOchreLight
                          : Colors.transparent,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: CameraTokens.brandOchre.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? CameraTokens.navyBackground
                            : Colors.white.withValues(alpha: 0.90),
                        fontSize: isSelected ? 12.0 : 11.0,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// Tampilan State 2: Penggaris presisi vertikal in-place di tepi kanan
  /// dengan tombol '×' di atas, garis ticks, jarum indikator emas,
  /// dan floating badge '1.6 x' di sebelah kiri jarum.
  Widget _buildExpandedRuler(ZoomScale scale) {
    const rulerWidth = 46.0;
    const closeBtnHeight = 32.0;
    final trackHeight = widget.length - closeBtnHeight - 12.0;

    // Hitung posisi Y jarum emas (0 di atas, trackHeight di bawah).
    // fraction 0 (minZoom .6) -> Y = trackHeight (bawah)
    // fraction 1 (maxZoom)   -> Y = 0 (atas)
    final currentFraction = scale.valueToFraction(widget.currentZoom);
    final needleY = (1 - currentFraction) * trackHeight + closeBtnHeight + 6.0;

    return Stack(
      key: const ValueKey('expanded_ruler'),
      clipBehavior: Clip.none,
      children: [
        // 1. Floating Readout Badge (misal '1.6 x') di sebelah kiri jarum
        Positioned(
          left: 0,
          top: (needleY - 14).clamp(closeBtnHeight, widget.length - 28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: CameraTokens.navySurface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: CameraTokens.brandOchreLight.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${widget.currentZoom.toStringAsFixed(1)}x',
              style: const TextStyle(
                color: CameraTokens.brandOchreLight,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),

        // 2. Kapsul Penggaris Vertikal (di sisi kanan)
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: rulerWidth,
            height: widget.length,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: CameraTokens.navySurface.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: CameraTokens.petrolBlue.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Tombol tutup '×'
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _collapse();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CameraTokens.navyPrimary.withValues(alpha: 0.7),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close,
                      size: 15,
                      color: Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Area canvas ruler vertikal
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (details) {
                      _collapseTimer?.cancel();
                      _handleDrag(details.localPosition.dy, trackHeight, scale);
                    },
                    onVerticalDragUpdate: (details) {
                      _collapseTimer?.cancel();
                      _handleDrag(details.localPosition.dy, trackHeight, scale);
                    },
                    onVerticalDragEnd: (_) => _startCollapseTimer(),
                    onTapDown: (details) {
                      _handleDrag(details.localPosition.dy, trackHeight, scale);
                      _startCollapseTimer();
                    },
                    child: CustomPaint(
                      size: Size(rulerWidth, trackHeight),
                      painter: _VerticalRulerPainter(
                        scale: scale,
                        currentZoom: widget.currentZoom,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleDrag(double dy, double trackHeight, ZoomScale scale) {
    if (trackHeight <= 0) return;
    // dy = 0 adalah atas (maxZoom) -> rawFraction = 1
    // dy = trackHeight adalah bawah (minZoom) -> rawFraction = 0
    final rawFraction = (1 - (dy / trackHeight)).clamp(0.0, 1.0);
    final newZoom = scale.fractionToValue(rawFraction);
    _checkHaptic(newZoom, scale);
    widget.onZoomChanged(newZoom);
  }
}

/// Rendering penggaris vertikal: garis skala, ticks halus, angka label,
/// dan jarum emas horizontal pada posisi zoom aktif.
class _VerticalRulerPainter extends CustomPainter {
  _VerticalRulerPainter({
    required this.scale,
    required this.currentZoom,
  });

  final ZoomScale scale;
  final double currentZoom;

  static const _tickMinorColor = Colors.white38;
  static const _tickMajorColor = Colors.white70;
  static const _shadow = [Shadow(color: Colors.black87, blurRadius: 4)];

  @override
  void paint(Canvas canvas, Size size) {
    final trackX = size.width * 0.42;
    final trackHeight = size.height;

    // 1. Garis track vertikal
    final trackPaint = Paint()
      ..color = CameraTokens.petrolBlue.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(trackX, 0), Offset(trackX, trackHeight), trackPaint);

    final nearest = scale.nearestStop(currentZoom);

    // 2. Minor sub-ticks di antara stops
    final minorTickPaint = Paint()
      ..color = _tickMinorColor
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    const minorTickLength = 5.0;

    for (var i = 0; i < scale.stops.length - 1; i++) {
      final s1 = scale.stops[i];
      final s2 = scale.stops[i + 1];
      final f1 = scale.valueToFraction(s1);
      final f2 = scale.valueToFraction(s2);
      for (var step = 1; step <= 3; step++) {
        final subFraction = f1 + (f2 - f1) * (step / 4);
        final subY = (1 - subFraction) * trackHeight;
        canvas.drawLine(
          Offset(trackX - minorTickLength / 2, subY),
          Offset(trackX + minorTickLength / 2, subY),
          minorTickPaint,
        );
      }
    }

    // 3. Major ticks & label stops
    for (final stop in scale.stops) {
      final fraction = scale.valueToFraction(stop);
      // fraction 0 (minZoom .6) di paling bawah (y = trackHeight)
      // fraction 1 (maxZoom) di paling atas (y = 0)
      final y = (1 - fraction) * trackHeight;
      final isNearest = (stop - nearest).abs() < 0.05;

      // Garis tick horizontal
      const tickLength = 10.0;
      final tickPaint = Paint()
        ..color = isNearest ? CameraTokens.brandOchreLight : _tickMajorColor
        ..strokeWidth = isNearest ? 2.5 : 1.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(trackX - tickLength / 2, y),
        Offset(trackX + tickLength / 2, y),
        tickPaint,
      );

      // Label stop di sisi kanan tick
      final label = ZoomScale.formatLabel(stop);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isNearest ? CameraTokens.brandOchreLight : Colors.white70,
            fontSize: 9.5,
            fontWeight: isNearest ? FontWeight.bold : FontWeight.w500,
            shadows: _shadow,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(trackX + tickLength / 2 + 3, y - textPainter.height / 2),
      );
    }

    // 3. Jarum Indikator Emas Horizontal pada currentZoom
    final currentFraction = scale.valueToFraction(currentZoom);
    final indicatorY = (1 - currentFraction) * trackHeight;

    final needlePaint = Paint()
      ..color = CameraTokens.brandOchreLight
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Garis jarum horizontal menembus track
    canvas.drawLine(
      Offset(trackX - 9, indicatorY),
      Offset(trackX + 9, indicatorY),
      needlePaint,
    );

    // Titik tengah / diamond jarum
    final diamondPaint = Paint()..color = CameraTokens.brandOchreLight;
    canvas.drawCircle(Offset(trackX, indicatorY), 3.5, diamondPaint);
    canvas.drawCircle(
      Offset(trackX, indicatorY),
      3.5,
      Paint()
        ..color = CameraTokens.navyBackground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _VerticalRulerPainter oldDelegate) {
    return oldDelegate.currentZoom != currentZoom ||
        oldDelegate.scale.minZoom != scale.minZoom ||
        oldDelegate.scale.maxZoom != scale.maxZoom;
  }
}

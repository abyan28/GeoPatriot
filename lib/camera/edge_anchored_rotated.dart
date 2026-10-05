import 'package:flutter/material.dart';

/// Sisi layar (dari sudut pandang pengguna) yang bisa dijadikan target
/// penempelan [EdgeAnchoredRotated], diurutkan searah jarum jam mulai dari
/// atas supaya bisa dipakai langsung sebagai index rotasi.
enum ScreenEdge { top, right, bottom, left }

/// Tempel [child] pada satu [targetEdge] (atas/kanan/bawah/kiri) DARI SUDUT
/// PANDANG PENGGUNA, lalu hitung sisi fisik layar yang benar-benar dipakai
/// berdasarkan [quarterTurns] saat ini.
///
/// Layar dikunci portrait (lihat `main.dart`/`AndroidManifest.xml`), jadi
/// piksel layar TIDAK ikut berputar saat device dimiringkan — yang berputar
/// cuma konten di dalamnya lewat `RotatedBox` (lihat `DeviceRotationController`).
/// Akibatnya sisi fisik device yang tetap (atas/kanan/bawah/kiri) berpindah
/// makna dari sudut pandang pengguna sesuai arah kemiringan. Rumus berikut
/// terbukti benar dari analisis geometris (rotasi konten quarterTurns searah
/// jarum jam mengompensasi device yang dimiringkan berlawanan arah):
///   sisi_fisik_yang_dipakai = (sisi_target_dari_sudut_pandang_user + quarterTurns) % 4
///
/// Dibungkus `Center` supaya batasan lebar/tinggi yang diteruskan ke
/// `RotatedBox` selalu longgar (bukan tegas) — mencegah bug ukuran kotak
/// membesar tegas selebar/setinggi layar saat kontennya ditukar orientasi.
class EdgeAnchoredRotated extends StatelessWidget {
  const EdgeAnchoredRotated({
    super.key,
    required this.targetEdge,
    required this.quarterTurns,
    required this.margin,
    required this.child,
    this.extraTopMargin = 0,
    this.extraBottomMargin = 0,
  });

  final ScreenEdge targetEdge;
  final int quarterTurns;
  final double margin;
  final Widget child;

  /// Seperti [extraBottomMargin], tapi untuk sisi fisik atas (mis. supaya
  /// tidak tumpang-tindih dengan HUD status GPS + tombol pengaturan yang
  /// selalu di fisik-atas layar).
  final double extraTopMargin;

  /// Jarak tambahan yang HANYA diterapkan saat sisi fisik yang dipakai
  /// akhirnya adalah bawah (mis. supaya tidak tumpang-tindih dengan baris
  /// tombol kontrol yang selalu ada di fisik-bawah-tengah layar, terlepas
  /// dari sisi target aslinya).
  final double extraBottomMargin;

  @override
  Widget build(BuildContext context) {
    final physicalEdge = ScreenEdge.values[(targetEdge.index + quarterTurns) % 4];
    final rotated = Center(child: RotatedBox(quarterTurns: quarterTurns, child: child));

    switch (physicalEdge) {
      case ScreenEdge.top:
        return Positioned(top: margin + extraTopMargin, left: 0, right: 0, child: rotated);
      case ScreenEdge.right:
        return Positioned(right: margin, top: 0, bottom: 0, child: rotated);
      case ScreenEdge.bottom:
        return Positioned(bottom: margin + extraBottomMargin, left: 0, right: 0, child: rotated);
      case ScreenEdge.left:
        return Positioned(left: margin, top: 0, bottom: 0, child: rotated);
    }
  }
}

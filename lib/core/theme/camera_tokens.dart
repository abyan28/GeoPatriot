import 'package:flutter/material.dart';

/// Token desain semantik khusus antarmuka kamera (HUD), kontrol mengambang,
/// status akurasi GPS, dan identitas visual resmi GeoPatriot
/// (berdasarkan palet resmi Kementerian Transmigrasi RI).
class CameraTokens {
  CameraTokens._();

  // --- Palet Identitas Resmi GeoPatriot (Transmigrasi RI) ---
  /// Deep Midnight Navy (#08111D) - Kanvas latar belakang utama.
  static const Color navyBackground = Color(0xFF08111D);

  /// Deep Petrol Navy (#102E4A) - Warna primer/app bar/elemen gelap terstruktur.
  static const Color navyPrimary = Color(0xFF102E4A);

  /// Card / Surface Navy (#0E2035) - Kontainer kartu & sheet mengambang.
  static const Color navySurface = Color(0xFF0E2035);

  /// Warm Ochre / Earth Gold (#C39653) - Aksen emas resmi, tombol primer, lencana brand.
  static const Color brandOchre = Color(0xFFC39653);

  /// Warm Ochre Light (#DCAB55) - Hover / highlight emas cerah.
  static const Color brandOchreLight = Color(0xFFDCAB55);

  /// Petrol / Oceanic Blue (#32748F) - Border halus, aksen sekunder, telemetry chips.
  static const Color petrolBlue = Color(0xFF32748F);

  /// Telemetry Cyan (#7EC7E8) - Angka koordinat GPS agar kontras tinggi & terbaca jelas.
  static const Color telemetryCyan = Color(0xFF7EC7E8);

  // --- Latar Belakang & Chrome HUD ---
  /// Latar belakang gelap semi-transparan untuk kontrol mengambang (pill, tombol bulat).
  static final Color hudBackground = const Color(0xFF08111D).withValues(alpha: 0.78);

  /// Warna batas halus pada kontrol mengambang untuk kontras terhadap preview terang.
  static final Color hudBorder = const Color(0xFF32748F).withValues(alpha: 0.45);

  /// Latar belakang canvas kamera murni gelap.
  static const Color canvasBlack = Color(0xFF08111D);

  // --- Tombol Rana (Shutter) ---
  /// Cincin luar tombol rana saat kondisi normal (putih bersih dengan aksen emas).
  static const Color shutterRing = Colors.white;

  /// Aksen cincin luar sekunder tombol rana.
  static const Color shutterRingAccent = Color(0xFFC39653);

  /// Warna inti dalam tombol rana saat kondisi normal.
  static const Color shutterInner = Colors.white;

  /// Warna aksen saat tombol rana ditekan/aktif.
  static const Color shutterPressed = Color(0xFFDCAB55);

  // --- Status Akurasi GPS ---
  /// Akurasi sangat baik (< 5 meter) - Hijau terang.
  static const Color gpsExcellent = Color(0xFF00E676);

  /// Akurasi baik (5 - 15 meter) - Biru muda.
  static const Color gpsGood = Color(0xFF29B6F6);

  /// Akurasi cukup (15 - 50 meter) - Kuning/Amber.
  static const Color gpsFair = Color(0xFFFFCA28);

  /// Akurasi kurang (> 50 meter) - Merah.
  static const Color gpsPoor = Color(0xFFFF5252);

  /// Sedang mencari sinyal satelit / belum terkunci - Abu-abu netral.
  static const Color gpsSearching = Color(0xFFB0BEC5);

  // --- Tipografi & Teks HUD ---
  /// Teks berpenekanan tinggi (judul, angka koordinat).
  static const Color textHighEmphasis = Colors.white;

  /// Teks berpenekanan sedang (alamat, timestamp).
  static final Color textMediumEmphasis = Colors.white.withValues(alpha: 0.85);

  /// Teks berpenekanan rendah (label sekunder, watermark attribution).
  static final Color textLowEmphasis = Colors.white.withValues(alpha: 0.60);
}

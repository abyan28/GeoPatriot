enum AccuracyCategory {
  excellent,
  good,
  fair,
  poor,
  unknown;

  /// Tentukan kategori akurasi (sangat baik/baik/cukup/kurang) dari nilai
  /// akurasi GPS dalam meter, sesuai ambang batas yang ditentukan PRD.
  static AccuracyCategory fromMeters(double? accuracy) {
    if (accuracy == null) return AccuracyCategory.unknown;
    if (accuracy < 5) return AccuracyCategory.excellent;
    if (accuracy < 15) return AccuracyCategory.good;
    if (accuracy < 50) return AccuracyCategory.fair;
    return AccuracyCategory.poor;
  }

  /// Teks kategori akurasi dalam Bahasa Indonesia untuk ditampilkan ke pengguna.
  String get label {
    switch (this) {
      case AccuracyCategory.excellent:
        return 'Sangat baik';
      case AccuracyCategory.good:
        return 'Baik';
      case AccuracyCategory.fair:
        return 'Cukup';
      case AccuracyCategory.poor:
        return 'Kurang';
      case AccuracyCategory.unknown:
        return 'Tidak diketahui';
    }
  }
}

/// Lokasi yang dibekukan pada satu momen. Tidak boleh dibaca ulang dari GPS
/// setelah dibuat. Nilai di sini adalah apa yang device laporkan saat itu,
/// bukan estimasi yang "diperhalus" belakangan.
class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.capturedAt,
    this.altitude,
    this.isStale = false,
  });

  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final DateTime capturedAt;

  /// true jika snapshot ini diambil dari posisi terakhir yang diketahui
  /// (bukan fix baru), misalnya karena permintaan lokasi baru timeout.
  final bool isStale;

  AccuracyCategory get accuracyCategory => AccuracyCategory.fromMeters(accuracy);

  /// true jika ini BUKAN lokasi sungguhan: pengganti 0,0 yang dibuat
  /// `LocationService.freezeSnapshot` saat GPS tidak memberi fix sama sekali.
  /// Koordinat ini tidak boleh ditulis ke EXIF/riwayat. (Koordinat 0,0 yang
  /// sengaja diisi manual tidak termasuk: itu tidak ditandai [isStale].)
  bool get isPlaceholder => isStale && latitude == 0.0 && longitude == 0.0 && accuracy == null;
}

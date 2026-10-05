/// Satu baris metadata riwayat foto: cukup untuk menampilkan gallery dan
/// detail tanpa perlu decode ulang file gambar atau memanggil geocoding lagi.
class HistoryEntry {
  const HistoryEntry({
    required this.baseName,
    required this.originalPath,
    required this.processedPath,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.addressText,
  });

  /// Nama dasar file, dipakai untuk memasangkan dan menghapus file original+processed.
  final String baseName;
  final String originalPath;
  final String processedPath;
  final DateTime timestamp;

  /// Null jika foto dibuat tanpa fix GPS (lihat `LocationSnapshot.isPlaceholder`).
  final double? latitude;
  final double? longitude;

  /// Alamat terformat (jika tersedia saat capture), disimpan sebagai teks
  /// jadi supaya history tidak perlu memanggil geocoding ulang.
  final String? addressText;

  Map<String, dynamic> toJson() => {
        'baseName': baseName,
        'originalPath': originalPath,
        'processedPath': processedPath,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
        'addressText': addressText,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        baseName: json['baseName'] as String,
        originalPath: json['originalPath'] as String,
        processedPath: json['processedPath'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        addressText: json['addressText'] as String?,
      );
}

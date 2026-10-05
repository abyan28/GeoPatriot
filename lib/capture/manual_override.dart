import '../location/models/location_snapshot.dart';

/// Pasangan koordinat hasil parsing input teks.
typedef CoordinatePair = ({double latitude, double longitude});

final _coordinatePairPattern = RegExp(r'^\s*(-?\d+(?:\.\d+)?)[,\s]+(-?\d+(?:\.\d+)?)\s*$');

/// Parse satu string "lat,lon" (pemisah koma, koma+spasi, atau spasi) —
/// mis. hasil salin dari Google Maps "-9.620308,124.879609". Mengembalikan
/// null bila format tidak dikenali atau di luar rentang (lat ±90, lon ±180).
CoordinatePair? parseCoordinatePair(String input) {
  final match = _coordinatePairPattern.firstMatch(input);
  if (match == null) return null;

  final latitude = double.tryParse(match.group(1)!);
  final longitude = double.tryParse(match.group(2)!);
  if (latitude == null || longitude == null) return null;
  if (latitude < -90 || latitude > 90) return null;
  if (longitude < -180 || longitude > 180) return null;

  return (latitude: latitude, longitude: longitude);
}

/// Koordinat dan/atau waktu yang diisi manual oleh pengguna, menggantikan
/// GPS dan jam perangkat untuk foto berikutnya. Hanya hidup di memori
/// (tidak dipersist) sehingga kembali ke GPS/jam asli saat app ditutup.
class ManualOverride {
  const ManualOverride({this.latitude, this.longitude, this.timestamp});

  final double? latitude;
  final double? longitude;
  final DateTime? timestamp;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// true jika tidak ada satu pun nilai yang di-override.
  bool get isEmpty => !hasCoordinates && timestamp == null;

  /// Bangun [LocationSnapshot] dari koordinat manual. Akurasi/altitude
  /// kosong karena tidak berasal dari sensor, jadi barisnya otomatis tidak
  /// tampil di watermark.
  LocationSnapshot toLocationSnapshot({required DateTime capturedAt}) {
    return LocationSnapshot(
      latitude: latitude!,
      longitude: longitude!,
      accuracy: null,
      capturedAt: capturedAt,
    );
  }
}

import 'dart:io';

import 'package:intl/intl.dart';
import 'package:native_exif/native_exif.dart';

import '../location/models/location_snapshot.dart';

/// Menulis metadata GPS dan timestamp ke file JPEG lewat `native_exif`.
/// EXIF bersifat tambahan (PRD §13): kegagalan menulis EXIF tidak boleh
/// menggagalkan penyimpanan foto, karena itu semua pemanggil method ini
/// wajib membungkusnya dengan try/catch.
///
/// Catatan keterbatasan platform: `native_exif` membungkus
/// `androidx.exifinterface` di Android dan `CGImageProperties` di iOS
/// dengan cara yang tidak sepenuhnya sama. Altitude dikirim sebagai
/// rational string di Android dan sebagai angka di iOS supaya masing-masing
/// native layer menerimanya dengan benar.
class ExifWriter {
  /// Tulis GPS latitude/longitude/altitude dan DateTimeOriginal ke [file].
  Future<void> write(File file, {required LocationSnapshot location, required DateTime timestamp}) async {
    final exif = await Exif.fromPath(file.path);
    try {
      final values = <String, Object>{
        'DateTimeOriginal': DateFormat('yyyy:MM:dd HH:mm:ss').format(timestamp),
      };

      // Lokasi pengganti (GPS tidak dapat fix) bukan data sungguhan: jangan
      // tulis koordinat 0,0 ke file.
      if (!location.isPlaceholder) {
        values['GPSLatitude'] = location.latitude;
        values['GPSLongitude'] = location.longitude;
        values['GPSLatitudeRef'] = location.latitude >= 0 ? 'N' : 'S';
        values['GPSLongitudeRef'] = location.longitude >= 0 ? 'E' : 'W';
      }

      final altitude = location.altitude;
      if (!location.isPlaceholder && altitude != null) {
        values['GPSAltitudeRef'] = altitude >= 0 ? '0' : '1';
        values['GPSAltitude'] = Platform.isIOS ? altitude.abs() : '${altitude.abs().round()}/1';
      }

      await exif.writeAttributes(values);
    } finally {
      await exif.close();
    }
  }
}

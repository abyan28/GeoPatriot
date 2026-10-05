import 'dart:io';

import 'package:native_exif/native_exif.dart';

import '../location/models/location_snapshot.dart';
import '../storage/photo_storage_service.dart';
import 'models/capture_session.dart';
import 'watermark_publisher.dart';

/// Metadata yang berhasil dibaca dari EXIF foto; field null berarti tidak
/// ada di file (foto kiriman WhatsApp dsb. biasanya sudah ter-strip).
typedef ExifMetadata = ({double? latitude, double? longitude, DateTime? capturedAt});

/// Menambahkan watermark ke foto yang sudah ada di galeri HP, memakai
/// pipeline yang sama dengan capture kamera ([WatermarkPublisher]).
class PhotoImportService {
  PhotoImportService({required this.storageService, required this.publisher});

  final PhotoStorageService storageService;
  final WatermarkPublisher publisher;

  /// Baca waktu pemotretan dan koordinat GPS dari EXIF [path]. Kegagalan
  /// membaca tidak pernah fatal: dikembalikan sebagai semua null.
  Future<ExifMetadata> readExif(String path) async {
    Exif? exif;
    try {
      exif = await Exif.fromPath(path);
      final latLong = await exif.getLatLong();
      final capturedAt = await exif.getOriginalDate();
      return (latitude: latLong?.latitude, longitude: latLong?.longitude, capturedAt: capturedAt);
    } catch (_) {
      return (latitude: null, longitude: null, capturedAt: null);
    } finally {
      await exif?.close();
    }
  }

  /// Beri watermark pada foto di [sourcePath] dengan [location] dan
  /// [timestamp] yang sudah ditentukan pemanggil. Foto sumber tidak diubah;
  /// original TIDAK diduplikasi ke album aplikasi karena sudah ada di galeri.
  Future<CaptureSession> importPhoto({
    required String sourcePath,
    required LocationSnapshot location,
    required DateTime timestamp,
  }) async {
    final baseName = await storageService.reserveBaseName(timestamp);
    final stagingOriginal = await storageService.saveOriginal(sourcePath, baseName: baseName);
    try {
      return await publisher.publish(
        stagingOriginal: stagingOriginal,
        baseName: baseName,
        location: location,
        timestamp: timestamp,
        publishOriginal: false,
      );
    } catch (_) {
      await storageService.deleteQuietly(stagingOriginal.path);
      rethrow;
    }
  }

  /// Tanggal modifikasi file, dipakai sebagai waktu cadangan bila EXIF tidak
  /// punya waktu pemotretan.
  Future<DateTime> fileModifiedAt(String path) => File(path).lastModified();
}

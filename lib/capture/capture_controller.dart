// ignore_for_file: prefer_initializing_formals
// Nama parameter publik sengaja berbeda dari nama field private, sehingga
// initializing formal (this._field) tidak dapat dipakai lintas file.

import 'package:flutter/foundation.dart';

import '../camera/camera_controller_service.dart';
import '../geocoding/geocoding_provider.dart';
import '../history/photo_history_service.dart';
import '../location/location_service.dart';
import '../map/map_thumbnail_provider.dart';
import '../storage/photo_storage_service.dart';
import '../watermark/models/watermark_configuration.dart';
import '../watermark/watermark_renderer.dart';
import 'exif_writer.dart';
import 'manual_override.dart';
import 'models/capture_session.dart';
import 'watermark_publisher.dart';

enum CaptureStatus { idle, capturing, success, error }

/// Orchestrate satu capture penuh: bekukan lokasi+waktu, ambil foto,
/// reverse geocoding, map thumbnail, render watermark, simpan
/// original+processed, tulis EXIF, catat ke history. Setiap langkah online
/// (geocoding/map/EXIF) bersifat best-effort, kegagalannya tidak pernah
/// menggagalkan capture, sesuai prinsip offline-first di rules-free-first.md §16.
class CaptureController extends ChangeNotifier {
  CaptureController({
    required LocationService locationService,
    required CameraControllerService cameraService,
    required PhotoStorageService storageService,
    required GeocodingProvider geocodingProvider,
    required MapThumbnailProvider mapThumbnailProvider,
    required PhotoHistoryService historyService,
    required WatermarkConfiguration Function() watermarkConfigProvider,
    required bool Function() saveOriginalProvider,
    ManualOverride? Function()? manualOverrideProvider,
    WatermarkRenderer? watermarkRenderer,
    ExifWriter? exifWriter,
  })  : _locationService = locationService,
        _cameraService = cameraService,
        _storageService = storageService,
        _saveOriginalProvider = saveOriginalProvider,
        _manualOverrideProvider = manualOverrideProvider,
        _publisher = WatermarkPublisher(
          storageService: storageService,
          geocodingProvider: geocodingProvider,
          mapThumbnailProvider: mapThumbnailProvider,
          historyService: historyService,
          watermarkConfigProvider: watermarkConfigProvider,
          watermarkRenderer: watermarkRenderer,
          exifWriter: exifWriter,
        );

  final LocationService _locationService;
  final CameraControllerService _cameraService;
  final PhotoStorageService _storageService;
  final WatermarkPublisher _publisher;
  final bool Function() _saveOriginalProvider;

  /// Koordinat/waktu manual yang aktif saat ini (null = pakai GPS dan jam
  /// perangkat).
  final ManualOverride? Function()? _manualOverrideProvider;

  CaptureStatus status = CaptureStatus.idle;
  CaptureSession? lastSession;
  String? errorMessage;

  /// Jalankan satu siklus capture penuh. Kegagalan lokasi/kamera/storage
  /// dianggap kegagalan capture; kegagalan geocoding/map/EXIF hanya
  /// menghasilkan data yang lebih sedikit, bukan capture gagal.
  Future<void> capture() async {
    status = CaptureStatus.capturing;
    errorMessage = null;
    notifyListeners();

    try {
      final manual = _manualOverrideProvider?.call();
      final timestamp = manual?.timestamp ?? DateTime.now();
      final location = manual != null && manual.hasCoordinates
          ? manual.toLocationSnapshot(capturedAt: timestamp)
          : await _locationService.freezeSnapshot();
      final photo = await _cameraService.takePicture();
      final baseName = await _storageService.reserveBaseName(timestamp);
      final stagingOriginal = await _storageService.saveOriginal(photo.path, baseName: baseName);
      await _storageService.deleteQuietly(photo.path);

      lastSession = await _publisher.publish(
        stagingOriginal: stagingOriginal,
        baseName: baseName,
        location: location,
        timestamp: timestamp,
        publishOriginal: _saveOriginalProvider(),
      );
      status = CaptureStatus.success;
    } on LocationAccessException catch (e) {
      errorMessage = e.userMessage;
      status = CaptureStatus.error;
    } catch (e, stackTrace) {
      debugPrint('Gagal mengambil foto: $e\n$stackTrace');
      await _storageService.cleanTemporaryFiles();
      errorMessage = 'Gagal mengambil foto. Coba lagi.';
      status = CaptureStatus.error;
    }

    notifyListeners();
  }
}

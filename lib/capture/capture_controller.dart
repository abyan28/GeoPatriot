// ignore_for_file: prefer_initializing_formals
// Nama parameter publik sengaja berbeda dari nama field private, sehingga
// initializing formal (this._field) tidak dapat dipakai lintas file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/date_symbol_data_local.dart';

import '../camera/camera_controller_service.dart';
import '../core/network/safe_fetch.dart';
import '../geocoding/geocoding_provider.dart';
import '../geocoding/models/address_snapshot.dart';
import '../history/models/history_entry.dart';
import '../history/photo_history_service.dart';
import '../location/location_service.dart';
import '../location/models/location_snapshot.dart';
import '../map/map_thumbnail_provider.dart';
import '../storage/photo_storage_service.dart';
import '../watermark/models/watermark_configuration.dart';
import '../watermark/models/watermark_data.dart';
import '../watermark/watermark_renderer.dart';
import 'exif_writer.dart';
import 'manual_override.dart';
import 'models/capture_session.dart';

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
        _geocodingProvider = geocodingProvider,
        _mapThumbnailProvider = mapThumbnailProvider,
        _historyService = historyService,
        _watermarkConfigProvider = watermarkConfigProvider,
        _saveOriginalProvider = saveOriginalProvider,
        _manualOverrideProvider = manualOverrideProvider,
        _watermarkRenderer = watermarkRenderer ?? WatermarkRenderer(),
        _exifWriter = exifWriter ?? ExifWriter();

  final LocationService _locationService;
  final CameraControllerService _cameraService;
  final PhotoStorageService _storageService;
  final GeocodingProvider _geocodingProvider;
  final MapThumbnailProvider _mapThumbnailProvider;
  final PhotoHistoryService _historyService;
  final WatermarkConfiguration Function() _watermarkConfigProvider;
  final bool Function() _saveOriginalProvider;

  /// Koordinat/waktu manual yang aktif saat ini (null = pakai GPS dan jam
  /// perangkat).
  final ManualOverride? Function()? _manualOverrideProvider;
  final WatermarkRenderer _watermarkRenderer;
  final ExifWriter _exifWriter;

  CaptureStatus status = CaptureStatus.idle;
  CaptureSession? lastSession;
  String? errorMessage;

  /// Cache bytes ikon aplikasi (untuk header watermark) supaya cuma dimuat
  /// sekali dari asset bundle, bukan setiap capture.
  Uint8List? _appIconBytes;
  bool _appIconLoadAttempted = false;

  /// Muat bytes ikon aplikasi dari asset bundle sekali saja. Kegagalan
  /// (mis. asset tidak ada) diabaikan — header watermark tetap tampil
  /// tanpa ikon, teks saja, bukan menggagalkan capture.
  Future<Uint8List?> _loadAppIconBytes() async {
    if (_appIconLoadAttempted) return _appIconBytes;
    _appIconLoadAttempted = true;
    try {
      final data = await rootBundle.load('assets/icon/app_icon.png');
      _appIconBytes = data.buffer.asUint8List();
    } catch (_) {
      _appIconBytes = null;
    }
    return _appIconBytes;
  }

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

      final address = await fetchSafely(
        () => _geocodingProvider.reverseGeocode(latitude: location.latitude, longitude: location.longitude),
      );
      final config = _watermarkConfigProvider();
      final map = config.showMapThumbnail
          ? await fetchSafely(
              () => _mapThumbnailProvider.fetchThumbnail(
                latitude: location.latitude,
                longitude: location.longitude,
                zoom: config.mapZoom,
              ),
            )
          : null;

      final watermarkData = WatermarkData(
        location: location,
        timestamp: timestamp,
        timeZoneName: timestamp.timeZoneName,
        address: address,
        map: map,
      );
      final appIconBytes = await _loadAppIconBytes();
      final sourceBytes = await stagingOriginal.readAsBytes();
      final processedBytes = await compute(
        _renderWatermarkInIsolate,
        _WatermarkRenderPayload(
          sourceImageBytes: sourceBytes,
          data: watermarkData,
          config: config,
          appIconBytes: appIconBytes,
          renderer: _watermarkRenderer,
        ),
      );
      final stagingProcessed = await _storageService.saveProcessed(processedBytes, baseName: baseName);

      await _writeExifSafely(stagingProcessed, location, timestamp);

      final processedFile = await _storageService.publishProcessedToGallery(stagingProcessed, baseName: baseName);

      final File originalFile;
      if (_saveOriginalProvider()) {
        originalFile = await _storageService.publishOriginalToGallery(stagingOriginal, baseName: baseName);
      } else {
        await stagingOriginal.delete();
        originalFile = stagingOriginal;
      }

      final session = CaptureSession(
        originalImageFile: originalFile,
        processedImageFile: processedFile,
        location: location,
        timestamp: timestamp,
        timeZoneName: timestamp.timeZoneName,
        address: address,
        map: map,
      );

      await _historyService.add(HistoryEntry(
        baseName: baseName,
        originalPath: originalFile.path,
        processedPath: processedFile.path,
        timestamp: timestamp,
        latitude: location.latitude,
        longitude: location.longitude,
        addressText: address == null ? null : _formattedAddress(address),
      ));

      lastSession = session;
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

  /// Tulis EXIF ke file processed; kegagalan apa pun (mis. keterbatasan
  /// platform) diabaikan karena EXIF hanya informasi tambahan, watermark
  /// tetap menjadi sumber informasi visual utama (PRD §13).
  Future<void> _writeExifSafely(File processedFile, LocationSnapshot location, DateTime timestamp) async {
    try {
      await _exifWriter.write(processedFile, location: location, timestamp: timestamp);
    } catch (_) {
      // Diamkan: lihat dokumentasi method di atas.
    }
  }

  String _formattedAddress(AddressSnapshot address) {
    return [address.village, address.regency, address.province]
        .where((component) => component != null && component.isNotEmpty)
        .join(', ');
  }
}

/// Payload data untuk eksekusi render watermark di background isolate.
class _WatermarkRenderPayload {
  const _WatermarkRenderPayload({
    required this.sourceImageBytes,
    required this.data,
    required this.config,
    this.appIconBytes,
    this.renderer,
  });

  final Uint8List sourceImageBytes;
  final WatermarkData data;
  final WatermarkConfiguration config;
  final Uint8List? appIconBytes;
  final WatermarkRenderer? renderer;
}

/// Fungsi top-level untuk rendering watermark di isolate terpisah via [compute],
/// mencegah freeze/jank pada UI thread saat mengolah foto resolusi tinggi.
Future<Uint8List> _renderWatermarkInIsolate(_WatermarkRenderPayload payload) async {
  await initializeDateFormatting('id_ID');
  final renderer = payload.renderer ?? WatermarkRenderer();
  return renderer.render(
    sourceImageBytes: payload.sourceImageBytes,
    data: payload.data,
    config: payload.config,
    appIconBytes: payload.appIconBytes,
  );
}

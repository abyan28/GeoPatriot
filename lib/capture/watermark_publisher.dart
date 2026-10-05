// ignore_for_file: prefer_initializing_formals
// Nama parameter publik sengaja berbeda dari nama field private, sehingga
// initializing formal (this._field) tidak dapat dipakai lintas file.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/date_symbol_data_local.dart';

import '../core/network/safe_fetch.dart';
import '../geocoding/geocoding_provider.dart';
import '../geocoding/models/address_snapshot.dart';
import '../history/models/history_entry.dart';
import '../history/photo_history_service.dart';
import '../location/models/location_snapshot.dart';
import '../map/models/map_snapshot.dart';
import '../map/map_thumbnail_provider.dart';
import '../storage/photo_storage_service.dart';
import '../watermark/models/watermark_configuration.dart';
import '../watermark/models/watermark_data.dart';
import '../watermark/watermark_renderer.dart';
import 'exif_writer.dart';
import 'models/capture_session.dart';

/// Bagian pipeline yang dipakai bersama oleh capture kamera dan impor foto
/// galeri: dari foto original yang sudah ada di staging sampai foto ber-
/// watermark terpublikasi ke galeri dan tercatat di history. Geocoding/map/
/// EXIF bersifat best-effort (offline-first), kegagalannya tidak menggagalkan
/// proses.
class WatermarkPublisher {
  WatermarkPublisher({
    required PhotoStorageService storageService,
    required GeocodingProvider geocodingProvider,
    required MapThumbnailProvider mapThumbnailProvider,
    required PhotoHistoryService historyService,
    required WatermarkConfiguration Function() watermarkConfigProvider,
    WatermarkRenderer? watermarkRenderer,
    ExifWriter? exifWriter,
  })  : _storageService = storageService,
        _geocodingProvider = geocodingProvider,
        _mapThumbnailProvider = mapThumbnailProvider,
        _historyService = historyService,
        _watermarkConfigProvider = watermarkConfigProvider,
        _watermarkRenderer = watermarkRenderer ?? WatermarkRenderer(),
        _exifWriter = exifWriter ?? ExifWriter();

  final PhotoStorageService _storageService;
  final GeocodingProvider _geocodingProvider;
  final MapThumbnailProvider _mapThumbnailProvider;
  final PhotoHistoryService _historyService;
  final WatermarkConfiguration Function() _watermarkConfigProvider;
  final WatermarkRenderer _watermarkRenderer;
  final ExifWriter _exifWriter;

  /// Batas waktu geocoding/peta sebelum dianggap tidak tersedia (offline).
  static const _onlineTimeout = Duration(seconds: 5);

  /// Cache bytes ikon aplikasi (untuk header watermark) supaya cuma dimuat
  /// sekali dari asset bundle, bukan setiap foto.
  Uint8List? _appIconBytes;
  bool _appIconLoadAttempted = false;

  /// Muat bytes ikon aplikasi dari asset bundle sekali saja. Kegagalan
  /// (mis. asset tidak ada) diabaikan — header watermark tetap tampil
  /// tanpa ikon, teks saja.
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

  /// Proses [stagingOriginal] (file original di staging): geocoding, peta,
  /// render watermark, tulis EXIF, publikasi ke galeri, catat history.
  /// Original dipublikasikan ke galeri hanya jika [publishOriginal] true,
  /// selain itu file stagingnya dihapus.
  Future<CaptureSession> publish({
    required File stagingOriginal,
    required String baseName,
    required LocationSnapshot location,
    required DateTime timestamp,
    required bool publishOriginal,
  }) async {
    final config = _watermarkConfigProvider();
    // Geocoding dan peta dijalankan bersamaan dengan batas waktu pendek, jadi
    // di sinyal buruk/offline capture menunggu paling lama ±[_onlineTimeout],
    // bukan dua kali berturut-turut.
    final addressFuture = fetchSafely(
      () => _geocodingProvider.reverseGeocode(latitude: location.latitude, longitude: location.longitude),
      timeout: _onlineTimeout,
    );
    final mapFuture = config.showMapThumbnail
        ? fetchSafely(
            () => _mapThumbnailProvider.fetchThumbnail(
              latitude: location.latitude,
              longitude: location.longitude,
              zoom: config.mapZoom,
            ),
            timeout: _onlineTimeout,
          )
        : Future<MapSnapshot?>.value(null);
    final address = await addressFuture;
    final map = await mapFuture;

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

    final processedFile = await _publishProcessedWithRetry(stagingProcessed, baseName);

    final File originalFile;
    if (publishOriginal) {
      originalFile = await _storageService.publishOriginalToGallery(stagingOriginal, baseName: baseName);
    } else {
      await stagingOriginal.delete();
      originalFile = stagingOriginal;
    }

    await _historyService.add(HistoryEntry(
      baseName: baseName,
      originalPath: originalFile.path,
      processedPath: processedFile.path,
      timestamp: timestamp,
      latitude: location.isPlaceholder ? null : location.latitude,
      longitude: location.isPlaceholder ? null : location.longitude,
      addressText: address == null ? null : _formattedAddress(address),
    ));

    return CaptureSession(
      originalImageFile: originalFile,
      processedImageFile: processedFile,
      location: location,
      timestamp: timestamp,
      timeZoneName: timestamp.timeZoneName,
      address: address,
      map: map,
    );
  }

  /// Publikasikan foto processed ke galeri; coba sekali lagi bila gagal
  /// (mis. izin galeri baru saja diberikan), lalu lempar
  /// [GalleryPublishException] agar pemanggil bisa memberi pesan yang jelas.
  Future<File> _publishProcessedWithRetry(File stagingProcessed, String baseName) async {
    try {
      return await _storageService.publishProcessedToGallery(stagingProcessed, baseName: baseName);
    } catch (_) {
      try {
        return await _storageService.publishProcessedToGallery(stagingProcessed, baseName: baseName);
      } catch (e) {
        throw GalleryPublishException(e);
      }
    }
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

/// Foto sudah dirender tetapi gagal disimpan ke galeri (izin ditolak,
/// penyimpanan penuh, dll).
class GalleryPublishException implements Exception {
  GalleryPublishException(this.cause);

  final Object cause;

  @override
  String toString() => 'GalleryPublishException: $cause';
}

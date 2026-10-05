import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../camera/widgets/manual_override_sheet.dart';
import '../capture/manual_override.dart';
import '../capture/photo_import_service.dart';
import '../capture/watermark_publisher.dart';
import '../geocoding/geocoding_provider.dart';
import '../location/models/location_snapshot.dart';
import '../map/map_thumbnail_provider.dart';
import '../settings/settings_controller.dart';
import '../storage/photo_storage_service.dart';
import 'photo_history_service.dart';

/// Alur "tambah watermark dari foto galeri": pilih foto lewat photo picker,
/// isi/koreksi koordinat dan waktu di sheet, lalu beri watermark satu per
/// satu. Koordinat dan waktu diambil dari EXIF masing-masing foto; nilai
/// yang diisi di sheet menggantikannya untuk SEMUA foto yang dipilih. Foto
/// tanpa koordinat (EXIF kosong dan tidak diisi manual) dilewati.
///
/// Mengembalikan jumlah foto yang berhasil diproses (0 jika dibatalkan atau
/// semuanya gagal), supaya pemanggil bisa memuat ulang daftar riwayat.
Future<int> importFromGallery(
  BuildContext context, {
  required SettingsController settings,
  required PhotoHistoryService historyService,
  required PhotoStorageService storageService,
  required GeocodingProvider geocodingProvider,
  required MapThumbnailProvider mapThumbnailProvider,
}) async {
  final picked = await ImagePicker().pickMultiImage();
  if (picked.isEmpty || !context.mounted) return 0;

  final importer = PhotoImportService(
    storageService: storageService,
    publisher: WatermarkPublisher(
      storageService: storageService,
      geocodingProvider: geocodingProvider,
      mapThumbnailProvider: mapThumbnailProvider,
      historyService: historyService,
      watermarkConfigProvider: () => settings.settings.watermark,
    ),
  );

  final firstExif = await importer.readExif(picked.first.path);
  if (!context.mounted) return 0;
  final hasFirstCoords = firstExif.latitude != null && firstExif.longitude != null;
  final manual = await showModalBottomSheet<ManualOverride>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ManualOverrideSheet(
      // Prefill dari EXIF HANYA untuk satu foto: untuk banyak foto, nilai
      // yang terisi akan dianggap override dan menimpa EXIF foto lainnya.
      initial: picked.length == 1
          ? ManualOverride(
              latitude: hasFirstCoords ? firstExif.latitude : null,
              longitude: hasFirstCoords ? firstExif.longitude : null,
              timestamp: firstExif.capturedAt,
            )
          : null,
      title: picked.length == 1 ? 'Tambah watermark' : 'Tambah watermark (${picked.length} foto)',
      description: picked.length == 1
          ? 'Koordinat dan waktu terisi dari EXIF foto bila ada. Ubah atau lengkapi bila perlu; '
              'foto tanpa koordinat dilewati.'
          : 'Koordinat dan waktu yang diisi berlaku untuk SEMUA foto yang dipilih. '
              'Kosongkan untuk memakai data EXIF masing-masing foto; foto tanpa koordinat dilewati.',
      resetLabel: 'Pakai data EXIF',
    ),
  );
  if (manual == null || !context.mounted) return 0;

  final progress = ValueNotifier<int>(0);
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, done, _) => Row(
            children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
              const SizedBox(width: 16),
              Expanded(child: Text('Memproses ${done + 1 > picked.length ? picked.length : done + 1} dari ${picked.length}...')),
            ],
          ),
        ),
      ),
    ),
  );

  var succeeded = 0;
  var skipped = 0;
  var failed = 0;
  for (final file in picked) {
    try {
      final exif = await importer.readExif(file.path);
      final latitude = manual.latitude ?? exif.latitude;
      final longitude = manual.longitude ?? exif.longitude;
      if (latitude == null || longitude == null) {
        skipped++;
      } else {
        final timestamp = manual.timestamp ?? exif.capturedAt ?? await importer.fileModifiedAt(file.path);
        await importer.importPhoto(
          sourcePath: file.path,
          location: LocationSnapshot(
            latitude: latitude,
            longitude: longitude,
            accuracy: null,
            capturedAt: timestamp,
          ),
          timestamp: timestamp,
        );
        succeeded++;
      }
    } catch (e) {
      debugPrint('Gagal memproses foto galeri: $e');
      failed++;
    } finally {
      await storageService.deletePickerCopy(file.path);
    }
    progress.value++;
  }
  progress.dispose();

  navigator.pop();
  final parts = [
    '$succeeded foto berhasil',
    if (skipped > 0) '$skipped dilewati (tanpa koordinat)',
    if (failed > 0) '$failed gagal',
  ];
  messenger.showSnackBar(SnackBar(content: Text(parts.join(', '))));
  return succeeded;
}

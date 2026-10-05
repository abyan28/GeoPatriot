import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Mempublikasikan foto original (opsional) dan foto processed (watermark)
/// ke Galeri publik Android, di dua album terpisah supaya keduanya mudah
/// dibedakan tapi tetap terjangkau file manager/Galeri mana pun. Keduanya
/// berbagi nama dasar yang sama supaya mudah dipasangkan di history.
class PhotoStorageService {
  /// Folder-folder ini cuma dipakai sebagai STAGING sementara (dibutuhkan
  /// `ExifWriter`/proses copy yang perlu `File` asli di disk) sebelum
  /// dipublikasikan ke galeri — bukan penyimpanan permanen, supaya tidak
  /// ada duplikat foto di storage privat DAN galeri publik sekaligus.
  static const _originalStagingFolderName = 'original';
  static const _processedStagingFolderName = 'processed';

  /// Nama album di Galeri Android tempat foto processed dipublikasikan.
  static const galleryAlbumName = 'GeoPatriot';

  /// Nama album (sub-folder) untuk foto original — dipisah dari processed
  /// supaya tidak tertukar, tapi tetap PUBLIK (bisa diakses Galeri/File
  /// Manager), sesuai permintaan user (sebelumnya original privat).
  static const originalGalleryAlbumName = 'GeoPatriot/Original';

  /// Path standar folder publik "Pictures" Android untuk profil pengguna
  /// utama/default — dipakai untuk memprediksi lokasi akhir foto setelah
  /// dipublikasikan lewat `gal` (package `gal` menyimpan gambar dengan
  /// album ke `Pictures/<album>`, bukan `DCIM/<album>`, terkonfirmasi dari
  /// source code Android plugin ini; album boleh mengandung "/" untuk
  /// sub-folder, diteruskan apa adanya ke MediaStore RELATIVE_PATH).
  /// Android-only, konsisten dengan proyek ini yang belum mendukung
  /// platform lain.
  static const _publicPicturesPath = '/storage/emulated/0/Pictures';

  /// Path folder Pictures publik (dipakai juga oleh `PhotoHistoryService`
  /// untuk menilai apakah penyimpanan publik terbaca).
  static const publicPicturesPath = _publicPicturesPath;

  Future<Directory> _folder(String name) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${documentsDir.path}/GeotagCamera/$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Ambil (dan buat jika belum ada) folder staging sementara untuk foto
  /// original sebelum dipublikasikan ke galeri (atau dihapus jika setting
  /// "Simpan foto original" nonaktif).
  Future<Directory> _originalStagingDirectory() => _folder(_originalStagingFolderName);

  /// Ambil (dan buat jika belum ada) folder staging sementara untuk foto
  /// processed sebelum dipublikasikan ke galeri.
  Future<Directory> _processedStagingDirectory() => _folder(_processedStagingFolderName);

  /// Hapus file di [path] bila ada; kegagalan hapus diabaikan karena ini
  /// hanya pembersihan file sementara.
  Future<void> deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Pola nama folder salinan sementara milik `image_picker`
  /// (`cache/<uuid>/<nama file>`).
  static final _uuidDirPattern = RegExp(r'^[0-9a-fA-F-]{32,36}$');
  static const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.heic'];

  /// Hapus salinan sementara foto yang dipilih lewat `image_picker` setelah
  /// selesai diproses. Hanya menghapus bila [path] berada di direktori cache
  /// aplikasi — jangan pernah menyentuh file asli milik pengguna di galeri.
  Future<void> deletePickerCopy(String path) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      if (!path.startsWith(cacheDir.path)) return;
      await deleteQuietly(path);
      final parent = File(path).parent;
      if (parent.path != cacheDir.path && _uuidDirPattern.hasMatch(parent.uri.pathSegments.where((s) => s.isNotEmpty).last)) {
        try {
          await parent.delete();
        } catch (_) {
          // Folder tidak kosong: biarkan.
        }
      }
    } catch (_) {}
  }

  /// Bersihkan sisa file sementara: folder staging (sisa capture yang gagal
  /// di tengah), file JPEG hasil `takePicture` di direktori cache yang
  /// tidak pernah dihapus oleh versi lama, dan folder salinan `image_picker`.
  /// Dipanggil saat startup.
  Future<void> cleanTemporaryFiles() async {
    try {
      for (final name in [_originalStagingFolderName, _processedStagingFolderName]) {
        final dir = await _folder(name);
        await for (final entity in dir.list()) {
          if (entity is File) await deleteQuietly(entity.path);
        }
      }
      final cacheDir = await getTemporaryDirectory();
      await for (final entity in cacheDir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
          await deleteQuietly(entity.path);
        } else if (entity is Directory) {
          await _deleteIfPickerCopyDir(entity);
        }
      }
    } catch (_) {}
  }

  /// Hapus [dir] bila bentuknya folder salinan `image_picker`: nama berupa
  /// UUID dan isinya hanya file gambar.
  Future<void> _deleteIfPickerCopyDir(Directory dir) async {
    final name = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (!_uuidDirPattern.hasMatch(name)) return;
    try {
      final children = await dir.list().toList();
      final onlyImages = children.every(
        (e) => e is File && _imageExtensions.any(e.path.toLowerCase().endsWith),
      );
      if (onlyImages) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Lokasi akhir (prediksi) foto processed di galeri publik untuk satu
  /// [baseName].
  File _publicProcessedFileFor(String baseName) {
    return File('$_publicPicturesPath/$galleryAlbumName/$baseName.jpg');
  }

  /// Lokasi akhir (prediksi) foto original di galeri publik untuk satu
  /// [baseName].
  File _publicOriginalFileFor(String baseName) {
    return File('$_publicPicturesPath/$originalGalleryAlbumName/$baseName.jpg');
  }

  /// Tentukan nama dasar file yang collision-safe untuk satu capture,
  /// dicek terhadap lokasi publik galeri (original & processed) sekaligus
  /// supaya kedua file pasangan selalu memakai suffix yang sama.
  Future<String> reserveBaseName(DateTime capturedAt) async {
    final base = _fileNameFor(capturedAt);

    var candidate = base;
    var suffix = 1;
    while (await _publicOriginalFileFor(candidate).exists() ||
        await _publicProcessedFileFor(candidate).exists()) {
      candidate = '${base}_$suffix';
      suffix++;
    }
    return candidate;
  }

  /// Salin foto original dari path sementara hasil capture kamera ke file
  /// STAGING (privat), dipakai untuk baca bytes (render watermark) dan
  /// sebagai sumber [publishOriginalToGallery] kalau setting "Simpan foto
  /// original" aktif — kalau tidak, staging ini dihapus begitu saja.
  Future<File> saveOriginal(String sourcePath, {required String baseName}) async {
    final dir = await _originalStagingDirectory();
    return File(sourcePath).copy('${dir.path}/$baseName.jpg');
  }

  /// Salin foto original dari file staging ke Galeri publik Android (album
  /// [originalGalleryAlbumName], sub-folder dari [galleryAlbumName]), lalu
  /// hapus file staging-nya — supaya cuma ada SATU salinan (di galeri),
  /// tidak dobel di storage privat. Publik (bukan privat lagi) sesuai
  /// permintaan user, supaya bisa diakses juga lewat Galeri/File Manager.
  Future<File> publishOriginalToGallery(File stagingFile, {required String baseName}) async {
    await Gal.requestAccess(toAlbum: true);
    await Gal.putImage(stagingFile.path, album: originalGalleryAlbumName);
    if (await stagingFile.exists()) await stagingFile.delete();
    return _publicOriginalFileFor(baseName);
  }

  /// Tulis bytes JPEG hasil watermark ke file STAGING sementara (privat),
  /// dipakai `ExifWriter` untuk menulis tag EXIF sebelum dipublikasikan ke
  /// galeri lewat [publishProcessedToGallery].
  Future<File> saveProcessed(Uint8List jpegBytes, {required String baseName}) async {
    final dir = await _processedStagingDirectory();
    final file = File('${dir.path}/$baseName.jpg');
    return file.writeAsBytes(jpegBytes, flush: true);
  }

  /// Salin foto processed (yang EXIF-nya sudah ditulis) dari file staging
  /// ke Galeri publik Android (album [galleryAlbumName]), lalu hapus file
  /// staging-nya — supaya cuma ada SATU salinan foto processed (di galeri),
  /// tidak dobel di storage privat.
  Future<File> publishProcessedToGallery(File stagingFile, {required String baseName}) async {
    await Gal.requestAccess(toAlbum: true);
    await Gal.putImage(stagingFile.path, album: galleryAlbumName);
    if (await stagingFile.exists()) await stagingFile.delete();
    return _publicProcessedFileFor(baseName);
  }

  /// Hapus sepasang file original + processed (keduanya di galeri publik)
  /// berdasarkan nama dasarnya. Dipakai saat pengguna menghapus satu entri
  /// di history. Menghapus langsung lewat `File.delete()` ke path publik
  /// sah dilakukan tanpa izin tambahan karena aplikasi selalu punya akses
  /// penuh ke media yang dibuatnya sendiri.
  Future<void> deleteByBaseName(String baseName) async {
    final originalFile = _publicOriginalFileFor(baseName);
    final processedFile = _publicProcessedFileFor(baseName);
    if (await originalFile.exists()) await originalFile.delete();
    if (await processedFile.exists()) await processedFile.delete();
  }

  /// Buat nama file dasar dari timestamp capture, format `IMG_yyyyMMdd_HHmmss_SSS`.
  String _fileNameFor(DateTime timestamp) {
    String pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');
    return 'IMG_${timestamp.year}${pad(timestamp.month)}${pad(timestamp.day)}_'
        '${pad(timestamp.hour)}${pad(timestamp.minute)}${pad(timestamp.second)}_'
        '${pad(timestamp.millisecond, 3)}';
  }
}

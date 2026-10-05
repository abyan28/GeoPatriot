import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../storage/photo_storage_service.dart';
import 'models/history_entry.dart';

/// Menyimpan metadata history foto sebagai satu file index JSON lokal.
/// Sengaja tidak memakai database (sqlite/hive) karena datanya sederhana
/// dan volumenya kecil untuk penggunaan pribadi (rules-free-first.md §28:
/// hindari database lokal kompleks sebelum dibutuhkan).
///
/// Semua operasi baca-ubah-tulis (add/remove/pruneMissing) dijalankan
/// berurutan lewat antrean statis (instance service dibuat di beberapa
/// layar), dan file ditulis secara atomik (tulis ke file sementara lalu
/// rename), supaya dua operasi bersamaan atau app yang mati di tengah
/// penulisan tidak merusak/menghapus riwayat.
class PhotoHistoryService {
  /// [documentsDirectory] hanya untuk pengujian (default: direktori dokumen
  /// aplikasi dari `path_provider`).
  PhotoHistoryService({Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory = documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  static Future<void> _queue = Future<void>.value();

  /// Jalankan [action] setelah semua operasi sebelumnya selesai.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Future<File> _indexFile() async {
    final documentsDir = await _documentsDirectory();
    final dir = Directory('${documentsDir.path}/GeotagCamera');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/history_index.json');
  }

  /// Baca semua entri history, terbaru lebih dulu. Mengembalikan list
  /// kosong jika belum pernah ada foto. Jika file index rusak, file itu
  /// disalin ke `.bak` (supaya tidak hilang ditimpa penulisan berikutnya)
  /// dan list kosong dikembalikan.
  Future<List<HistoryEntry>> loadAll() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content) as List<dynamic>;
      final entries = decoded
          .map((item) => HistoryEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return entries;
    } catch (_) {
      try {
        await file.copy('${file.path}.bak');
      } catch (_) {}
      return [];
    }
  }

  /// Buang entri yang foto processed-nya sudah tidak ada di penyimpanan
  /// (mis. dihapus lewat Galeri bawaan HP) dari file index, lalu
  /// kembalikan daftar yang tersisa. Pengecekan memakai path publik yang
  /// sama dengan yang dipakai `PhotoStorageService`, jadi sah tanpa izin
  /// tambahan untuk media milik aplikasi ini. Foto original yang hilang
  /// tidak membuat entri dibuang. Jika folder Pictures publik sendiri tidak
  /// terbaca (mis. path penyimpanan berbeda di Secure Folder/multi-user),
  /// tidak ada yang dibuang karena hilang/tidaknya foto tidak bisa dinilai.
  Future<List<HistoryEntry>> pruneMissing() {
    return _serial(() async {
      final entries = await loadAll();
      if (!await Directory(PhotoStorageService.publicPicturesPath).exists()) {
        return entries;
      }

      final kept = <HistoryEntry>[];
      for (final entry in entries) {
        if (await File(entry.processedPath).exists()) kept.add(entry);
      }
      if (kept.length != entries.length) await _writeAll(kept);
      return kept;
    });
  }

  /// Tambahkan satu entri baru ke index, disimpan paling depan (terbaru).
  Future<void> add(HistoryEntry entry) {
    return _serial(() async {
      final entries = await loadAll();
      entries.insert(0, entry);
      await _writeAll(entries);
    });
  }

  /// Hapus satu entri dari index berdasarkan nama dasar filenya.
  Future<void> remove(String baseName) {
    return _serial(() async {
      final entries = await loadAll();
      entries.removeWhere((entry) => entry.baseName == baseName);
      await _writeAll(entries);
    });
  }

  Future<void> _writeAll(List<HistoryEntry> entries) async {
    final file = await _indexFile();
    final json = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(json, flush: true);
    await temp.rename(file.path);
  }
}

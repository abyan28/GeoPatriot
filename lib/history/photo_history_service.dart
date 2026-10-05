import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models/history_entry.dart';

/// Menyimpan metadata history foto sebagai satu file index JSON lokal.
/// Sengaja tidak memakai database (sqlite/hive) karena datanya sederhana
/// dan volumenya kecil untuk penggunaan pribadi (rules-free-first.md §28:
/// hindari database lokal kompleks sebelum dibutuhkan).
class PhotoHistoryService {
  Future<File> _indexFile() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${documentsDir.path}/GeotagCamera');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/history_index.json');
  }

  /// Baca semua entri history, terbaru lebih dulu. Mengembalikan list
  /// kosong jika belum pernah ada foto atau file index rusak.
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
      return [];
    }
  }

  /// Buang entri yang foto processed-nya sudah tidak ada di penyimpanan
  /// (mis. dihapus lewat Galeri bawaan HP) dari [entries] dan dari file
  /// index. Pengecekan memakai path publik yang sama dengan yang dipakai
  /// `PhotoStorageService`, jadi sah tanpa izin tambahan untuk media milik
  /// aplikasi ini. Foto original yang hilang tidak membuat entri dibuang.
  Future<List<HistoryEntry>> pruneMissing(List<HistoryEntry> entries) async {
    final kept = <HistoryEntry>[];
    for (final entry in entries) {
      if (await File(entry.processedPath).exists()) kept.add(entry);
    }
    if (kept.length != entries.length) await _writeAll(kept);
    return kept;
  }

  /// Tambahkan satu entri baru ke index, disimpan paling depan (terbaru).
  Future<void> add(HistoryEntry entry) async {
    final entries = await loadAll();
    entries.insert(0, entry);
    await _writeAll(entries);
  }

  /// Hapus satu entri dari index berdasarkan nama dasar filenya.
  Future<void> remove(String baseName) async {
    final entries = await loadAll();
    entries.removeWhere((entry) => entry.baseName == baseName);
    await _writeAll(entries);
  }

  Future<void> _writeAll(List<HistoryEntry> entries) async {
    final file = await _indexFile();
    final json = jsonEncode(entries.map((entry) => entry.toJson()).toList());
    await file.writeAsString(json, flush: true);
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geotag_camera/history/models/history_entry.dart';
import 'package:geotag_camera/history/photo_history_service.dart';

HistoryEntry _entry(String baseName, {String? processedPath}) => HistoryEntry(
      baseName: baseName,
      originalPath: '/tmp/$baseName-o.jpg',
      processedPath: processedPath ?? '/tmp/$baseName.jpg',
      timestamp: DateTime(2026, 1, 1, 8, 0, baseName.hashCode.abs() % 60),
      latitude: -6.2,
      longitude: 106.8,
    );

void main() {
  late Directory tempDir;
  late PhotoHistoryService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_test_');
    service = PhotoHistoryService(documentsDirectory: () async => tempDir);
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('banyak add bersamaan semuanya tersimpan (tidak saling menimpa)', () async {
    await Future.wait([for (var i = 0; i < 25; i++) service.add(_entry('IMG_$i'))]);

    final entries = await service.loadAll();
    expect(entries.map((e) => e.baseName).toSet().length, 25);
  });

  test('remove menghapus entri yang tepat', () async {
    await service.add(_entry('A'));
    await service.add(_entry('B'));
    await service.remove('A');

    expect((await service.loadAll()).map((e) => e.baseName), ['B']);
  });

  test('file index rusak dicadangkan ke .bak dan tidak melempar', () async {
    final index = File('${tempDir.path}/GeotagCamera/history_index.json');
    await index.create(recursive: true);
    await index.writeAsString('{bukan json valid');

    expect(await service.loadAll(), isEmpty);
    expect(File('${index.path}.bak').existsSync(), isTrue);
  });

  test('tidak meninggalkan file .tmp setelah menulis', () async {
    await service.add(_entry('A'));

    expect(File('${tempDir.path}/GeotagCamera/history_index.json.tmp').existsSync(), isFalse);
  });

  test('pruneMissing tidak membuang apa pun bila folder Pictures publik tidak terbaca', () async {
    // Di mesin uji, /storage/emulated/0/Pictures tidak ada, jadi foto tidak
    // bisa dinilai hilang atau tidak: semua entri harus dipertahankan.
    await service.add(_entry('A'));
    await service.add(_entry('B'));

    final kept = await service.pruneMissing();

    expect(kept.length, 2);
  });

  test('entri lama tanpa koordinat (null) bisa dibaca', () async {
    await service.add(HistoryEntry(
      baseName: 'NOGPS',
      originalPath: '/x',
      processedPath: '/y',
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    ));

    final entries = await service.loadAll();
    expect(entries.single.latitude, isNull);
    expect(entries.single.longitude, isNull);
  });
}

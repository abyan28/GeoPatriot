import 'package:flutter_test/flutter_test.dart';
import 'package:geotag_camera/survey/models/survey_category.dart';
import 'package:geotag_camera/survey/survey_controller.dart';
import 'package:geotag_camera/survey/survey_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SurveyController> _loaded() async {
  final controller = SurveyController();
  while (!controller.isLoaded) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('default: mode mati, kategori bawaan, belum siap', () async {
    final survey = await _loaded();

    expect(survey.enabled, isFalse);
    expect(survey.categories.map((c) => c.id), ['lahan', 'rumah', 'kk', 'ktp', 'shm', 'dokumen-lain']);
    expect(survey.isReady, isFalse);
    expect(survey.currentShot, isNull);
  });

  test('siap setelah mode aktif, lokasi, dan objek terisi', () async {
    final survey = await _loaded();
    await survey.setEnabled(true);
    await survey.setLocation('SP3 Kapitanmeo');
    await survey.setObject('Budi');

    expect(survey.isReady, isTrue);
    expect(survey.previewFileName, 'budi-lahan-sp3-kapitanmeo.jpg');
    expect(survey.currentShot!.applyWatermark, isTrue);
  });

  test('kategori dokumen tanpa watermark dan kode masuk nama', () async {
    final survey = await _loaded();
    await survey.setEnabled(true);
    await survey.setLocation('SP3');
    await survey.setObject('Budi', code: '12');
    survey.selectCategory('kk');

    expect(survey.currentShot!.desiredBaseName, 'budi-12-kk-sp3');
    expect(survey.currentShot!.applyWatermark, isFalse);
  });

  test('nextObject mengosongkan objek dan kode serta mereset kategori', () async {
    final survey = await _loaded();
    await survey.setEnabled(true);
    await survey.setLocation('SP3');
    await survey.setObject('Budi', code: '12');
    survey.selectCategory('ktp');

    survey.nextObject();

    expect(survey.objectName, isEmpty);
    expect(survey.objectCode, isEmpty);
    expect(survey.selectedCategory!.id, 'lahan');
    expect(survey.isReady, isFalse);
  });

  test('recent objects: terbaru di depan, tanpa duplikat, maksimal 5', () async {
    final survey = await _loaded();
    for (final name in ['A', 'B', 'C', 'D', 'E', 'F', 'c']) {
      await survey.setObject(name);
    }

    expect(survey.recentObjects, ['c', 'F', 'E', 'D', 'B']);
  });

  test('lokasi, kategori, dan recent tersimpan; objek aktif tidak', () async {
    final first = await _loaded();
    await first.setEnabled(true);
    await first.setLocation('SP3');
    await first.setObject('Budi');
    await first.addCategory('Jalan', applyWatermark: false);

    final second = await _loaded();

    expect(second.enabled, isTrue);
    expect(second.locationName, 'SP3');
    expect(second.recentObjects, ['Budi']);
    expect(second.categories.last.label, 'Jalan');
    expect(second.categories.last.applyWatermark, isFalse);
    expect(second.objectName, isEmpty);
  });

  test('addCategory membuat id unik dan menolak label kosong', () async {
    final survey = await _loaded();

    final dup = await survey.addCategory('Lahan');
    final empty = await survey.addCategory('###');

    expect(dup!.id, 'lahan-2');
    expect(empty, isNull);
  });

  test('removeCategory tidak menghapus kategori terakhir', () async {
    final survey = await _loaded();
    for (final c in List<SurveyCategory>.from(survey.categories)) {
      await survey.removeCategory(c.id);
    }

    expect(survey.categories, hasLength(1));
  });

  test('SurveyService: JSON rusak kembali ke default', () async {
    SharedPreferences.setMockInitialValues({'survey_json': '{bukan json'});

    final data = await SurveyService().load();

    expect(data.enabled, isFalse);
    expect(data.categories, SurveyCategory.defaults);
  });
}

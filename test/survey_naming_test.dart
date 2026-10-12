import 'package:flutter_test/flutter_test.dart';
import 'package:geotag_camera/survey/survey_naming.dart';

void main() {
  group('sanitizeNamePart', () {
    test('huruf kecil, spasi jadi tanda hubung', () {
      expect(sanitizeNamePart('Pak I Wayan'), 'pak-i-wayan');
    });

    test('aksen dan simbol dibuang', () {
      expect(sanitizeNamePart('José  Ñandú!!'), 'jose-nandu');
      expect(sanitizeNamePart('  --SP 3/Kapitan_Meo--  '), 'sp-3-kapitan-meo');
    });

    test('batas 40 karakter tanpa tanda hubung di ujung', () {
      final result = sanitizeNamePart('a' * 39 + ' b' * 5);
      expect(result.length, lessThanOrEqualTo(40));
      expect(result.endsWith('-'), isFalse);
    });

    test('hanya simbol menghasilkan string kosong', () {
      expect(sanitizeNamePart('***'), isEmpty);
    });
  });

  group('buildSurveyBaseName', () {
    test('format dasar objek-kategori-lokasi', () {
      expect(
        buildSurveyBaseName(objek: 'Budi', kategori: 'Lahan', lokasi: 'Kapitanmeo'),
        'budi-lahan-kapitanmeo',
      );
    });

    test('kode opsional ditaruh setelah objek', () {
      expect(
        buildSurveyBaseName(objek: 'Budi', kode: '12', kategori: 'KK', lokasi: 'SP3'),
        'budi-12-kk-sp3',
      );
    });

    test('bagian wajib kosong menghasilkan null', () {
      expect(buildSurveyBaseName(objek: '', kategori: 'Lahan', lokasi: 'SP3'), isNull);
      expect(buildSurveyBaseName(objek: 'Budi', kategori: 'Lahan', lokasi: '  '), isNull);
      expect(buildSurveyBaseName(objek: '###', kategori: 'Lahan', lokasi: 'SP3'), isNull);
    });
  });

  group('pickAvailableName', () {
    test('mengembalikan nama polos bila bebas', () async {
      expect(await pickAvailableName('budi-lahan-sp3', (_) async => false), 'budi-lahan-sp3');
    });

    test('menambah -2, -3 saat bentrok', () async {
      final taken = {'budi-lahan-sp3', 'budi-lahan-sp3-2'};
      expect(
        await pickAvailableName('budi-lahan-sp3', (c) async => taken.contains(c)),
        'budi-lahan-sp3-3',
      );
    });
  });
}

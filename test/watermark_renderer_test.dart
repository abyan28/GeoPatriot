import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:geotag_camera/geocoding/models/address_snapshot.dart';
import 'package:geotag_camera/location/models/location_snapshot.dart';
import 'package:geotag_camera/map/models/map_snapshot.dart';
import 'package:geotag_camera/watermark/models/watermark_configuration.dart';
import 'package:geotag_camera/watermark/models/watermark_data.dart';
import 'package:geotag_camera/watermark/watermark_renderer.dart';
import 'package:image/image.dart' as img;

Uint8List _fakeJpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgba8(120, 140, 160, 255));
  return Uint8List.fromList(img.encodeJpg(image));
}

Uint8List _fakeMapPng() {
  final image = img.Image(width: 240, height: 240);
  img.fill(image, color: img.ColorRgba8(200, 220, 200, 255));
  return Uint8List.fromList(img.encodePng(image));
}

LocationSnapshot _sampleLocation() => LocationSnapshot(
      latitude: -6.914744,
      longitude: 107.609810,
      accuracy: 8,
      altitude: 750,
      capturedAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  final renderer = WatermarkRenderer();

  test('render dengan data lengkap (portrait) menghasilkan JPEG valid', () {
    final data = WatermarkData(
      location: _sampleLocation(),
      timestamp: DateTime(2026, 3, 5, 14, 30),
      timeZoneName: 'WIB',
      address: const AddressSnapshot(
        village: 'Cipadung',
        district: 'Cibiru',
        regency: 'Kota Bandung',
        province: 'Jawa Barat',
        country: 'Indonesia',
      ),
      map: MapSnapshot(imageBytes: _fakeMapPng(), attributionText: '© OpenStreetMap contributors'),
    );

    final result = renderer.render(
      sourceImageBytes: _fakeJpeg(1080, 1920),
      data: data,
      config: WatermarkConfiguration.defaultTemplate(),
    );

    final decoded = img.decodeJpg(result);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1080);
    expect(decoded.height, 1920);
  });

  test('render tetap berhasil (landscape) walau address dan map null', () {
    final data = WatermarkData(
      location: _sampleLocation(),
      timestamp: DateTime(2026, 3, 5, 14, 30),
      timeZoneName: 'WIB',
    );

    final result = renderer.render(
      sourceImageBytes: _fakeJpeg(1920, 1080),
      data: data,
      config: WatermarkConfiguration.defaultTemplate(),
    );

    final decoded = img.decodeJpg(result);
    expect(decoded, isNotNull);
    expect(decoded!.width, 1920);
    expect(decoded.height, 1080);
  });

  test('alamat sangat panjang tidak menggagalkan render', () {
    final data = WatermarkData(
      location: _sampleLocation(),
      timestamp: DateTime(2026, 3, 5, 14, 30),
      timeZoneName: 'WIB',
      address: const AddressSnapshot(
        street: 'Jalan Terusan Jenderal Sudirman Nomor Sekian Belas Ratus Dua Puluh Tiga',
        village: 'Kelurahan Dengan Nama Yang Sangat Panjang Sekali Sekali',
        district: 'Kecamatan Panjang',
        regency: 'Kabupaten Dengan Nama Panjang Juga',
        province: 'Provinsi Dengan Nama Yang Tidak Kalah Panjang',
        country: 'Indonesia',
      ),
    );

    expect(
      () => renderer.render(
        sourceImageBytes: _fakeJpeg(1080, 1920),
        data: data,
        config: WatermarkConfiguration.detail(),
      ),
      returnsNormally,
    );
  });

  test('peta berisi bytes bukan gambar tidak menggagalkan render', () {
    final data = WatermarkData(
      location: _sampleLocation(),
      timestamp: DateTime(2026, 3, 5, 14, 30),
      timeZoneName: 'WIB',
      map: MapSnapshot(imageBytes: Uint8List.fromList([1, 2, 3, 4, 5]), attributionText: 'Atribusi peta'),
    );

    final result = renderer.render(
      sourceImageBytes: _fakeJpeg(1080, 1920),
      data: data,
      config: WatermarkConfiguration.defaultTemplate(),
    );

    expect(img.decodeJpg(result), isNotNull);
  });

  test('ukuran panel proporsional terhadap lebar foto di resolusi berbeda', () {
    // Sebelumnya ukuran watermark piksel absolut, jadi di foto 1080 lebar
    // panelnya hanya ~0,67x porsi di foto 720. Sekarang harus sebanding.
    double panelWidthFraction(int width, int height) {
      final data = WatermarkData(
        location: _sampleLocation(),
        timestamp: DateTime(2026, 3, 5, 14, 30),
        timeZoneName: 'WIB',
      );
      final result = renderer.render(
        sourceImageBytes: _fakeJpeg(width, height),
        data: data,
        config: WatermarkConfiguration.defaultTemplate(),
      );
      final decoded = img.decodeJpg(result)!;
      var minX = decoded.width;
      var maxX = -1;
      for (final pixel in decoded) {
        // Latar foto uji terang (~140); panel hitam semi-transparan jauh lebih gelap.
        if (pixel.luminance < 90) {
          if (pixel.x < minX) minX = pixel.x;
          if (pixel.x > maxX) maxX = pixel.x;
        }
      }
      expect(maxX, greaterThan(minX), reason: 'panel tidak terdeteksi');
      return (maxX - minX + 1) / decoded.width;
    }

    final at720 = panelWidthFraction(720, 1280);
    final at1080 = panelWidthFraction(1080, 1920);

    expect(at1080 / at720, inInclusiveRange(0.85, 1.2));
  });

  test('watermarkScaleFor memakai sisi pendek dan dijepit 0,5-4', () {
    expect(watermarkScaleFor(720, 1280), 1.0);
    expect(watermarkScaleFor(1080, 1920), 1.5);
    expect(watermarkScaleFor(1920, 1080), 1.5);
    expect(watermarkScaleFor(100, 100), 0.5);
    expect(watermarkScaleFor(9000, 12000), 4.0);
  });

  test('resolusi kecil tetap dapat dirender tanpa exception', () {
    final data = WatermarkData(
      location: _sampleLocation(),
      timestamp: DateTime(2026, 3, 5, 14, 30),
      timeZoneName: 'WIB',
    );

    expect(
      () => renderer.render(
        sourceImageBytes: _fakeJpeg(320, 240),
        data: data,
        config: WatermarkConfiguration.compact(),
      ),
      returnsNormally,
    );
  });

  test('template compact tanpa thumbnail tidak menyebabkan error geometri', () {
    final data = WatermarkData(
      location: _sampleLocation(),
      timestamp: DateTime(2026, 3, 5, 14, 30),
      timeZoneName: 'WIB',
      map: MapSnapshot(imageBytes: _fakeMapPng(), attributionText: '© OpenStreetMap contributors'),
    );

    final result = renderer.render(
      sourceImageBytes: _fakeJpeg(1080, 1920),
      data: data,
      config: WatermarkConfiguration.compact(),
    );

    expect(img.decodeJpg(result), isNotNull);
  });

  test('resolusi besar (foto kamera nyata) dapat dirender', () {
    final data = WatermarkData(
      location: _sampleLocation(),
      timestamp: DateTime(2026, 3, 5, 14, 30),
      timeZoneName: 'WIB',
    );

    final result = renderer.render(
      sourceImageBytes: _fakeJpeg(4032, 3024),
      data: data,
      config: WatermarkConfiguration.defaultTemplate(),
    );

    final decoded = img.decodeJpg(result);
    expect(decoded!.width, 4032);
    expect(decoded.height, 3024);
  });
}

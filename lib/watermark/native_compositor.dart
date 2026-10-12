import 'package:flutter/services.dart';

/// Ukuran foto dalam orientasi tampilan (EXIF sudah diperhitungkan).
typedef PhotoSize = ({int width, int height});

/// Jembatan ke kompositor native Android (`MainActivity.kt`): membaca ukuran
/// foto dan menempelkan overlay watermark ke foto penuh memakai
/// `BitmapFactory`/`Canvas`, jauh lebih cepat daripada dekode+encode JPEG
/// 12 MP di Dart. Semua method mengembalikan null/false saat platform tidak
/// tersedia (tes unit, platform lain) atau native gagal, sehingga pemanggil
/// cukup jatuh ke jalur render Dart.
class NativeCompositor {
  const NativeCompositor();

  static const _channel = MethodChannel('geopatriot/compositor');

  Future<PhotoSize?> imageSize(String path) async {
    try {
      final result = await _channel.invokeMapMethod<String, int>('imageSize', {'path': path});
      final width = result?['width'];
      final height = result?['height'];
      if (width == null || height == null || width <= 0 || height <= 0) return null;
      return (width: width, height: height);
    } catch (_) {
      return null;
    }
  }

  Future<bool> composite({
    required String sourcePath,
    required Uint8List overlayPng,
    required int x,
    required int y,
    required int quality,
    required String outputPath,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('composite', {
        'sourcePath': sourcePath,
        'overlayPng': overlayPng,
        'x': x,
        'y': y,
        'quality': quality,
        'outputPath': outputPath,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}

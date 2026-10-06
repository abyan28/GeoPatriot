import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// Index kamera pertama yang menghadap [direction], atau null bila tidak ada.
/// Entri PERTAMA tiap arah adalah kamera logis utama (di HP multi-lensa ia
/// yang punya rentang zoom penuh, mis. 0.6x ultra-wide). Perangkat bisa
/// mendaftarkan lebih dari dua kamera, jadi switch tidak boleh sekadar
/// memutar index.
int? pickCameraIndex(List<CameraDescription> cameras, CameraLensDirection direction) {
  final index = cameras.indexWhere((camera) => camera.lensDirection == direction);
  return index < 0 ? null : index;
}

/// Membungkus package `camera`: daftar kamera, inisialisasi controller, dan
/// switch kamera. Lifecycle (pause/resume saat app di-background) ditangani
/// oleh pemanggil lewat [pause] dan [resume], karena itu adalah concern
/// widget lifecycle, bukan tanggung jawab service ini.
class CameraControllerService {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _switching = false;

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  bool get hasMultipleCameras =>
      pickCameraIndex(_cameras, CameraLensDirection.back) != null &&
      pickCameraIndex(_cameras, CameraLensDirection.front) != null;

  /// True selama [switchCamera] berjalan; dipakai pemanggil untuk menolak
  /// tap ganda pada tombol switch.
  bool get isSwitching => _switching;

  /// Ambil daftar kamera yang tersedia lalu buka kamera pertama.
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw StateError('Tidak ada kamera yang tersedia pada perangkat ini.');
    }
    _selectedCameraIndex = pickCameraIndex(_cameras, CameraLensDirection.back) ?? 0;
    await _openCamera(_selectedCameraIndex);
  }

  /// Pindah ke kamera berikutnya (mis. depan ke belakang) jika perangkat
  /// punya lebih dari satu kamera. Controller lama dilepas LEBIH DULU
  /// sebelum yang baru dibuka (lihat [_openCamera]), jadi pemanggil harus
  /// sudah berhenti merender preview dari [controller] sebelum memanggil
  /// ini. Jika kamera baru gagal dibuka, kamera sebelumnya dibuka kembali
  /// dan exception dilempar ulang.
  Future<void> switchCamera() async {
    if (!hasMultipleCameras || _switching) return;
    _switching = true;
    final previousIndex = _selectedCameraIndex;
    try {
      final target = _cameras[previousIndex].lensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      _selectedCameraIndex = pickCameraIndex(_cameras, target)!;
      await _openCamera(_selectedCameraIndex);
    } catch (_) {
      _selectedCameraIndex = previousIndex;
      try {
        await _openCamera(previousIndex);
      } catch (_) {
        // Kamera sebelumnya pun gagal dibuka: controller tetap null,
        // pemanggil menangani lewat exception asli di bawah.
      }
      rethrow;
    } finally {
      _switching = false;
    }
  }

  /// Atur mode flash kamera (mis. off/auto/torch) jika kamera sudah siap.
  Future<void> setFlashMode(FlashMode mode) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setFlashMode(mode);
  }

  /// Level zoom minimum (selalu 1.0) yang didukung kamera aktif.
  Future<double> getMinZoomLevel() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return 1.0;
    return controller.getMinZoomLevel();
  }

  /// Level zoom maksimum (zoom hardware/optik sungguhan lewat API resmi
  /// package `camera`, BUKAN crop digital) yang didukung kamera aktif.
  Future<double> getMaxZoomLevel() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return 1.0;
    return controller.getMaxZoomLevel();
  }

  /// Ubah level zoom kamera aktif secara langsung (dipanggil berulang saat
  /// gesture cubit berlangsung).
  Future<void> setZoomLevel(double zoom) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await controller.setZoomLevel(zoom);
  }

  /// Ambil satu foto dari kamera yang sedang aktif. Orientasi capture
  /// dikunci HANYA sesaat di sekitar pemanggilan ini (bukan terus-menerus
  /// selama kamera menyala) — mengunci terus-menerus terbukti membuat
  /// CameraX ikut memutar tekstur PREVIEW secara berkelanjutan, bukan
  /// cuma foto hasil. Sumber orientasinya tetap sensor independen
  /// (`native_device_orientation`), bukan `controller.value.deviceOrientation`
  /// milik package `camera` yang terbukti macet di `portraitUp`.
  Future<XFile> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('Kamera belum siap.');
    }

    final sensorOrientation = await NativeDeviceOrientationCommunicator().orientation(useSensor: true);
    final deviceOrientation = sensorOrientation.deviceOrientation ?? DeviceOrientation.portraitUp;

    await controller.lockCaptureOrientation(deviceOrientation);
    try {
      return await controller.takePicture();
    } finally {
      await controller.unlockCaptureOrientation();
    }
  }

  /// Lepaskan resource kamera saat app masuk background. Controller akan
  /// dibuat ulang oleh [resume].
  Future<void> pause() async {
    await _controller?.dispose();
    _controller = null;
  }

  /// Buka kembali kamera setelah app kembali aktif dari background.
  Future<void> resume() async {
    if (_controller != null || _cameras.isEmpty) return;
    await _openCamera(_selectedCameraIndex);
  }

  /// Lepaskan semua resource kamera secara permanen (dipanggil saat screen
  /// ditutup, bukan sekadar pause).
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  /// Lepaskan controller lama LEBIH DULU, baru buat dan inisialisasi
  /// `CameraController` baru untuk kamera pada index tertentu. Dua
  /// controller tidak boleh hidup bersamaan: banyak perangkat (CameraX)
  /// gagal/menggantung saat membuka kamera depan selama sesi kamera
  /// belakang belum dilepas, dan [controller] lama yang sudah di-dispose
  /// tidak boleh tersisa sebagai nilai yang bisa dibaca widget.
  Future<void> _openCamera(int index) async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();

    final newController = CameraController(
      _cameras[index],
      // veryHigh = 1080p. `high` hanya 1280x720 (0,9 MP), terlalu kecil untuk
      // foto dokumentasi: preset yang sama dipakai preview DAN pengambilan foto.
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    try {
      await newController.initialize();
    } catch (_) {
      await newController.dispose();
      rethrow;
    }
    _controller = newController;
  }
}

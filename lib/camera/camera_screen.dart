import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../capture/capture_controller.dart';
import '../core/network/safe_fetch.dart';
import '../core/permissions/app_permissions.dart';
import '../geocoding/cached_geocoding_provider.dart';
import '../geocoding/locationiq_geocoding_provider.dart';
import '../geocoding/models/address_snapshot.dart';
import '../history/photo_history_service.dart';
import '../location/location_service.dart';
import '../location/models/location_snapshot.dart';
import '../map/cached_map_thumbnail_provider.dart';
import '../map/locationiq_map_thumbnail_provider.dart';
import '../map/models/map_snapshot.dart';
import '../settings/settings_controller.dart';
import '../storage/photo_storage_service.dart';
import '../core/theme/camera_tokens.dart';
import 'widgets/camera_bottom_bar.dart';
import 'widgets/fixed_camera_preview.dart';
import 'widgets/gps_status_pill.dart';
import 'camera_controller_service.dart';
import 'device_rotation_controller.dart';
import 'edge_anchored_rotated.dart';
import 'live_watermark_overlay.dart';
import 'zoom_ruler_control.dart';

/// Berapa lama banner "Tersimpan" tetap tampil setelah capture sukses,
/// sebelum otomatis hilang sendiri.
const _savedBannerDuration = Duration(seconds: 2);

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final _appPermissions = AppPermissions();
  final _cameraService = CameraControllerService();
  final _locationService = LocationService();

  // Instance yang sama dipakai live-preview dan CaptureController, supaya
  // cache geocoding/map terbagi (tidak dobel request ke LocationIQ).
  final _geocodingProvider = CachedGeocodingProvider(
    LocationIqGeocodingProvider(),
  );
  final _mapThumbnailProvider = CachedMapThumbnailProvider(
    LocationIqMapThumbnailProvider(),
  );
  final _rotationController = DeviceRotationController();

  late final CaptureController _captureController;

  AppPermissionsSummary? _permissions;
  bool _cameraReady = false;
  LocationSnapshot? _liveLocation;
  AddressSnapshot? _liveAddress;
  MapSnapshot? _liveMap;
  String? _lastLiveGeoKey;
  StreamSubscription<LocationSnapshot>? _locationSubscription;
  bool _showSavedBanner = false;
  Timer? _savedBannerTimer;
  bool _isFlashing = false;

  // Zoom kamera sungguhan (hardware/optik lewat API resmi package `camera`,
  // BUKAN crop digital) — dikendalikan lewat ZoomRulerControl (drag) DAN
  // gesture cubit di preview, keduanya menulis ke `_currentZoom` yang SAMA
  // (package `camera` tidak punya getter "level zoom saat ini", jadi
  // variabel inilah satu-satunya sumber kebenaran di sisi app).
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  /// Daftarkan observer lifecycle, siapkan capture controller, lalu mulai
  /// alur pengecekan izin.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = context.read<SettingsController>();
    _captureController = CaptureController(
      locationService: _locationService,
      cameraService: _cameraService,
      storageService: PhotoStorageService(),
      geocodingProvider: _geocodingProvider,
      mapThumbnailProvider: _mapThumbnailProvider,
      historyService: PhotoHistoryService(),
      watermarkConfigProvider: () => settings.settings.watermark,
      saveOriginalProvider: () => settings.settings.saveOriginal,
    );
    _bootstrap();
  }

  /// Cek status izin kamera/lokasi saat layar pertama dibuka; kalau semua
  /// sudah diberikan, langsung mulai kamera dan lokasi.
  Future<void> _bootstrap() async {
    final permissions = await _appPermissions.checkAll();
    setState(() => _permissions = permissions);
    if (permissions.allGranted) {
      await _startCameraAndLocation();
    }
  }

  /// Nyalakan kamera dan mulai stream lokasi live setelah izin lengkap.
  Future<void> _startCameraAndLocation() async {
    await _cameraService.initialize();
    if (mounted) setState(() => _cameraReady = true);
    // Cegah layar mati otomatis selagi preview kamera aktif, seperti
    // aplikasi kamera pada umumnya.
    await WakelockPlus.enable();

    final minZoom = await _cameraService.getMinZoomLevel();
    final maxZoom = await _cameraService.getMaxZoomLevel();
    if (mounted) {
      setState(() {
        _minZoom = minZoom;
        _maxZoom = maxZoom;
        _currentZoom = minZoom;
      });
    }

    _locationSubscription = _locationService.watchSnapshot().listen(
      (snapshot) {
        if (mounted) setState(() => _liveLocation = snapshot);
        _maybeUpdateLiveWatermarkData(snapshot);
      },
      onError: (_) {
        // GPS mati/bermasalah: biarkan status tetap null, tampilkan fallback di UI.
      },
    );
  }

  /// Ambil alamat/map thumbnail untuk watermark live HANYA saat lokasi
  /// berpindah ke titik yang "praktis berbeda" (presisi sama dengan
  /// `CoordinateCache`), supaya tidak memicu request LocationIQ berulang
  /// untuk pergerakan beberapa sentimeter. Memakai provider yang sama
  /// dengan `CaptureController`, jadi hasil ini juga dipakai ulang saat
  /// shutter benar-benar ditekan (tidak menambah jumlah request).
  Future<void> _maybeUpdateLiveWatermarkData(LocationSnapshot snapshot) async {
    final key =
        '${snapshot.latitude.toStringAsFixed(4)},${snapshot.longitude.toStringAsFixed(4)}';
    if (key == _lastLiveGeoKey) return;
    _lastLiveGeoKey = key;

    final config = context.read<SettingsController>().settings.watermark;

    if (config.showAddress || config.showLocationName) {
      final address = await fetchSafely(
        () => _geocodingProvider.reverseGeocode(
          latitude: snapshot.latitude,
          longitude: snapshot.longitude,
        ),
      );
      if (mounted) setState(() => _liveAddress = address);
    }

    if (config.showMapThumbnail) {
      final map = await fetchSafely(
        () => _mapThumbnailProvider.fetchThumbnail(
          latitude: snapshot.latitude,
          longitude: snapshot.longitude,
          zoom: config.mapZoom,
        ),
      );
      if (mounted) setState(() => _liveMap = map);
    }
  }

  /// Minta izin kamera/lokasi yang belum diberikan, lalu mulai kamera dan
  /// lokasi jika semuanya sudah lengkap setelah diminta.
  Future<void> _requestMissingPermissions() async {
    final current = _permissions;
    if (current == null) return;

    var camera = current.camera;
    var location = current.location;
    if (camera != AppPermissionState.granted) {
      camera = await _appPermissions.requestCamera();
    }
    if (location != AppPermissionState.granted) {
      location = await _appPermissions.requestLocation();
    }

    final updated = AppPermissionsSummary(camera: camera, location: location);
    setState(() => _permissions = updated);
    if (updated.allGranted) {
      await _startCameraAndLocation();
    }
  }

  /// Lepaskan kamera saat app masuk background, buka lagi saat app resume,
  /// supaya resource kamera tidak bocor atau bentrok dengan app lain.
  ///
  /// Sengaja HANYA bereaksi ke [AppLifecycleState.paused] (app benar-benar
  /// di-background), BUKAN [AppLifecycleState.inactive] — `inactive` juga
  /// terpicu sesaat oleh hal-hal transient seperti pengambilan screenshot
  /// sistem, notification shade, atau dialog izin, yang sebelumnya membuat
  /// kamera ikut di-dispose & diinisialisasi ulang tiap kejadian itu
  /// (terlihat sebagai layar putih + ikon loading sekilas).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_cameraReady && state != AppLifecycleState.resumed) return;
    if (state == AppLifecycleState.paused) {
      setState(() => _cameraReady = false);
      _cameraService.pause();
      WakelockPlus.disable();
    } else if (state == AppLifecycleState.resumed) {
      _cameraService.resume().then((_) {
        if (mounted) setState(() => _cameraReady = true);
      });
      WakelockPlus.enable();
    }
  }

  /// Bersihkan semua resource (observer, stream lokasi, kamera) saat layar
  /// ditutup.
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _savedBannerTimer?.cancel();
    _cameraService.dispose();
    _captureController.dispose();
    _rotationController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  /// Catat level zoom saat ini sebagai dasar sebelum gesture cubit dimulai.
  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  /// Ubah level zoom kamera sungguhan mengikuti gesture cubit, di-clamp ke
  /// rentang yang didukung kamera. `ZoomRulerControl` yang selalu terlihat
  /// otomatis ikut update posisi indikatornya lewat `_currentZoom` yang sama.
  void _onScaleUpdate(ScaleUpdateDetails details) {
    final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
    if (newZoom == _currentZoom) return;
    setState(() => _currentZoom = newZoom);
    _cameraService.setZoomLevel(newZoom);
  }

  /// Ubah level zoom kamera sesuai posisi drag di `ZoomRulerControl` —
  /// jalur kedua yang menulis ke `_currentZoom` yang sama dengan gesture
  /// cubit, supaya keduanya selalu sinkron.
  void _onRulerZoomChanged(double zoom) {
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    if (clamped == _currentZoom) return;
    setState(() => _currentZoom = clamped);
    _cameraService.setZoomLevel(clamped);
  }

  /// Jalankan capture saat tombol shutter ditekan, lalu tampilkan pesan
  /// error via snackbar jika gagal, atau banner "Tersimpan" (yang otomatis
  /// hilang sendiri setelah [_savedBannerDuration]) jika berhasil.
  Future<void> _onShutterPressed() async {
    setState(() => _isFlashing = true);
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) setState(() => _isFlashing = false);
    });

    await _captureController.capture();
    if (!mounted) return;
    if (_captureController.status == CaptureStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _captureController.errorMessage ?? 'Gagal mengambil foto.',
          ),
        ),
      );
      return;
    }

    _savedBannerTimer?.cancel();
    setState(() => _showSavedBanner = true);
    _savedBannerTimer = Timer(_savedBannerDuration, () {
      if (mounted) setState(() => _showSavedBanner = false);
    });
  }

  /// Bangun tampilan utama: layar kamera fullscreen immersive dengan
  /// HUD mengambang, tanpa AppBar konvensional yang memotong viewfinder.
  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;
    return ChangeNotifierProvider.value(
      value: _rotationController,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: permissions == null
            ? const Center(child: CircularProgressIndicator())
            : permissions.allGranted
            ? ChangeNotifierProvider.value(
                value: _captureController,
                child: _CameraBody(
                  cameraReady: _cameraReady,
                  controller: _cameraService.controller,
                  liveLocation: _liveLocation,
                  liveAddress: _liveAddress,
                  liveMap: _liveMap,
                  showSavedBanner: _showSavedBanner,
                  hasMultipleCameras: _cameraService.hasMultipleCameras,
                  minZoom: _minZoom,
                  maxZoom: _maxZoom,
                  currentZoom: _currentZoom,
                  isFlashing: _isFlashing,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onRulerZoomChanged: _onRulerZoomChanged,
                  onSwitchCamera: () async {
                    await _cameraService.switchCamera();
                    setState(() {});
                  },
                  onShutterPressed: _onShutterPressed,
                  onOpenGallery: () => Navigator.of(context).pushNamed('/history'),
                  onOpenSettings: () => Navigator.of(context).pushNamed('/settings'),
                ),
              )
            : _PermissionGate(
                permissions: permissions,
                onRequestPermissions: _requestMissingPermissions,
                onOpenSettings: _appPermissions.openSettings,
              ),
      ),
    );
  }
}

/// Bungkus [child] supaya berputar 90° per langkah mengikuti orientasi
/// fisik device (lihat [DeviceRotationController]), sementara posisi
/// widget di layar tidak berubah — pola standar kontrol aplikasi kamera.
///
/// Pakai [RotatedBox], bukan `Transform`/`AnimatedRotation`: `RotatedBox`
/// menukar lebar/tinggi widget SAAT LAYOUT (bukan cuma saat menggambar),
/// jadi kotak pembungkusnya ikut menyesuaikan dan tidak meluber keluar
/// area yang dialokasikan `Positioned` — beda dengan `Transform.rotate`
/// yang cuma memutar hasil gambarnya sehingga kontrol lebar (seperti
/// badge status GPS) meluber jadi bar tipis memanjang saat diputar.
class _RotatedControl extends StatelessWidget {
  const _RotatedControl({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final quarterTurns = context.watch<DeviceRotationController>().quarterTurns;
    return RotatedBox(quarterTurns: quarterTurns, child: child);
  }
}

class _PermissionGate extends StatelessWidget {
  const _PermissionGate({
    required this.permissions,
    required this.onRequestPermissions,
    required this.onOpenSettings,
  });

  final AppPermissionsSummary permissions;
  final VoidCallback onRequestPermissions;
  final VoidCallback onOpenSettings;

  /// Tampilkan pesan permintaan izin, dengan tombol yang berbeda tergantung
  /// apakah izin ditolak permanen (harus buka Settings) atau belum diminta.
  @override
  Widget build(BuildContext context) {
    final permanentlyDenied =
        permissions.camera == AppPermissionState.permanentlyDenied ||
        permissions.location == AppPermissionState.permanentlyDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Aplikasi membutuhkan izin kamera dan lokasi untuk menambahkan '
              'informasi GPS pada foto Anda.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: permanentlyDenied
                  ? onOpenSettings
                  : onRequestPermissions,
              child: Text(
                permanentlyDenied ? 'Buka Pengaturan' : 'Berikan Izin',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraBody extends StatelessWidget {
  const _CameraBody({
    required this.cameraReady,
    required this.controller,
    required this.liveLocation,
    required this.liveAddress,
    required this.liveMap,
    required this.showSavedBanner,
    required this.hasMultipleCameras,
    required this.minZoom,
    required this.maxZoom,
    required this.currentZoom,
    required this.isFlashing,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onRulerZoomChanged,
    required this.onSwitchCamera,
    required this.onShutterPressed,
    required this.onOpenGallery,
    required this.onOpenSettings,
  });

  final bool cameraReady;
  final CameraController? controller;
  final LocationSnapshot? liveLocation;
  final AddressSnapshot? liveAddress;
  final MapSnapshot? liveMap;
  final bool showSavedBanner;
  final bool hasMultipleCameras;
  final double minZoom;
  final double maxZoom;
  final double currentZoom;
  final bool isFlashing;
  final GestureScaleStartCallback onScaleStart;
  final GestureScaleUpdateCallback onScaleUpdate;
  final ValueChanged<double> onRulerZoomChanged;
  final VoidCallback onSwitchCamera;
  final VoidCallback onShutterPressed;
  final VoidCallback onOpenGallery;
  final VoidCallback onOpenSettings;

  /// Susun preview kamera, watermark live, banner hasil capture terakhir,
  /// floating top HUD, dan bottom control bar dalam satu stack.
  @override
  Widget build(BuildContext context) {
    final captureController = context.watch<CaptureController>();
    final session = captureController.lastSession;
    final quarterTurns = context.watch<DeviceRotationController>().quarterTurns;

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewScale = _previewScale(constraints, controller);

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Preview Kamera
            if (cameraReady && controller != null)
              GestureDetector(
                onScaleStart: onScaleStart,
                onScaleUpdate: onScaleUpdate,
                child: Center(child: FixedCameraPreview(controller!)),
              )
            else
              const Center(child: CircularProgressIndicator()),

            // 2. Overlay Watermark Live
            if (cameraReady && controller != null)
              LiveWatermarkOverlay(
                location: liveLocation,
                address: liveAddress,
                mapThumbnailBytes: liveMap?.imageBytes,
                previewScale: previewScale,
                previewAreaSize: constraints.biggest,
              ),

            // 3. Zoom Ruler
            if (cameraReady && maxZoom > minZoom)
              _buildZoomRuler(constraints, quarterTurns: quarterTurns),

            // 4. Shutter Flash Effect
            if (isFlashing)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(color: Colors.white.withValues(alpha: 0.65)),
                ),
              ),

            // 5. Banner Notifikasi Tersimpan (Tappable ke Galeri)
            if (session != null && showSavedBanner)
              EdgeAnchoredRotated(
                targetEdge: ScreenEdge.top,
                quarterTurns: quarterTurns,
                margin: 68,
                child: _LastCaptureBanner(
                  session: captureController,
                  onTap: onOpenGallery,
                ),
              ),

            // 6. Top Floating HUD (Pill Status GPS + Tombol Pengaturan)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RotatedControl(
                        child: GpsStatusPill(location: liveLocation),
                      ),
                      _RotatedControl(
                        child: IconButton(
                          tooltip: 'Pengaturan',
                          style: IconButton.styleFrom(
                            backgroundColor: CameraTokens.hudBackground,
                            side: BorderSide(color: CameraTokens.hudBorder, width: 1),
                            padding: const EdgeInsets.all(10),
                          ),
                          icon: const Icon(Icons.settings_outlined, color: Colors.white),
                          onPressed: onOpenSettings,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 7. Bottom Control Bar (Galeri + Shutter + Switch Camera)
            // Baris tombol kontrol bawah tetap berada di sisi fisik bawah layar
            // (bottom: 32) agar tombol rana nyaman dijangkau jempol di kedua
            // orientasi, sementara ikon-ikon di dalamnya berputar di tempat
            // (in-place) tanpa memutar kontainer baris menjadi kolom vertikal.
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: CameraBottomBar(
                quarterTurns: quarterTurns,
                cameraReady: cameraReady,
                busy: captureController.status == CaptureStatus.capturing,
                hasMultipleCameras: hasMultipleCameras,
                lastCapturedFile: session?.processedImageFile,
                onShutterPressed: onShutterPressed,
                onSwitchCamera: onSwitchCamera,
                onOpenGallery: onOpenGallery,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Bangun `ZoomRulerControl` yang posisinya berpindah mulus (bukan
  /// loncat/berkedip) antara sisi kanan (portrait) dan dekat bawah
  /// (landscape) — selalu pakai `left`+`top` absolut (dihitung manual untuk
  /// tiap orientasi) di kedua kasus, bukan bertukar `left`/`right`/`top`/
  /// `bottom` mana yang null, supaya `AnimatedPositioned` bisa
  /// meng-interpolasi angkanya dengan benar alih-alih widget "meloncat"
  /// begitu saja saat orientasi berubah.
  ///
  /// `ZoomRulerControl` SENDIRI selalu vertikal (lihat dokumentasinya) —
  /// `RotatedBox(quarterTurns: quarterTurns)` di sini yang membuatnya
  /// tampak horizontal & terbaca benar saat device dimiringkan, pola yang
  /// SAMA dengan `_RotatedControl` (ikon-ikon lain di layar ini). Ukuran
  /// setelah dirotasi (lebar/tinggi TERTUKAR untuk quarterTurns ganjil)
  /// dipakai untuk hitung posisi, supaya tetap pas di kedua orientasi.
  Widget _buildZoomRuler(BoxConstraints constraints, {required int quarterTurns}) {
    const rulerLength = 220.0;
    const rulerThickness = ZoomRulerControl.thickness;
    const edgeMargin = 8.0;
    // Diletakkan di atas baris tombol shutter (bottom: 48, tinggi ~72)
    // supaya tidak tumpang tindih saat landscape.
    const landscapeBottomMargin = 140.0;
    final isLandscape = quarterTurns.isOdd;

    final portraitLeft = constraints.maxWidth - rulerThickness - edgeMargin;
    final portraitTop = (constraints.maxHeight - rulerLength) / 2;
    final landscapeLeft = (constraints.maxWidth - rulerLength) / 2;
    final landscapeTop = constraints.maxHeight - landscapeBottomMargin - rulerThickness;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      left: isLandscape ? landscapeLeft : portraitLeft,
      top: isLandscape ? landscapeTop : portraitTop,
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: ZoomRulerControl(
          minZoom: minZoom,
          maxZoom: maxZoom,
          currentZoom: currentZoom,
          onZoomChanged: onRulerZoomChanged,
          length: rulerLength,
        ),
      ),
    );
  }

  /// Hitung faktor skala antara "1 piksel resolusi asli kamera" dan "1
  /// logical pixel di layar", supaya ukuran panel watermark live (dirender
  /// dalam logical pixel Flutter) bisa dibuat SEBANDING SECARA PROPORSI
  /// dengan panel watermark hasil foto akhir (dirender `WatermarkRenderer`
  /// dalam piksel gambar beresolusi tinggi) — tanpa penyesuaian ini, angka
  /// ukuran yang sama (mis. fontSize 20) akan terlihat jauh lebih besar di
  /// preview kecil dibanding di foto beresolusi tinggi.
  ///
  /// `CameraPreview` membesarkan diri mengikuti `controller.value.aspectRatio`
  /// sampai sebesar mungkin di area yang tersedia (pola containment-fit
  /// `AspectRatio` standar), jadi rasio (lebar preview di layar ÷
  /// `previewSize.width`) adalah faktor skala yang konsisten, terlepas dari
  /// orientasi sensor vs layar.
  double _previewScale(
    BoxConstraints constraints,
    CameraController? controller,
  ) {
    final previewSize = controller?.value.previewSize;
    if (controller == null || previewSize == null || previewSize.width <= 0) {
      return 1.0;
    }

    final aspectRatio = controller.value.aspectRatio;
    final onScreenWidth =
        constraints.maxWidth / constraints.maxHeight > aspectRatio
        ? constraints.maxHeight * aspectRatio
        : constraints.maxWidth;

    return onScreenWidth / previewSize.width;
  }
}

class _LastCaptureBanner extends StatelessWidget {
  const _LastCaptureBanner({required this.session, required this.onTap});

  final CaptureController session;
  final VoidCallback onTap;

  /// Tampilkan banner foto terakhir yang berhasil disimpan dan dapat diketuk
  /// untuk langsung membuka galeri foto.
  @override
  Widget build(BuildContext context) {
    final capture = session.lastSession;
    if (capture == null) return const SizedBox.shrink();

    final formatted = DateFormat(
      'HH:mm:ss',
      'id_ID',
    ).format(capture.timestamp);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: CameraTokens.hudBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: CameraTokens.hudBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  capture.processedImageFile,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  cacheWidth: 96,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tersimpan $formatted (Buka)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

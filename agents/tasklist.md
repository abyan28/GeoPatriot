# Tasklist — GPS Map Camera

Progress: 95% (Fase 0-13 selesai; Fase Redesign UI/UX komprehensif selesai; Fase 14 opsional sengaja tidak dikerjakan, Fase 15 checklist rilis manual belum dikerjakan)

Mengacu ke `agents/workflow-free-first.md`. Centang `[✓]` + ✅ setiap fase/task selesai, dengan catatan file yang dibuat/diubah. AI wajib update file ini setiap selesai satu task, sebelum melapor ke user (lihat `prd-free-first.md` §22).

## Fase 0 — Project Bootstrap
- [✓] ✅ Bootstrap project Flutter, struktur folder, dependency awal (Selesai)
  * `pubspec.yaml`, `.gitignore`, `README.md`

## Fase 1 — App Shell
- [✓] ✅ Navigasi Camera/Settings/History + permission state UI (Selesai)

## Fase 2 — Camera
- [✓] ✅ Camera preview, shutter, switch kamera, simpan foto original (Selesai)

## Fase 3 — Location
- [✓] ✅ GPS live status, kategori akurasi, freeze snapshot (Selesai)

## Fase 4 — Timestamp & Capture Session
- [✓] ✅ CaptureSession (image+location+timestamp dari momen yang sama) (Selesai)

## Fase 5 — Capture Session + Watermark Core
- [✓] ✅ Watermark renderer + konfigurasi + template (Selesai)
  * `lib/watermark/models/watermark_position.dart`, `watermark_configuration.dart`, `watermark_template.dart`, `watermark_data.dart`
  * `lib/watermark/watermark_renderer.dart` (pure, pakai package `image`, tidak ada HTTP/GPS di dalamnya)
  * Test: `test/watermark_renderer_test.dart` (portrait, landscape, address kosong, address panjang, resolusi kecil & besar, template compact)

## Fase 6 — Local Storage + Original/Processed
- [✓] ✅ Processed photo terpisah dari original, history metadata, share/delete (Selesai)
  * `lib/storage/photo_storage_service.dart`: `reserveBaseName`, `saveOriginal`, `saveProcessed`, `deleteByBaseName` (nama dasar sinkron antara original & processed)
  * `lib/history/models/history_entry.dart`, `lib/history/photo_history_service.dart` (index JSON lokal, bukan database)
  * `lib/history/history_screen.dart`: gallery grid, detail, share (`share_plus`), delete dengan konfirmasi, empty state

## Fase 7 — Geocoding Provider Abstraction
- [✓] ✅ `GeocodingProvider` + `NominatimGeocodingProvider` + cache + formatter (Selesai)
  * `lib/geocoding/geocoding_provider.dart`, `nominatim_geocoding_provider.dart` (rate limit 1 req/detik, User-Agent, timeout 8s), `cached_geocoding_provider.dart`
  * `lib/geocoding/models/address_snapshot.dart`, `lib/geocoding/address_formatter.dart`
  * Test: `test/address_formatter_test.dart`
  * CATATAN: `_userAgent` di `nominatim_geocoding_provider.dart` masih placeholder kontak, wajib diganti kontak nyata sebelum rilis (sesuai policy Nominatim)

## Fase 8 — Map Thumbnail Provider
- [✓] ✅ `MapThumbnailProvider` + implementasi raster tile OSM + cache (Selesai)
  * `lib/map/map_thumbnail_provider.dart`, `osm_raster_map_thumbnail_provider.dart` (stitching tile.openstreetmap.org, marker, attribution), `cached_map_thumbnail_provider.dart`
  * CATATAN: `tile.openstreetmap.org` cocok untuk dev/skala kecil saja; ganti provider raster OSM-derived lain sebelum trafik produksi besar (lihat komentar di file & rules-free-first.md §12)

## Fase 9 — Map/Address Cache
- [✓] ✅ Cache generik berbasis koordinat, dipakai geocoding & map (Selesai)
  * `lib/core/cache/coordinate_cache.dart` (pembulatan presisi, TTL, clear)
  * Test: `test/coordinate_cache_test.dart`

## Fase 10 — Offline Fallback
- [✓] ✅ Fallback jaringan di level kode, teruji otomatis (Selesai)
  * `lib/core/network/safe_fetch.dart` dipakai geocoding & map di `CaptureController` (timeout 8s, exception apa pun → null, tidak pernah menggagalkan capture)
  * Test: `test/safe_fetch_test.dart`
  * BELUM: verifikasi manual airplane-mode di device fisik (tidak ada device tersambung di lingkungan ini)

## Fase 11 — Settings dan Template
- [✓] ✅ Field visibility, posisi, appearance, template, persistence (Selesai)
  * `lib/settings/models/app_settings.dart`, `settings_service.dart` (shared_preferences), `settings_controller.dart` (Provider ChangeNotifier)
  * `lib/settings/settings_screen.dart`: UI lengkap (toggle field, pilihan posisi, slider opacity/font/thumbnail/zoom, custom text, save-original)
  * Test: `test/settings_service_test.dart`

## Fase 12 — EXIF
- [✓] ✅ Tulis GPS + DateTimeOriginal ke file processed (Selesai)
  * `lib/capture/exif_writer.dart` pakai `native_exif`, dibungkus try/catch non-fatal di `CaptureController`
  * CATATAN keterbatasan: format altitude berbeda Android (rational string) vs iOS (double) mengikuti native code masing-masing platform (lihat komentar di file); belum diverifikasi di device iOS nyata (tidak ada Mac di lingkungan ini)

## Fase 13 — Quality, Testing, Platform
- [~] Sebagian selesai:
  * `flutter analyze`: bersih
  * `flutter test`: 26 test lulus (formatter, cache, watermark 6 skenario, safe-fetch, settings persistence, model)
  * `flutter build apk --debug`: diverifikasi sukses
  * BELUM: uji di device Android/iOS fisik, uji manual low-light/GPS lemah/storage penuh (butuh device nyata)

## Fase 14 — Optional Satellite Provider
- [ ] Sengaja tidak dikerjakan: eksplisit opsional, bukan syarat MVP (lihat prd-free-first.md §9.2)

## Fase 15 — Release Readiness
- [ ] Belum dikerjakan: checklist rilis (App icon custom, app name final, signing config, review privacy text) — sebagian besar berupa keputusan produk/aset, bukan kode

---

## Catatan Non-Fase (perbaikan/audit tambahan)
- [✓] ✅ Audit `agents/ANTISLOP-ID.md` terhadap `camera_screen.dart` (Selesai)
- [✓] ✅ Fix bug build Android: Kotlin incremental compiler cross-drive crash (Selesai)
- [✓] ✅ Fix bug build Android: `camera_android_camerax` versi lama tidak kompatibel (Selesai)
- [✓] ✅ Adopsi pedoman baru dari `prd-free-first.md` §22-23: tasklist.md + komentar Indonesia (Selesai)
- [✓] ✅ Rename folder root project `Geotag Camera` → `GPS Camera` (Selesai oleh user, sesi baru dibuka)
- [✓] ✅ Tambah `android.permission.INTERNET` ke AndroidManifest (dibutuhkan geocoding/map tile) (Selesai)
- [✓] ✅ Fix bug build Android: `native_exif 0.6.2` hardcode `compileSdkVersion 33`, konflik dengan androidx modern (Selesai)
  * `pubspec.yaml`: upgrade `native_exif: ^0.6.0` → `^0.8.0` (versi baru pakai `flutter.compileSdkVersion` dinamis)
  * `flutter build apk --debug` sukses setelah upgrade (~167MB)
  * CATATAN: ada warning non-fatal dari Flutter soal plugin `native_exif` & `share_plus` yang masih apply Kotlin Gradle Plugin (KGP) lama; belum breaking, tapi perlu dipantau di update Flutter berikutnya
- [✓] ✅ Diagnostik alamat tidak muncul & map thumbnail rusak → TERKONFIRMASI, provider diganti (Selesai)
  * Bukti log device nyata: Nominatim membalas `403 "Access denied. See https://operations.osmfoundation.org/policies/nominatim/"` (block eksplisit, bukan rate-limit); 9 tile `tile.openstreetmap.org` di koordinat berbeda-beda semua membalas `status=200 bytes=6987` (identik persis → gambar "soft-block" pengganti, bukan peta asli)
  * Keputusan user (AskUserQuestion): pindah ke **LocationIQ** untuk geocoding + map thumbnail (satu API key, free tier, memang didesain untuk aplikasi)
  * File baru: `lib/core/config/api_keys.dart` (`String.fromEnvironment('LOCATIONIQ_API_KEY')`, tidak di-hardcode), `lib/geocoding/locationiq_geocoding_provider.dart`, `lib/map/locationiq_map_thumbnail_provider.dart`
  * `lib/camera/camera_screen.dart`: wiring provider diganti ke LocationIQ (dibungkus `CachedGeocodingProvider`/`CachedMapThumbnailProvider` yang sudah ada, tidak berubah)
  * Provider Nominatim/OSM tile lama TIDAK dihapus (`nominatim_geocoding_provider.dart`, `osm_raster_map_thumbnail_provider.dart`), tetap sebagai referensi implementasi provider alternatif
  * `README.md` diupdate: cara daftar & pakai API key LocationIQ (`--dart-define=LOCATIONIQ_API_KEY=...`)
  * VERIFIKASI DEVICE: berhasil — alamat & map thumbnail asli sudah muncul di foto uji nyata
- [✓] ✅ Fix akar masalah orientasi — TERKONFIRMASI BERHASIL di device nyata (Selesai)
  * PERCOBAAN #1 (lock ke `controller.value.deviceOrientation`) GAGAL — `deviceOrientation` stuck di `portraitUp` walau HP landscape (bug plugin `camera`/`camera_android_camerax`)
  * PERCOBAAN #2 (BERHASIL): baca orientasi dari `native_device_orientation` (sensor fisik langsung), independen dari tracking internal `camera` plugin yang bermasalah
  * VERIFIKASI DEVICE: log menunjukkan `NativeDeviceOrientation.landscapeLeft` terdeteksi benar dan `EXIF Orientation mentah: 1` (normal, tidak perlu rotasi) — watermark & foto sudah mengikuti orientasi landscape dengan benar
- [✓] ✅ Fix "glitch" preview saat capture (Selesai)
  * Penyebab: `lockCaptureOrientation()`/`unlockCaptureOrientation()` dipanggil di SETIAP `takePicture()`, memicu CameraX mengonfigurasi ulang sesi preview tiap shutter ditekan
  * Fix: `lib/camera/camera_controller_service.dart` sekarang mengunci orientasi lewat stream (`onOrientationChanged`) sekali saat kamera dibuka, hanya mengunci ulang saat orientasi BENAR-BENAR berubah; `takePicture()` tidak lock/unlock sama sekali lagi
  * Log diagnostik orientasi (per-capture) dihapus karena bug sudah tuntas; diganti log ringan hanya saat orientasi berubah
- [✓] ✅ Fix alamat berbahasa Inggris (Selesai)
  * `lib/geocoding/locationiq_geocoding_provider.dart`: tambah parameter `accept-language: id`
- [✓] ✅ Fix teks alamat & attribution terpotong di tengah kata (Selesai)
  * `lib/watermark/watermark_renderer.dart`: baris alamat/custom text sekarang boleh wrap sampai 2 baris dengan pemutusan di batas kata (`_WatermarkLine`, `_wrapLine`, `_lastWordBreak`), bukan dipotong paksa 1 baris
- [✓] ✅ Fix spasi aneh sebelum "LocationIQ" di attribution (Selesai)
  * Penyebab: karakter "©" tidak punya glyph di bitmap font `image` package, dirender kosong tapi tetap makan lebar
  * `lib/map/locationiq_map_thumbnail_provider.dart`: hapus "©" dari `_attribution` (kredit LocationIQ + OpenStreetMap tetap dipertahankan, wajib sesuai ToS LocationIQ)
- [✓] ✅ Redesign watermark: box menyesuaikan konten, hierarki font, ukuran diperbesar, accuracy default OFF (Selesai)
  * `lib/watermark/watermark_renderer.dart`: `panelWidth` sekarang dihitung dari lebar konten aktual (wrap + thumbnail + padding), bukan dipaksa selebar foto; baris nama lokasi pakai font satu tingkat lebih besar dari body (`_titleFontFor`)
  * `lib/watermark/models/watermark_configuration.dart`: `defaultTemplate()` — `fontSize` 14→20, `thumbnailSize` 96→140, `showAccuracy` true→false; `detail()` — `fontSize` 15→22, `thumbnailSize` 112→160; `compact()` — `fontSize` 12→14
  * BELUM diverifikasi ulang di device fisik oleh user (menunggu uji berikutnya)
- [✓] ✅ Fix UI landscape "aneh" & preview tidak full-screen (Selesai)
  * Root cause: aplikasi tidak mengunci orientasi UI, sehingga layout jadi tidak konsisten saat device landscape (bukan transient glitch seperti dugaan sebelumnya) — pola standar aplikasi kamera adalah UI dikunci portrait, sensor orientasi hanya dipakai untuk EXIF foto (sudah benar sejak fix sebelumnya)
  * `lib/main.dart`: `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`
  * `android/app/src/main/AndroidManifest.xml`: `android:screenOrientation="portrait"` pada MainActivity
  * `lib/camera/camera_screen.dart`: preview kamera diganti dari `Center(child: CameraPreview(...))` (letterbox, tidak mengisi layar) ke `_FullBleedCameraPreview` (pola `Transform.scale` + `AspectRatio` + `ClipRect` standar, mengisi layar penuh seperti aplikasi kamera lain)
  * BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Watermark live preview (floating overlay sebelum capture) (Selesai)
  * File baru `lib/camera/live_watermark_overlay.dart`: render panel watermark pakai widget Flutter biasa (bukan `WatermarkRenderer`/`image` package yang berat untuk live), posisi mengikuti `WatermarkConfiguration.position` aktif
  * `lib/camera/camera_screen.dart`: alamat & map thumbnail untuk live preview diambil proaktif saat lokasi berpindah ke titik "praktis berbeda" (presisi sama `CoordinateCache`), pakai instance `CachedGeocodingProvider`/`CachedMapThumbnailProvider` yang SAMA dengan `CaptureController` (cache terbagi, tidak menambah request LocationIQ dibanding sebelumnya — hanya pindah waktu fetch jadi lebih awal)
  * BUKAN pixel-perfect sama dengan hasil akhir (font Flutter vs bitmap font watermark renderer akan sedikit berbeda) — representasi visual, bukan preview identik
  * BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Rotasi ikon/panel UI mengikuti orientasi fisik saat landscape (Selesai)
  * Root cause sebenarnya (dikonfirmasi dari perbandingan screenshot user vs aplikasi referensi): kunci UI ke portrait itu SUDAH BENAR dan dipakai juga oleh aplikasi referensi (posisi kontrol tidak berpindah) — yang belum dibangun adalah rotasi KONTEN kontrol (ikon/teks/panel) 90° di tempat supaya tetap terbaca saat HP dipegang miring
  * File baru `lib/camera/device_rotation_controller.dart`: `ChangeNotifier` yang melacak sensor orientasi (`native_device_orientation`, sumber sama dengan yang dipakai EXIF, subscription terpisah) dan expose `quarterTurns` (0/1/2/3)
  * `lib/camera/camera_screen.dart`: widget `_RotatedControl` (`AnimatedRotation`) membungkus ikon AppBar (Settings/Riwayat), tombol switch kamera, tombol shutter, GPS badge, dan banner "Tersimpan" — posisi di layar tetap, hanya konten yang berputar
  * `lib/camera/live_watermark_overlay.dart`: seluruh panel watermark live ikut diputar sebagai satu blok (meniru referensi)
- [✓] ✅ Auto-hide banner "Tersimpan", fix posisi+ukuran card saat landscape, layar tetap menyala saat kamera aktif (Selesai)
  * Diputuskan (dikonfirmasi user via AskUserQuestion): TETAP kunci UI ke portrait, tidak ikut berputar sungguhan seperti kamera bawaan HP — sesuai perilaku aplikasi referensi GPS Map Camera yang juga terkunci portrait
  * Root cause bug "kotak membesar aneh saat landscape": `Positioned(top:16,left:16,right:16,...)` membuat lebar jadi TEGAS (tight), lalu `RotatedBox` menukar balik batasan lebar/tinggi itu untuk anaknya saat quarterTurns ganjil — anak jadi dipaksa setinggi lebar layar penuh
  * Root cause bug "posisi tidak ikut pindah sisi saat landscape": piksel layar tidak ikut berputar (dikunci portrait), cuma konten yang berputar lewat `RotatedBox`, jadi sisi fisik HP yang tetap (atas/kanan/bawah/kiri) berpindah makna dari sudut pandang pengguna saat dimiringkan — card yang nempel di tepi-atas-fisik jadi terlihat nempel di kiri/kanan tergantung arah kemiringan
  * File baru `lib/camera/edge_anchored_rotated.dart`: widget `EdgeAnchoredRotated` — terima target sisi dari SUDUT PANDANG PENGGUNA (atas/kanan/bawah/kiri), hitung sisi fisik yang benar dipakai via rumus `(targetEdge + quarterTurns) % 4`, dibungkus `Center` supaya batasan yang diteruskan ke `RotatedBox` selalu longgar (sekaligus jadi fix generik untuk bug ukuran membesar di atas)
  * `lib/camera/camera_screen.dart`: `_LastCaptureBanner` pakai `EdgeAnchoredRotated(targetEdge: top)` — selalu tampak di atas dari sudut pandang pengguna, portrait maupun landscape kedua arah
  * `lib/camera/live_watermark_overlay.dart`: posisi `top`/`bottom` (default) pakai `EdgeAnchoredRotated`; posisi 4 sudut (topLeft/dst, bukan default) TIDAK diubah — tetap menempel sudut fisik yang sama seperti sebelumnya (di luar cakupan laporan bug ini)
  * Banner "Tersimpan": tambah auto-hide — `_CameraScreenState` sekarang punya `_showSavedBanner`+`_savedBannerTimer`, otomatis disembunyikan 2 detik setelah capture sukses (data `lastSession` di `CaptureController` sendiri TIDAK dihapus, cuma visibilitas banner di UI)
  * Layar tetap menyala saat kamera aktif: tambah dependency `wakelock_plus` (memakai `FLAG_KEEP_SCREEN_ON` Android, tidak butuh izin manifest tambahan) — `WakelockPlus.enable()` dipanggil setelah kamera siap & saat app resume, `WakelockPlus.disable()` saat app pause/dispose
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix preview kamera tampil miring/rusak terus-menerus saat landscape (Selesai)
  * Root cause sebenarnya: fix "glitch saat capture" sebelumnya (lock orientasi terus-menerus lewat stream, re-lock tiap sensor berubah) TERBUKTI membuat CameraX ikut memutar TEKSTUR PREVIEW kamera secara berkelanjutan selama kamera menyala, bukan cuma memengaruhi EXIF foto hasil — inilah penyebab layar kamera terlihat "aneh"/rusak terus-menerus di landscape, bukan sekadar transient
  * Dikonfirmasi lewat urutan gejala yang diingat user: masalah ini mulai muncul persis sejak sesi lalu mengganti mekanisme lock jadi terus-menerus
  * `lib/camera/camera_controller_service.dart`: hapus mekanisme lock terus-menerus (`_watchOrientation`, `_orientationSubscription`), kembali ke lock SEKALI-PAKAI tepat sebelum `takePicture()` dan unlock segera sesudahnya (pola seperti percobaan pertama), tapi sumber orientasinya tetap dibaca one-shot dari `native_device_orientation` (bukan `controller.value.deviceOrientation` yang terbukti macet di `portraitUp`)
  * Konsekuensi yang bisa diterima: preview normal selama user mengarahkan kamera; kemungkinan ada kedipan super singkat tepat saat shutter ditekan, foto hasil tetap berorientasi benar
  * BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix arah rotasi ikon/panel UI terbalik (Selesai)
  * User konfirmasi rotasi berjalan tapi arahnya salah
  * `lib/camera/device_rotation_controller.dart`: tukar nilai `quarterTurns` untuk `NativeDeviceOrientation.landscapeLeft` (3→1) dan `landscapeRight` (1→3)
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix preview kamera terlihat "ter-zoom"/terlalu besar (Selesai)
  * Root cause: rumus skala di `_FullBleedCameraPreview` (`controller.value.aspectRatio / deviceRatio`) BENAR untuk layar yang bisa berputar bebas, tapi SALAH sejak UI dikunci portrait terus-menerus — `controller.value.aspectRatio` dari sensor kamera selalu >1 ("landscape"), sedangkan rasio layar yang dikunci portrait selalu <1, sehingga pembagian langsung menghasilkan skala sangat besar (preview jadi tampak ter-zoom, padahal tidak ada fitur zoom yang aktif)
  * `lib/camera/camera_screen.dart`: `_FullBleedCameraPreview` sekarang pakai rumus resmi contoh package `camera` untuk preview full-bleed di layar terkunci portrait — `scale = size.aspectRatio * controller.value.aspectRatio`, dibalik `1/scale` jika hasilnya <1
  * VERIFIKASI: `flutter analyze` bersih; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Kembalikan preview kamera ke versi semula (sebelum revisi full-bleed) atas permintaan user (Selesai)
  * User menilai preview full-bleed (`_FullBleedCameraPreview`, `Transform.scale`) hasilnya lebih jelek daripada versi awal, walau rumus skalanya sudah diperbaiki — diminta kembali ke kondisi sebelum rangkaian revisi kunci orientasi
  * `lib/camera/camera_screen.dart`: `_CameraBody` kembali pakai `Center(child: CameraPreview(controller!))` polos (letterbox, sesuai aspect ratio asli kamera, tidak dipotong/di-scale); widget `_FullBleedCameraPreview` dihapus (tidak dipakai lagi)
  * VERIFIKASI: `flutter analyze` bersih; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Hapus badge koordinat live, pindahkan watermark (live & hasil akhir) ke bottom-center (Selesai)
  * Permintaan user: hapus kotak koordinat GPS live (dianggap tidak perlu, sudah terwakili watermark), dan watermark harus selalu bottom-center di kedua mode (portrait & landscape)
  * `lib/camera/camera_screen.dart`: hapus widget `_GpsStatusBadge` beserta pemanggilannya; banner "Tersimpan" naik ke `top: 16` (sebelumnya `top: 72`, dulu di bawah badge yang kini dihapus)
  * `lib/watermark/watermark_renderer.dart`: `_panelOrigin` untuk `WatermarkPosition.top`/`bottom` sekarang menghitung `dx` rata tengah horizontal (`(imageWidth - panelWidth) ~/ 2`), bukan rata kiri seperti sebelumnya (default template sudah pakai `WatermarkPosition.bottom`, jadi ini otomatis membuat hasil akhir watermark bottom-center)
  * `lib/camera/live_watermark_overlay.dart`: untuk posisi `top`/`bottom`, panel live dibungkus `Center` dengan `left: 0, right: 0` (bukan `margin` rata kiri/kanan) — posisi Positioned ini tidak berubah saat device diputar (hanya konten di dalamnya yang berputar lewat `RotatedBox`), jadi otomatis tetap bottom-center di portrait maupun landscape
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Samakan proporsi ukuran kotak watermark live dengan hasil foto (Selesai)
  * Root cause: `WatermarkRenderer` (hasil foto) memakai `config.fontSize`/`thumbnailSize`/dll sebagai piksel LANGSUNG di atas gambar beresolusi tinggi (mis. 3000-4000px lebar) — proporsinya kecil; `LiveWatermarkOverlay` (preview) memakai angka KONFIGURASI YANG SAMA sebagai logical pixel Flutter langsung di atas widget preview yang jauh lebih kecil (~400dp) — proporsinya jadi jauh lebih besar. Bukan bug render, tapi belum ada penyesuaian skala antar dua "ruang piksel" yang beda jauh resolusinya
  * `lib/camera/camera_screen.dart`: `_CameraBody` dibungkus `LayoutBuilder`, tambah `_previewScale()` — hitung rasio (lebar preview kamera yang benar-benar tampil di layar, hasil containment-fit `AspectRatio` seperti pola resmi package `camera`) ÷ (`controller.value.previewSize.width`, resolusi asli kamera)
  * `lib/camera/live_watermark_overlay.dart`: terima `previewScale`, kalikan ke semua ukuran berbasis config sebelum dipakai (fontSize, thumbnailSize, spacing, cornerRadius, margin, padding dalam — disamakan ke `_finalInnerPadding=14` acuan `WatermarkRenderer`); `config.opacity` TIDAK dikalikan (sudah fraksi 0..1)
  * TIDAK mengubah `WatermarkConfiguration` (tidak ada migrasi data tersimpan) maupun `WatermarkRenderer` (hasil foto tetap acuan proporsi yang benar) — murni penyesuaian tampilan live preview
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Kalibrasi ukuran watermark live ~3x + cegah tabrakan dengan tombol shutter (Selesai)
  * User bandingkan langsung 2 screenshot (`ss mode portrait.jpg` vs `hasil portrait.jpeg`): kotak live cuma ~41% lebar layar padahal hasil foto ~penuh lebar — rumus rasio resolusi murni ternyata masih terlalu kecil (previewSize kemungkinan tidak identik resolusi JPEG hasil capture asli, dan orientasi width/height-nya juga berpotensi salah arah)
  * `lib/camera/live_watermark_overlay.dart`: tambah konstanta `_liveScaleCalibration = 3.0` (angka empiris dari pengukuran nyata user, BUKAN turunan matematis — didokumentasikan gampang disetel ulang), dikalikan ke `previewScale` sebelum dipakai ke semua ukuran
  * Tabrakan dengan shutter: kotak watermark (target bawah) dan tombol shutter sama-sama di fisik-bawah-tengah — solusi yang dipilih: beri jarak tambahan ke watermark, BUKAN memindah tombol/mengecilkan area preview permanen (opsi yang sempat dipertimbangkan tapi lebih invasif)
  * `lib/camera/edge_anchored_rotated.dart`: tambah parameter opsional `extraBottomMargin`, HANYA diterapkan saat sisi fisik yang dipakai adalah bawah (otomatis berlaku juga untuk kasus jarang HP posisi terbalik, tanpa logika khusus tambahan)
  * `lib/camera/live_watermark_overlay.dart`: kirim `extraBottomMargin: _bottomControlsClearance` (112.0 — offset tombol 24 + diameter shutter 72 + jarak napas) saat posisi watermark `bottom`
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix kotak watermark live terlalu besar/menumpuk saat landscape (Selesai)
  * User konfirmasi portrait sudah pas (tidak diubah). Landscape terlalu besar karena 2 sebab: (1) lebar maksimum panel (`maxWidth: 320`) tetap dipakai apa adanya walau panel diputar 90° sebagai satu blok — padahal ruang yang tersedia untuk melebar saat landscape jauh lebih lega (setinggi layar portrait, bukan sesempit lebar layar portrait); (2) baris alamat/custom text di live overlay TIDAK punya batas jumlah baris sama sekali (beda dari `WatermarkRenderer` yang membatasi 2 baris), jadi di font besar hasil kalibrasi 3x, teks menumpuk jadi banyak baris dan panel jadi sangat tinggi
  * `lib/camera/live_watermark_overlay.dart`: `maxWidth` sekarang kondisional — portrait tetap `320` (tidak diubah), landscape (`quarterTurns.isOdd`) pakai `previewAreaSize.height * 0.62` (jauh lebih lega, memberi ruang melebar supaya baris tidak menumpuk); `addLine()` sekarang terima `maxLines` (default 1, dipakai `2` untuk alamat/custom text meniru `WatermarkRenderer`), pakai `TextOverflow.ellipsis`
  * `lib/camera/camera_screen.dart`: `_CameraBody` meneruskan `previewAreaSize: constraints.biggest` (dari `LayoutBuilder` yang sama dipakai `_previewScale`) ke `LiveWatermarkOverlay`
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user — kalau masih kurang pas, `_landscapeMaxWidthFraction`/`_liveScaleCalibration` tinggal disetel lagi
- [✓] ✅ Kecilkan lagi ukuran watermark live khusus landscape (Selesai)
  * User konfirmasi portrait sudah pas (JANGAN diubah); landscape masih agak besar walau lebar panel sudah dilonggarkan — minta dikecilkan langsung
  * `lib/camera/live_watermark_overlay.dart`: tambah `_landscapeScaleMultiplier = 0.6`, dikalikan ke `scale` HANYA saat `isLandscape` (di atas `_liveScaleCalibration` yang tetap 3.0 tidak berubah, supaya portrait tidak ikut terpengaruh)
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user — angka `0.6` gampang disetel lagi kalau masih kurang/lebih pas
- [✓] ✅ Kecilkan juga ukuran watermark live portrait (samakan dengan landscape) (Selesai)
  * User konfirmasi landscape sudah bagus, minta portrait ikut dikecilkan dengan besaran yang sama ("1x dari size sekarang")
  * `lib/camera/live_watermark_overlay.dart`: sederhanakan — `_landscapeScaleMultiplier` (0.6, sebelumnya cuma berlaku landscape) dilebur jadi satu `_liveScaleCalibration = 1.8` (dari `3.0 * 0.6`) yang berlaku merata untuk kedua orientasi, menggantikan skema dua-konstanta sebelumnya
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix overflow ("RIGHT OVERFLOWED BY 26 PIXELS") pada kotak watermark live (Selesai)
  * User screenshot preview kamera menampilkan garis kuning-hitam khas indikator overflow debug Flutter — root cause: `thumbnailSize` (ukuran thumbnail peta) dihitung independen dari `maxWidth` kotak panel; setelah kalibrasi ukuran dinaikkan (lihat entri kalibrasi di atas), thumbnail sendirian bisa mendekati/melebihi `maxWidth`, membuat `Row` (thumbnail + teks) meluber keluar kotak
  * `lib/camera/live_watermark_overlay.dart`: `thumbnailSize` sekarang dibatasi (`clamp`) supaya tidak pernah lebih dari separuh ruang konten yang tersisa (`maxWidth` dikurangi padding & spacing) — thumbnail otomatis mengecil sendiri kalau ruang sempit, bukan memaksa ukuran penuh lalu meluber
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix kamera restart (layar putih + loading) & kotak watermark sempat membesar saat screenshot (Selesai)
  * Root cause: `didChangeAppLifecycleState` bereaksi ke `AppLifecycleState.inactive` DAN `paused` dengan men-dispose kamera — `inactive` ternyata juga terpicu oleh hal transient seperti pengambilan screenshot sistem (bukan cuma saat app benar-benar di-background), jadi tiap screenshot bikin kamera ikut di-dispose lalu diinisialisasi ulang (terlihat sebagai layar putih + ikon loading sekilas)
  * Efek ikutan: selagi kamera reinit (controller/previewSize sempat null), `_previewScale` jatuh ke nilai fallback `1.0` yang jauh lebih besar dari skala normal, membuat kotak watermark live sempat terlihat membesar sekilas
  * `lib/camera/camera_screen.dart`: `didChangeAppLifecycleState` sekarang HANYA bereaksi ke `AppLifecycleState.paused` (bukan `inactive` lagi) untuk pause/dispose kamera
  * `lib/camera/camera_screen.dart`: `LiveWatermarkOverlay` sekarang cuma dirender saat `cameraReady && controller != null` (sebelumnya selalu dirender, termasuk saat kamera belum/sedang tidak siap) — pertahanan tambahan supaya kotak watermark tidak pernah pakai skala fallback yang salah
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Rename ulang ke "GeoPatriot" + logo aplikasi (background dihapus) + ikon launcher Android (Selesai)
  * User minta nama aplikasi diganti lagi dari "GPS Camera" jadi "GeoPatriot", sekaligus pasang logo dari `referensi/logo geopatriot.jpg` (disarankan pakai file .jpg beresolusi tinggi 2048x2048, bukan .png yang sudah terkompres 512x512, lalu latar belakangnya dihapus)
  * Background logo dihapus pakai flood-fill berbasis KONEKTIVITAS (bukan sekadar color-threshold global) dari sisi-sisi gambar — supaya area putih YANG MEMANG BAGIAN DESAIN (lingkaran dalam di belakang ikon kamera, celah antar bilah shutter) tidak ikut terhapus, cuma latar cream di luar lingkaran badge yang hilang. Diverifikasi dengan render di atas latar magenta kontras — tepi bersih, tidak ada halo/sisa warna latar
  * Lingkaran logo terukur mengisi ~68% lebar kanvas sumbernya — pas dengan "zona aman" adaptive icon Android (~66-72%), jadi dipakai langsung tanpa perlu tambah padding manual
  * File hasil disimpan ke `assets/icon/app_icon.png` (2048x2048, transparan)
  * `pubspec.yaml`: tambah dev dependency `flutter_launcher_icons: ^0.14.3` + konfigurasi (`image_path`, `adaptive_icon_background: "#FFFFFF"`, `adaptive_icon_foreground`), daftarkan asset; dijalankan `dart run flutter_launcher_icons` — berhasil generate ikon biasa (semua densitas mipmap) + adaptive icon Android 8+ (`mipmap-anydpi-v26/ic_launcher.xml` + `drawable-*/ic_launcher_foreground.png`)
  * Rename label: `lib/app.dart` (`GeoPatriotApp`, judul "GeoPatriot"), `lib/main.dart`, `lib/camera/camera_screen.dart` (AppBar), `android/app/src/main/AndroidManifest.xml` (`android:label`)
  * Ikut diseragamkan juga (konsisten dengan penamaan baru, tidak diminta eksplisit tapi jelas relevan): `lib/storage/photo_storage_service.dart` (`galleryAlbumName` → "GeoPatriot", jadi foto tersimpan ke `Pictures/GeoPatriot`), `lib/watermark/models/watermark_configuration.dart` (`appBrandingText` default → "GeoPatriot", teks yang tercetak di watermark foto)
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos, `flutter build apk --debug` BERHASIL (ikon baru & manifest terkonfirmasi tidak merusak build); BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Ganti panel info detail Riwayat dari swipe-up jadi ikon Info di AppBar (Selesai)
  * User laporan: panel metadata yang di-swipe-up dari bawah (fix sebelumnya) menutupi foto mode portrait. Diganti pendekatannya: ikon Info (di samping Share & Hapus di AppBar), detail cuma muncul sebagai modal bottom sheet saat ikon itu diklik
  * `lib/history/history_screen.dart`: hapus `_DetailInfoSheet`/`DraggableScrollableSheet` yang menempel permanen; tambah `_showInfo()` (pakai `showModalBottomSheet`, `showDragHandle: true`) dipicu `IconButton(Icons.info_outline)` di AppBar; foto (`PageView.builder`) sekarang jadi `body` langsung (tidak perlu `Stack` lagi karena tidak ada lagi panel yang menumpuk di atasnya)
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix badge/panel UI meluber & rusak saat diputar landscape (Selesai)
  * Root cause (dikonfirmasi dari screenshot device nyata): `AnimatedRotation`/`Transform.rotate` hanya memutar hasil GAMBAR widget, bukan ukuran kotak layout-nya — untuk widget lebar seperti badge status GPS (`left:16, right:16`, hampir selebar layar), saat diputar 90° hasilnya meluber jauh ke luar area yang dialokasikan `Positioned`, tampil sebagai bar tipis memanjang yang rusak
  * Preview kamera yang terlihat "miring mengikuti device" saat landscape TERNYATA SUDAH BENAR — dibandingkan langsung dengan screenshot aplikasi referensi (`contoh tampilan apps gps map camera saat mode landscape.jpg`), perilaku itu memang standar untuk UI yang dikunci portrait; bukan bug
  * `lib/camera/camera_screen.dart`: `_RotatedControl` ganti `AnimatedRotation` → `RotatedBox` (menukar lebar/tinggi widget SAAT LAYOUT, bukan cuma saat digambar, sehingga kotak pembungkus ikut menyesuaikan dan tidak meluber)
  * `lib/camera/live_watermark_overlay.dart`: panel watermark live juga ganti ke `RotatedBox`
  * Konsekuensi: transisi rotasi jadi langsung/tanpa animasi halus (sebelumnya 200ms), demi mencegah bug meluber — trade-off yang sama dipakai referensi (ikon di aplikasi referensi juga snap langsung, tidak animasi)
  * VERIFIKASI: `flutter analyze` bersih; BELUM diverifikasi ulang di device fisik oleh user
  * BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Rename label ke "GPS Camera" (user-visible saja) (Selesai)
  * `lib/app.dart`: judul `MaterialApp` "Geotag Camera" → "GPS Camera"; class `GeotagCameraApp` → `GpsCameraApp`
  * `lib/main.dart`: sesuaikan pemanggilan ke `GpsCameraApp`
  * `lib/camera/camera_screen.dart`: teks AppBar "Geotag Camera" → "GPS Camera"
  * `android/app/src/main/AndroidManifest.xml`: `android:label="geotag_camera"` → `"GPS Camera"` (nama yang tampil di home screen/recents)
  * SENGAJA TIDAK diubah: `pubspec.yaml` `name: geotag_camera` (identitas package Dart) dan `applicationId`/`namespace` Android — bukan sesuatu yang terlihat user, mengubahnya berisiko Android menganggap aplikasi ini "baru" (data privat lama termasuk index riwayat bisa tidak terbaca). Nama folder index riwayat privat internal (`GeotagCamera/`) juga sengaja tidak diubah dengan alasan sama
- [✓] ✅ Simpan hasil foto (watermark) ke Galeri publik Android, hapus duplikat privat (Selesai)
  * Permintaan user: foto hasil tidak muncul di Galeri HP/File Manager karena tersimpan di folder privat aplikasi; minta dipindah ke folder publik TANPA duplikat (jangan simpan di privat & publik sekaligus)
  * Dicek ke source resmi package `gal` (dependency baru, aktif dipelihara, murni lokal): fungsi simpan gambarnya SELALU pakai folder `Pictures/<album>`, BUKAN `DCIM/<album>` — keterbatasan library. Diputuskan pakai `Pictures/GPS Camera/` (tetap muncul normal di Galeri HP, tujuan user tetap tercapai)
  * `gal` tidak punya fungsi hapus — dipakai `File.delete()` langsung ke path publik yang diprediksi (`/storage/emulated/0/Pictures/GPS Camera/<baseName>.jpg`), sah dilakukan tanpa izin tambahan karena aplikasi selalu punya akses penuh ke media yang dibuatnya sendiri
  * `pubspec.yaml`: tambah dependency `gal: ^2.3.0`
  * `android/app/src/main/AndroidManifest.xml`: tambah `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=29`) dan `android:requestLegacyExternalStorage="true"` (dibutuhkan `gal` khusus Android 10, diabaikan otomatis Android 11+)
  * `lib/storage/photo_storage_service.dart`: `saveProcessed()` sekarang cuma menulis ke file STAGING sementara (folder privat `processed/`, dipakai `ExifWriter` seperti biasa); method baru `publishProcessedToGallery()` menyalin staging file ke galeri lewat `Gal.putImage(path, album: 'GPS Camera')` (didahului `Gal.requestAccess(toAlbum: true)`) lalu menghapus staging file — hasilnya cuma SATU salinan foto processed, di galeri publik; `deleteByBaseName()` diupdate menghapus dari path publik, bukan folder privat lagi
  * `lib/capture/capture_controller.dart`: alur capture tambah satu langkah — `saveProcessed` (staging) → tulis EXIF (tidak berubah, tetap butuh `File` asli) → `publishProcessedToGallery` (baru) — `CaptureSession`/`HistoryEntry` memakai path publik hasil akhir
  * Foto **original** (fitur opsional toggle "Simpan Original") TIDAK diubah — tetap privat seperti sekarang, di luar cakupan keluhan user
  * Sempat gagal build: `camera_android_camerax` juga mendeklarasikan `WRITE_EXTERNAL_STORAGE` dengan `maxSdkVersion` berbeda (28 vs 29 kita) → manifest merger conflict. Fix: tambah `xmlns:tools` + `tools:replace="android:maxSdkVersion"` pada `AndroidManifest.xml`
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos, `flutter build apk --debug` BERHASIL (plugin native `gal` terkonfirmasi terintegrasi bersih); BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Redesign layar detail Riwayat: foto di tengah, metadata di-swipe, navigasi swipe antar-foto (Selesai)
  * Permintaan user: foto landscape nempel di atas layar (minta di tengah); metadata (disebut user "exif", sebenarnya field aplikasi sendiri) selalu tampil penuh padahal sudah ada di watermark (minta disembunyikan/baru muncul saat di-swipe ke atas seperti Galeri Samsung); harus keluar ke grid dulu untuk lihat foto lain (minta bisa swipe kiri/kanan)
  * `lib/history/history_screen.dart`: `_HistoryDetailScreen` dirombak jadi `StatefulWidget` dengan `PageView.builder` (menerima seluruh `entries` + `initialIndex`, bukan satu `entry`) — tiap foto dirender `Center(child: Image.file(..., fit: BoxFit.contain))`, otomatis di tengah untuk portrait maupun landscape
  * Metadata dipindah ke `_DetailInfoSheet` (`DraggableScrollableSheet`, collapsed jadi handle tipis di bawah secara default, bisa ditarik naik) — tidak menutupi foto sampai user swipe up
  * Share/Delete di AppBar mengacu ke foto yang sedang tampil (dilacak `onPageChanged`); hapus foto saat browsing otomatis lanjut ke foto berikutnya/sebelumnya, atau kembali ke grid kalau list jadi kosong
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Multi-select di grid Riwayat: hapus & bagikan banyak foto sekaligus (Selesai)
  * Permintaan user: tekan-tahan untuk pilih banyak foto sekaligus, supaya hapus/share tidak harus buka satu-per-satu
  * `lib/history/history_screen.dart`: `_HistoryScreenState` tambah `Set<String> _selectedBaseNames` — tekan-tahan (`onLongPress`) toggle mode pilih; saat mode pilih aktif, tap biasa jadi toggle pilih/batal (bukan buka detail), thumbnail terpilih dapat overlay centang
  * AppBar kontekstual saat mode pilih: judul "N dipilih", tombol kembali jadi "batal pilih", actions jadi Share & Delete yang beroperasi ke SEMUA item terpilih (`Share.shareXFiles` menerima list, `deleteByBaseName` dipanggil berulang dengan satu dialog konfirmasi)
  * Fitur "copy/move ke folder pilihan" SENGAJA TIDAK dibangun (butuh folder-picker + Storage Access Framework, pekerjaan besar sendiri) — dianggap sudah cukup terwakili kombinasi foto otomatis di Galeri publik (entri sebelumnya) + bulk Share yang bisa ke target seperti app "Files"
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix ruler zoom tidak ikut orientasi landscape + hapus kotak latar ruler (Selesai)
  * User screenshot: saat landscape, ruler sudah pindah jadi horizontal, TAPI angka/tick-nya tetap tegak lurus (tidak ikut miring seperti watermark/ikon lain) — salah pendekatan di iterasi sebelumnya
  * Root cause: `ZoomRulerControl` sebelumnya dibangun dengan DUA layout terpisah (vertikal utk portrait, horizontal-manual utk landscape) dengan asumsi keliru bahwa layar ikut berputar — padahal layar app ini DIKUNCI PORTRAIT PERMANEN (piksel tidak pernah berputar sungguhan), jadi versi "horizontal manual" tadi digambar tegak lurus terhadap piksel yang tetap, bukan terhadap sudut pandang user yang memiringkan device
  * Fix: `ZoomRulerControl` disederhanakan drastis — SELALU dibangun vertikal (satu tata letak kanonis, satu arah gesture `onVerticalDragUpdate`), tidak ada lagi parameter/logika `isLandscape` di dalamnya sama sekali. Orientasi ditangani PEMANGGIL (`camera_screen.dart`) lewat `RotatedBox(quarterTurns: quarterTurns)` — pola yang SAMA persis dengan `_RotatedControl` (ikon lain di layar ini) — `RotatedBox` menukar lebar/tinggi SAAT LAYOUT dan ikut mentransformasi koordinat gesture childnya, jadi ruler otomatis tampil & berfungsi benar di semua orientasi tanpa kode orientasi apa pun di dalam widget ruler itu sendiri
  * Sekaligus: hapus kotak/latar pil semi-transparan di belakang ruler (`_ZoomRulerPainter`) sesuai permintaan user — cukup elemen ruler (garis, tick, label, lingkaran) yang tampil langsung di atas preview, label diberi text-shadow supaya tetap terbaca tanpa latar
  * `test/zoom_scale_test.dart` tidak berubah (menguji `ZoomScale`, logika murni yang tidak disentuh perubahan ini)
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 32/32 lolos, `flutter build apk --debug` BERHASIL; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Ruler-style discrete zoom control, orientation-aware (Selesai)
  * User minta kontrol zoom kamera diganti dari gesture cubit + indikator teks sesaat menjadi ruler bergaya aplikasi kamera modern: tick/mark, titik level zoom yang bisa dipilih, indikator posisi jelas, bisa digeser smooth, tetap sinkron & tidak reset saat orientasi berubah
  * Riset dulu sebelum ngoding (sesuai instruksi user): dicek ke source `camera-0.12.1/lib/src/camera_controller.dart` — API zoom CUMA `getMinZoomLevel()`/`getMaxZoomLevel()`/`setZoomLevel()`, TIDAK ADA getter "zoom saat ini" dan TIDAK ADA daftar stop zoom diskrit milik device (tidak ada info lensa fisik ultra-wide/tele) — jadi level 0.5x/1x/2x/3x/5x di ruler BUKAN hardcode buta, tapi kandidat umum yang DISARING supaya cuma tampil kalau benar-benar ada dalam rentang `[minZoom, maxZoom]` device sungguhan
  * Dicek juga: `DeviceRotationController` (dari sesi sebelumnya) sudah jadi satu-satunya sumber kebenaran orientasi fisik di app ini — `MediaQuery.orientation`/`OrientationBuilder` bawaan Flutter TIDAK BISA dipakai karena UI aplikasi ini sengaja dikunci portrait (tidak akan pernah berubah). Kontrol zoom baru ikut pola yang sama demi konsistensi
  * File baru `lib/camera/zoom_ruler_control.dart`: `ZoomScale` (logika murni tanpa widget — hitung stop yang relevan + konversi dua arah nilai-zoom ⇄ posisi-ruler pakai skala LOGARITMIK supaya jarak antar tanda proporsional visual), `ZoomRulerControl` (widget publik, terima `isLandscape` utk tukar sumbu gesture & layout tick BENAR-BENAR jadi horizontal/vertikal, bukan cuma diputar visual), `_ZoomRulerGestureArea` (drag handling terpisah), `_ZoomRulerPainter` (`CustomPainter` murni rendering) — 3 lapis dipisah sesuai permintaan user ("pisahkan state/logic; gesture handling; ruler rendering")
  * `lib/camera/camera_screen.dart`: hapus indikator teks sesaat + `_showZoomIndicator`/`_zoomIndicatorTimer`; ganti kontrol jadi PERSISTEN (selalu terlihat) lewat `ZoomRulerControl`, posisi berpindah mulus pakai `AnimatedPositioned` (`left`/`top` absolut dihitung manual utk kedua orientasi — SENGAJA tidak menukar properti null `left`↔`right` dsb, supaya interpolasi animasi tidak "meloncat"): kanan-tengah saat portrait, dekat-bawah (di atas baris shutter) saat landscape. Gesture cubit tetap dipertahankan sebagai jalur kedua, sama-sama menulis ke `_currentZoom` yang sama (satu-satunya sumber kebenaran, karena plugin tidak punya getter zoom — sudah diinfokan ke user sebagai keterbatasan plugin, bukan pilihan desain)
  * Orientasi TIDAK PERNAH menyentuh `CameraControllerService`/lifecycle kamera (dikonfirmasi dari arsitektur yang sudah ada — `DeviceRotationController` sepenuhnya independen), jadi zoom level tidak ter-reset dan kamera tidak restart saat rotasi — dijamin arsitektur, tidak perlu kode tambahan
  * Test baru `test/zoom_scale_test.dart` (5 test: filtering stops, konversi dua arah, ujung rentang, nearest-stop)
  * GPS/watermark/EXIF/capture/history/settings TIDAK disentuh sama sekali
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 32/32 lolos, `flutter build apk --debug` BERHASIL; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix kotak watermark live jadi selebar layar (regresi dari pemisahan badge) (Selesai)
  * User screenshot: kotak watermark live tiba-tiba selebar layar penuh (hasil foto tetap benar) setelah badge logo dipisah jadi kotak tersendiri
  * Root cause DITEMUKAN dari analisis constraint Flutter: `lib/camera/live_watermark_overlay.dart` menggabungkan badge+panel lewat `Column(crossAxisAlignment: CrossAxisAlignment.stretch, ...)` — `stretch` memaksa Column mengambil lebar PENUH area yang tersedia (constraint dari `Center` di pemanggil bersifat longgar-tak-terbatas), lalu memaksa `panel` di dalamnya ikut selebar itu juga, MENGABAIKAN `maxWidth: 320` milik `panel` sendiri (aturan Flutter: constraint ketat dari parent selalu menang atas `maxWidth` yang dideklarasikan child)
  * Fix: `crossAxisAlignment.end` (bukan `stretch`) — cuma merapatkan badge ke sisi kanan lebar Column (yang mengikuti lebar `panel`, elemen terlebar), tanpa memaksa ukuran siapa pun; efek tumpang-tindih badge-ke-panel tetap lewat `Transform.translate` (murni visual, tidak mengubah ukuran layout)
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 27/27 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Foto original dipublikasikan ke Galeri publik juga (bukan privat lagi) (Selesai)
  * User minta foto original (kalau setting "Simpan foto original" diaktifkan) ikut disimpan publik, ke `Pictures/GeoPatriot/Original` — sebelumnya privat di storage aplikasi
  * `lib/storage/photo_storage_service.dart`: tambah `originalGalleryAlbumName = 'GeoPatriot/Original'` (album `gal` boleh mengandung "/" untuk sub-folder, diteruskan apa adanya ke MediaStore RELATIVE_PATH); method baru `publishOriginalToGallery()` (pola identik `publishProcessedToGallery`: salin dari staging ke galeri lewat `Gal.putImage`, hapus staging); `saveOriginal()` sekarang murni staging (nama folder privat lama `original/` dipakai ulang cuma sebagai staging, bukan tujuan akhir lagi); `reserveBaseName()`/`deleteByBaseName()` diupdate mengecek/menghapus dari lokasi publik original, bukan privat
  * `lib/capture/capture_controller.dart`: alur capture — `saveOriginal` (staging) tetap dipakai untuk baca bytes watermark seperti biasa; SETELAH itu, kalau setting "Simpan foto original" aktif baru dipanggil `publishOriginalToGallery` (baru dipublikasikan ke galeri), kalau tidak staging langsung dihapus (perilaku lama, tidak berubah)
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 27/27 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Set default pengaturan sesuai preferensi user, kotak logo dipisah jadi lencana tersendiri (Selesai)
  * **Default pengaturan**: user kirim 2 screenshot Pengaturan, minta nilai yang sudah di-set jadi default kode. `lib/watermark/models/watermark_configuration.dart` (`defaultTemplate()`): `showTimezone`/`showAccuracy` false→true, `opacity` 0.55→0.40, `fontSize` 20→14, `thumbnailSize` 140→160. `lib/settings/models/app_settings.dart`: `saveOriginal` default true→false (sengaja menyimpang dari catatan PRD §14 "default ON" — permintaan eksplisit user, foto original tetap bisa diaktifkan manual). Test `settings_service_test.dart` diupdate menyesuaikan default baru
  * **Pertanyaan lokasi foto original**: dijelaskan ke user (bukan perubahan kode) — foto original (kalau diaktifkan) tersimpan di folder PRIVAT aplikasi (`original/`), TERPISAH dari foto processed yang sekarang di Galeri publik `Pictures/GeoPatriot` — bukan folder yang sama
  * **Kotak logo dipisah jadi lencana tersendiri**: user kirim contoh crop lebih jelas — logo+nama harusnya jadi KOTAK TERPISAH yang ditempelkan di sisi panel utama (meniru referensi), bukan baris di dalam panel (yang bikin panel utama jadi ada ruang kosong tak perlu). Revisi dari fix logo sebelumnya
  * `lib/watermark/watermark_renderer.dart`: `render()` kembali ke panel tunggal original (tanpa header di dalam), tambah method baru `_drawBrandBadge()` — gambar kotak lencana TERPISAH (padding sendiri lebih kecil, `_badgePadding=8`) rata kanan terhadap panel utama, ditempel TUMPANG TINDIH `_badgeOverlap=6` px ke sisi panel yang menjauhi tepi gambar terdekat (kalau panel di paruh bawah gambar → lencana ditempel di ATAS panel; kalau di paruh atas → di BAWAH), supaya lencana tidak pernah terpotong keluar batas gambar apa pun posisi watermark yang dipilih
  * `lib/camera/live_watermark_overlay.dart`: pola sama pakai widget Flutter biasa — `badge` (Container terpisah) + `panel` (Container original tanpa header) digabung lewat `Column` dengan `Transform.translate` pada badge untuk efek tumpang-tindih visual (tidak menambah tinggi total, murni pergeseran render), urutan Column (badge duluan atau panel duluan) mengikuti `_isTop(config.position)` supaya arah tempel konsisten dengan hasil akhir
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 27/27 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix label slider transparansi, fix branding "GPS Camera" basi, logo di watermark, zoom kamera sungguhan, sandikan API key (Selesai)
  * **Label slider transparansi**: user laporkan cuma tampil "0"/"1" walau posisi geser & efek transparansi berubah halus. Root cause: `_SliderSetting` di `lib/settings/settings_screen.dart` selalu `.round()` nilai jadi bilangan bulat buat label — untuk slider opacity (rentang 0.1-1.0, kontinu) itu SELALU membulatkan ke 0 atau 1. Fix: tambah `labelFormatter` opsional, slider opacity pakai format persen (`70%`)
  * **Watermark masih "GPS Camera"**: `appBrandingText` tidak pernah bisa diubah dari UI Pengaturan (murni default kode) TAPI ikut tersimpan ke `shared_preferences` — nilai lama dari sebelum rename "GeoPatriot" jadi permanen tersimpan, tidak terpengaruh perubahan default di kode. Fix: `lib/watermark/models/watermark_configuration.dart` — `appBrandingText` berhenti disimpan/dibaca dari JSON, selalu pakai default terbaru dari kode
  * **Logo+nama app di watermark**: restrukturisasi panel jadi ada baris header terpisah (ikon + "GeoPatriot", rata kanan) di ATAS baris info lokasi, meniru posisi logo aplikasi referensi — sebelumnya cuma baris teks biasa paling bawah. `lib/watermark/watermark_renderer.dart`: `render()` terima `appIconBytes` opsional (supaya renderer tetap "pure", tidak load asset sendiri); `lib/capture/capture_controller.dart`: muat `assets/icon/app_icon.png` sekali lewat `rootBundle` lalu diteruskan; `lib/camera/live_watermark_overlay.dart`: `headerRow` (Image.asset + Text) di atas panel, live sama persis dengan hasil akhir secara struktur
  * **Zoom kamera sungguhan**: dicek ke source `camera: ^0.12.1` — `getMinZoomLevel()`/`getMaxZoomLevel()`/`setZoomLevel()` adalah API resmi zoom hardware/optik (BUKAN crop digital). `lib/camera/camera_controller_service.dart`: expose 3 method itu; `lib/camera/camera_screen.dart`: gesture cubit (`onScaleStart`/`onScaleUpdate`) di atas preview mengubah zoom live, di-clamp ke rentang kamera, plus indikator "2.0x" sesaat yang hilang otomatis
  * **Sandikan API key untuk rilis publik**: didiskusikan dulu ke user (jatah 5.000/hari dipakai bersama semua user APK, key ditanam APAPUN bentuknya pada dasarnya bisa diambil orang yang niat bongkar — bukan celah khusus). User pilih tetap ditanam tapi disamarkan. `lib/core/config/api_keys.dart`: ganti dari `String.fromEnvironment('LOCATIONIQ_API_KEY')` polos jadi didekode dari `LOCATIONIQ_API_KEY_ENCODED` (XOR + base64) saat runtime — TIDAK diklaim aman total, cuma menaikkan kesulitan dari "kelihatan langsung di `strings`" jadi "perlu decompile aktif". File baru `tool/encode_api_key.dart` (script CLI buat sandikan key sebelum build rilis, algoritma harus identik dengan decoder). `README.md`: instruksi `--dart-define` diupdate ke `LOCATIONIQ_API_KEY_ENCODED`, tambah bagian "Rilis APK publik"
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 27/27 lolos, `flutter build apk --debug` dengan `--dart-define=LOCATIONIQ_API_KEY_ENCODED=...` BERHASIL (alur encode/decode & semua perubahan terkonfirmasi terintegrasi bersih); BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix bug setting "Zoom Peta" tidak berpengaruh (Selesai)
  * User ubah-ubah "Zoom Peta" di Pengaturan tapi thumbnail peta watermark tidak pernah berubah, sempat minta setting-nya dihapus kalau memang tidak berfungsi
  * Root cause DITEMUKAN (bukan dugaan): `lib/map/cached_map_thumbnail_provider.dart` men-cache thumbnail lewat `CoordinateCache` yang key-nya CUMA dari koordinat (lihat `CoordinateCache.keyFor`) — `zoom` tidak ikut jadi bagian key. Karena thumbnail utk lokasi saat ini biasanya sudah ke-cache duluan (begitu GPS dapat fix, sebelum user sempat ubah setting), mengubah zoom tanpa pindah lokasi selalu kena cache hit dari zoom lama — request baru ke LocationIQ dengan zoom baru tidak pernah terkirim. Fiturnya sebenarnya sudah benar di sisi pengiriman request, cuma "ketutup" cache
  * Kesimpulan: setting TIDAK dihapus — cuma bug cache kecil, bukan fitur salah desain
  * `lib/core/cache/coordinate_cache.dart`: `keyFor`/`get`/`set` tambah parameter opsional `extra` (String) yang ikut digabung ke cache key — generik, bisa dipakai cache lain kalau perlu key tambahan serupa nanti
  * `lib/map/cached_map_thumbnail_provider.dart`: sertakan `zoom` sebagai `extra` (`'zoom=$zoom'`) saat get/set cache — kombinasi lokasi+zoom berbeda sekarang dianggap entri cache berbeda. `CachedGeocodingProvider` tidak disentuh (tidak pakai `extra`, perilaku tetap sama)
  * Test baru: `test/coordinate_cache_test.dart` — "koordinat sama tapi extra berbeda dianggap entri cache berbeda"
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 27/27 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Koreksi: hapus cincin tebal ikon, revert clearance watermark, naikkan jarak shutter-ke-bar sistem (Selesai)
  * User konfirmasi ikon sudah bagus tapi minta cincin/lingkaran tebal navy di bagian luar logo dihapus supaya lebih bersih
  * `assets/icon/app_icon.png`: cincin navy di-mask keluar (crop ke lingkaran radius pas di batas dalam cincin, dicek dulu posisi & warnanya lewat scan pixel horizontal), lalu di-crop+scale ulang supaya tetap mengisi ~96% kanvas seperti sebelumnya — dijalankan ulang `dart run flutter_launcher_icons`
  * User klarifikasi: perubahan `_bottomControlsClearance` sebelumnya SALAH SASARAN — yang dimaksud "panel di bawah tombol shutter" adalah bar navigasi sistem Android, bukan kotak watermark live di atas tombol. `lib/camera/live_watermark_overlay.dart`: `_bottomControlsClearance` di-revert 170 → 112 (ke nilai sebelum perubahan salah paham)
  * `lib/camera/camera_screen.dart`: jarak baris tombol shutter/switch-kamera dari tepi bawah layar dinaikkan 24 → 48, supaya tidak terlalu mepet dengan bar navigasi sistem
  * Lebar panel info modal masih dilaporkan sama (belum berubah) — sudah dicek ulang kodenya (`constraints: BoxConstraints(maxWidth: double.infinity)` di `history_screen.dart`, dari fix ronde sebelumnya), fix-nya SUDAH ADA dan benar sesuai source Flutter (`bottom_sheet.dart`) — kemungkinan besar user masih menguji build/APK lama sebelum fix itu terpasang; TIDAK ADA perubahan kode tambahan di ronde ini untuk ini, menunggu konfirmasi user setelah install ulang APK terbaru
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user
- [✓] ✅ Fix ikon aplikasi kecil di home screen, jarak panel-shutter, tema gelap, lebar panel info (Selesai)
  * User screenshot home screen: ikon GeoPatriot terlihat jauh lebih kecil dari ikon app lain (ada "outer putih" ekstra) — root cause: logo sumber sengaja dibuat dengan margin lebar (lingkaran cuma ~68% lebar kanvas, buat "zona aman" adaptive icon), sementara app lain (Zoom, Canva, dll) desain ikonnya memang mengisi penuh kanvas
  * `assets/icon/app_icon.png`: di-crop ketat ke bounding box lingkaran lalu diskalakan ulang supaya lingkaran mengisi ~96% kanvas (dicek dulu render di atas latar magenta, hasilnya rapi tanpa terpotong) — dijalankan ulang `dart run flutter_launcher_icons` untuk regenerate semua ikon Android
  * Kotak watermark live masih bersinggungan dengan tombol shutter di device nyata walau sudah diberi jarak sebelumnya — `lib/camera/live_watermark_overlay.dart`: `_bottomControlsClearance` dinaikkan dari 112 → 170
  * Tema gelap: `lib/core/theme/app_theme.dart` tambah `AppTheme.dark()`; `lib/app.dart` tambah `darkTheme: AppTheme.dark()` + `themeMode: ThemeMode.system` — otomatis ikut mode gelap/terang sistem HP (termasuk panel info detail foto yang sebelumnya selalu putih)
  * Panel info detail foto tampak seperti kartu melayang dengan margin kiri-kanan, bukan penuh selebar layar — root cause DIKONFIRMASI dari baca source Flutter (`bottom_sheet.dart`): Material 3 membatasi lebar bottom sheet default maks 640dp, kena di device dengan logical width >640dp.
  * `lib/history/history_screen.dart`: `showModalBottomSheet` tambah `constraints: BoxConstraints(maxWidth: double.infinity)` supaya selalu selebar layar
  * VERIFIKASI: `flutter analyze` bersih, `flutter test` 26/26 lolos; BELUM diverifikasi ulang di device fisik oleh user

## Fase Redesign UI/UX Komprehensif — Immersive HUD, Anti-Lag Isolate, & Polish
- [✓] ✅ Redesign UI/UX Menyeluruh: Edge-to-edge HUD, Background Watermarking, Live Settings Preview, Pinch-to-Zoom (Selesai)
  * **Viewfinder Edge-to-Edge & Floating HUD**: Menghapus `AppBar` konvensional di `CameraScreen`. Menambahkan top floating HUD berisi `GpsStatusPill` (indikator real-time dengan kode warna akurasi dan modal info sensor) dan tombol `Settings` mengambang.
  * **Ergonomi Bottom Bar**: Membuat `CameraBottomBar` yang menata tiga kontrol thumb-zone: akses galeri foto terakhir cepat (kiri), tombol shutter besar 76dp beranimasi tekan (tengah), dan switch kamera (kanan). Banner tersimpan dibuat interaktif (tappable langsung ke detail foto).
  * **Anti-Lag Background Isolate**: Pemrosesan CPU berat `WatermarkRenderer.render` dipindahkan ke background worker isolate menggunakan `compute()` di `CaptureController`, menghilangkan jank/freeze thread UI saat memotret foto beresolusi tinggi.
  * **Graceful GPS Timeout**: `LocationService.freezeSnapshot` dan `WatermarkRenderer` diperbarui agar saat pencarian satelit timeout atau koordinat belum terkunci, aplikasi tidak memblokir capture melainkan tetap mengambil foto dengan fallback yang aman.
  * **Progressive Disclosure & Live Preview di Settings**: Menambahkan kartu pratinjau live watermark reaktif di bagian atas `SettingsScreen`, memperbaiki status aktif template chip (`selected: activeTemplate == template`), input catatan lapangan tersinkronisasi `onChanged`, pengelompokan Card terstruktur, dan tombol "Kembalikan ke Setelan Awal".
  * **Galeri & Detail Foto**: Menambahkan `InteractiveViewer` pada `HistoryDetailScreen` (mendukung pinch-to-zoom hingga 4x), `errorBuilder` fallback pada thumbnail dan foto detail jika file terhapus di luar aplikasi, tombol seleksi "Pilih" eksplisit di AppBar, judul dinamis indeks foto (`Foto X dari Y`), penyesuaian dialog konfirmasi hapus ramah pengguna, dan tombol "Salin Koordinat" di info modal.
  * **Design Tokens & Theme**: Menambahkan `CameraTokens` di `lib/core/theme/camera_tokens.dart` dan menyelaraskan tema gelap di `lib/core/theme/app_theme.dart`.
  * **File Baru**: `lib/core/theme/camera_tokens.dart`, `lib/camera/widgets/gps_status_pill.dart`, `lib/camera/widgets/camera_bottom_bar.dart`, `test/settings_controller_test.dart`.
  * **File Diubah**: `lib/core/theme/app_theme.dart`, `lib/capture/capture_controller.dart`, `lib/location/location_service.dart`, `lib/watermark/watermark_renderer.dart`, `lib/settings/settings_controller.dart`, `lib/settings/settings_screen.dart`, `lib/history/history_screen.dart`, `lib/camera/camera_screen.dart`.
  * VERIFIKASI: `flutter analyze` 0 issues (bersih), `flutter test` 34/34 tests lolos.

## Fase Perbaikan Bug Landscape Layout — In-Place Icon Rotation & Zero Overlap
- [✓] ✅ Fix Bug Layout Kamera Landscape: Penumpukan Bottom Bar & Zoom Ruler (Selesai)
  * **Root Cause Ditemukan**: `CameraBottomBar` sebelumnya dibungkus oleh `_RotatedControl` (`RotatedBox`) di `lib/camera/camera_screen.dart`. Ketika device dimiringkan ke mode landscape (`quarterTurns = 1` atau `3`), `RotatedBox` memutar kontainer baris selebar layar penuh tersebut sebesar 90°, mengubah baris horizontal menjadi kolom vertikal di tengah layar yang menabrak dan menimpa penggaris zoom (`ZoomRulerControl`) membentuk palang silang (+).
  * **In-Place Icon Rotation**: Menghapus pembungkus `_RotatedControl` dari `CameraBottomBar` di `camera_screen.dart` sehingga baris kontrol bawah tetap berlabuh stabil di sisi fisik bawah layar (`bottom: 32`). Menambahkan parameter `quarterTurns` ke `CameraBottomBar` dan merotasikan isi ikon/gambar di tempat (*in-place*) pada `_QuickGalleryButton` (thumbnail galeri) dan `IconButton` (ganti kamera).
  * **Zero Collision**: Dengan `CameraBottomBar` pada `bottom: 32` (tinggi 76dp) dan `ZoomRulerControl` pada `bottom: 140` (tinggi 32dp), tercipta jarak klirens bersih sebesar 32dp di antara keduanya saat mode landscape, menghilangkan tumpang tindih secara permanen.
  * **File Diubah**: `lib/camera/camera_screen.dart`, `lib/camera/widgets/camera_bottom_bar.dart`.
  * **File Baru**: `test/camera_bottom_bar_test.dart` (pengujian widget untuk kestabilan baris horizontal di portrait & landscape, rotasi in-place, disabled state saat busy, dan single-camera layout).
  * **VERIFIKASI**: `flutter analyze` 0 issues (bersih), `flutter test` 38/38 tests lolos (100% pass).

## Fase Perbaikan Bug Landscape Capture — Viewfinder AspectRatio Glitch
- [✓] ✅ Fix Bug Viewfinder Menyusut & Berputar Saat Capture Landscape (Selesai)
  * **Root Cause Ditemukan**: `CameraPreview` bawaan package `camera` mengamati `controller.value.lockedCaptureOrientation`. Ketika `CameraController.lockCaptureOrientation(landscape)` dipanggil sesaat sebelum `takePicture()` agar foto JPEG tersimpan dengan orientasi EXIF yang benar, `CameraPreview` internal mengubah rasio aspek menjadi 16:9 dan memutar tekstur dengan `RotatedBox(quarterTurns: 3)`. Karena jendela aplikasi dikunci ke portrait (`DeviceOrientation.portraitUp`), preview kamera tiba-tiba menyusut menjadi strip mendatar di tengah layar (letterboxing) dengan bar hitam besar di atas/bawah dan memutar gambar secara mendadak selama ~1 detik proses capture.
  * **Implementasi FixedCameraPreview**: Membuat widget `FixedCameraPreview` di `lib/camera/widgets/fixed_camera_preview.dart` yang mengunci rasio aspek vertikal `1 / value.aspectRatio` secara stabil dan langsung menampilkan `controller.buildPreview()` tanpa rotasi buatan. Viewfinder tetap kokoh, mulus, dan tidak berkedip saat memotret, sementara foto hasil capture tetap tersimpan dengan orientasi landscape yang benar.
  * **File Baru**: `lib/camera/widgets/fixed_camera_preview.dart`.
  * **File Diubah**: `lib/camera/camera_screen.dart`.
  * **VERIFIKASI**: `flutter analyze` 0 issues (bersih), `flutter test` 38/38 tests lolos (100% pass).

## Fase Perbaikan Bug Capture & Lifecycle Preview — Isolate Locale & Disposed Safety
- [✓] ✅ Fix Gagal Mengambil Foto di Samsung S24+ & Disposed CameraController Exception (Selesai)
  * **Root Cause 1 Ditemukan (Gagal Ambil Foto)**: `_renderWatermarkInIsolate` dijalankan di Dart isolate terpisah via `compute()`. Paket `intl` (`DateFormat('dd MMMM yyyy HH:mm:ss', 'id_ID')`) membutuhkan inisialisasi lokal. Inisialisasi `initializeDateFormatting('id_ID')` sebelumnya hanya dijalankan di `main()` pada root isolate. Karena memori antar isolate di Dart tidak terbagi (shared memory), pemanggilan `DateFormat` di dalam background isolate memicu `LocaleDataException: Locale data has not been initialized, call initializeDateFormatting(<locale>)`. Exception ini tertangkap oleh blok `catch (_)` generik di `CaptureController.capture()`, menyebabkan status capture selalu gagal dengan pesan "Gagal mengambil foto. Coba lagi."
  * **Solusi Root Cause 1**:
    1. Mengubah `_renderWatermarkInIsolate` menjadi `async` dan menambahkan `await initializeDateFormatting('id_ID');` sebelum eksekusi rendering watermark di background isolate.
    2. Menghapus silent error swallow pada `CaptureController.capture()` dengan mencetak log detail error dan stack trace (`debugPrint('Gagal mengambil foto: $e\n$stackTrace')`).
  * **Root Cause 2 Ditemukan (Disposed CameraController)**: Saat transisi siklus hidup aplikasi (seperti screenshot sistem, menarik notification shade, atau meminimalkan aplikasi), `FixedCameraPreview` mencoba memanggil `controller.buildPreview()`. Jika controller berada dalam proses dispose/pause atau belum selesai resume, plugin `camera` melempar `CameraException: Disposed CameraController, buildPreview() was called on a disposed CameraController`.
  * **Solusi Root Cause 2**:
    1. Membungkus pemanggilan `controller.buildPreview()` di `FixedCameraPreview` dengan `try-catch` defensif dan fallback ke `SizedBox.shrink()` jika controller sedang dalam transisi dispose.
    2. Memperbaiki sinkronisasi lifecycle di `lib/camera/camera_screen.dart:didChangeAppLifecycleState`: saat `paused`, segera ubah `_cameraReady = false` agar UI unmount preview sebelum controller dipause; saat `resumed`, tunggu `_cameraService.resume()` tuntas sebelum menyetel `_cameraReady = true`.
  * **File Diubah**: `lib/capture/capture_controller.dart`, `lib/camera/widgets/fixed_camera_preview.dart`, `lib/camera/camera_screen.dart`.
  * **VERIFIKASI**: `flutter analyze` 0 issues (bersih), `flutter test` 38/38 tests lolos (100% pass).


## Fase Peningkatan Resolusi Foto & Kecepatan Proses — Preset max + Kompositor Native
- [✓] ✅ Resolusi foto 2 MP → 12 MP, bug pita hijau 4K, dan percepatan proses (Selesai, 12 Okt 2026)
  * **Masalah 1 (file kecil)**: `ResolutionPreset.veryHigh` = 1920x1080 ≈ 2 MP dan dipakai preview + `takePicture()`. Bukan masalah kompresi. FHD tidak mungkin 8 MP; 8 MP pada 16:9 = 4K.
  * **Masalah 2 (garis hijau + blur warna)**: `ultraHigh` (3840x2160) menghasilkan JPEG kamera cacat di Galaxy S25+: pita hijau 32 px di tepi sensor-bawah dan chroma bergeser. Foto original tanpa watermark juga cacat, jadi sumbernya HAL/CameraX, bukan dekoder `image`.
  * **Solusi 1+2**: `camera_controller_service.dart` memakai `ResolutionPreset.max` (4:3, ±12 MP). Bersih dan file 2,x MB.
  * **Masalah 3 (proses lama)**: dekode + `bakeOrientation` + encode JPEG 12 MP di Dart `image` (single-thread), ditambah geocode+peta yang baru dimulai setelah foto selesai.
  * **Solusi 3**:
    1. `MainActivity.kt`: `MethodChannel(geopatriot/compositor)` dengan `imageSize` dan `composite` (BitmapFactory + Canvas, putar sesuai EXIF, JPEG q90, thread latar). Wrapper `lib/watermark/native_compositor.dart`.
    2. `watermark_renderer.dart`: dipecah `_layout` + `_paint`; `renderOverlay()` menghasilkan panel RGBA kecil (PNG) + posisi; `render()` tetap untuk fallback/tes. Tampilan identik.
    3. `watermark_publisher.dart`: `_renderToStaging` (native dulu, fallback Dart), `fetchOnlineData()` + parameter `onlineData`, log `[perf]` per tahap.
    4. `capture_controller.dart`: geocode+peta dimulai paralel dengan `takePicture()`. `photo_storage_service.dart`: `saveOriginal(move: true)` (rename) dan `processedStagingFile()`.
  * **File Diubah**: `lib/camera/camera_controller_service.dart`, `lib/capture/capture_controller.dart`, `lib/capture/watermark_publisher.dart`, `lib/storage/photo_storage_service.dart`, `lib/watermark/watermark_renderer.dart`, `lib/watermark/native_compositor.dart` (baru), `android/.../MainActivity.kt`, `test/watermark_renderer_test.dart`.
  * **VERIFIKASI**: `flutter analyze` 0 issues, `flutter test` 62/62 lolos (tes baru overlay = render penuh). Diuji di Galaxy S25+ (release, wireless debugging): foto 12 MP tanpa pita hijau dan proses cepat (dikonfirmasi user).

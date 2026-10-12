- [x] perbaiki live watermark yg offside ketika mode portrait yg satunya (atas-bawah). ("D:\Aplikasi\GeoPatriot\referensi\bug rotasi ke atas.jpg")
- [x] tambahkan menu manual input koordinat yg nantinya bakal di-reverse geocoding + thumbnail petanya.
- [x] tambahkan menu input manual timestamp-nya.
- [x] tambahkan fitur untuk menambahkan watermark secara manual dari foto yg ada di galeri.
- [x] kenapa fitur galeri di aplikasinya ketika sebuah foto di galeri tersebut dihapus melalui galeri bawaan HP, terdapat jejaknya di galeri aplikasi. Susah jelaskannya, aku kasih ss-nya saja. "D:\Aplikasi\GeoPatriot\referensi\tampak galeri apps.jpg" dan "D:\Aplikasi\GeoPatriot\referensi\tampilan foto yg dihapus.jpg".
- [x] Switcher camera depannya sepertinya bermasalah. Coba cek deh. Tiap kali tekan tombol switcher ke kamera depan, layar selalu black gitu dan kayak hang. Ada juga muncul error seperti berikut: "D:\Aplikasi\GeoPatriot\referensi\Screenshot_20261006_060704.jpg". Bahkan ketika kamera depan berhasil diakses, ketika kembali ke kamera belakang juga layar jadi black dan kayak hang gitu. Coba dicek lagi ya.
- [x] Oh iya, untuk referensi pengerjaan tambahan fiturnya bisa coba dicek ke folder "D:\Aplikasi\GeoPatriot Web" ini ya. Itu versi web dari aplikasi ini. (dipakai sebagai acuan parser koordinat dan alur impor foto)
- [x] (12 Okt 2026) Kenapa file foto hanya ratusan KB / 2 MP padahal kamera HP berMP besar? → resolusi dinaikkan ke 12 MP.
- [x] (12 Okt 2026) Hasil foto ada garis hijau dan blur warna (`referensi/bug hasil foto.jpg`, `bug hasil foto 2.jpg`).
- [x] (12 Okt 2026) Proses setelah shutter terlalu lama dengan preset tetap → komposit watermark dipindah ke native.
- [x] (12 Okt 2026) Mode Survei untuk sensus: nama file otomatis `objek-kategori-lokasi.jpg`, kategori dokumen tanpa watermark dan live watermark disembunyikan.

---

# Catatan pengerjaan (6 Okt 2026)

Semua item di atas sudah dikerjakan, di-commit per item, lolos `flutter analyze` dan `flutter test` (54 tes). Yang sudah diuji langsung di HP (Samsung, release build via wireless debugging): switch kamera, zoom awal 1x, pemasangan APK. Sisanya (lihat "Perlu diuji di HP") belum dikonfirmasi di perangkat.

## 1. Optimasi ukuran APK dan data (`aacdb44`)
- Masalah: APK 58 MB, terinstall 189 MB, data 98 MB.
- Penyebab: APK memuat 3 ABI sekaligus (arm64, armeabi-v7a, x86_64); R8/minify tidak aktif; file JPEG sementara hasil `takePicture` tidak pernah dihapus; thumbnail mendekode foto penuh.
- Perbaikan: aktifkan `isMinifyEnabled` + `isShrinkResources` (`android/app/build.gradle.kts`, `proguard-rules.pro`); hapus file sementara kamera dan bersihkan staging saat gagal; `PhotoStorageService.cleanTemporaryFiles()` dipanggil saat startup; `cacheWidth` pada `Image.file`.
- Hasil: APK arm64 20,5 MB (build dengan `--split-per-abi`).

## 2. Switch kamera depan/belakang (`91ab4c2`)
- Penyebab: controller lama di-dispose saat widget masih memakainya ("CameraController was used after being disposed"), dua controller hidup bersamaan sehingga kamera depan gagal/hitam, tanpa `try/catch`.
- Perbaikan: preview dicabut dulu, controller lama dilepas sebelum yang baru dibuka (`camera_controller_service.dart`), guard tap ganda, fallback ke kamera sebelumnya bila gagal, zoom di-query ulang.

## 3. Riwayat sinkron dengan galeri bawaan (`edb3eac`)
- Penyebab: riwayat memakai index JSON sendiri, tidak tahu file dihapus dari luar.
- Perbaikan: `PhotoHistoryService.pruneMissing()` membuang entri yang filenya hilang; dipanggil saat Riwayat dibuka dan saat app kembali dari background (juga di layar detail).

## 4. Live watermark offside saat portrait terbalik (`6d3c6ee`)
- Penyebab: overlay menempel ke tepi layar penuh, bukan frame preview; hanya sisi bawah yang punya clearance.
- Perbaikan: overlay ditambatkan ke rect frame preview dengan clearance HUD atas dan tombol bawah yang dihitung otomatis (`camera_screen.dart:_buildLiveWatermark`, `edge_anchored_rotated.dart`).

## 5. Input manual koordinat + timestamp (`ef794e7`)
- Ikon di HUD kamera membuka sheet (`manual_override_sheet.dart`): koordinat "lat, lon" (parser `parseCoordinatePair`, validasi ±90/±180), tanggal, jam. Model `ManualOverride` (`capture/manual_override.dart`), hanya di memori, reset saat app ditutup. Dipakai live watermark, capture, EXIF; alamat dan peta di-geocode dari koordinat manual. Tanpa penanda "Manual" (keputusan user).

## 6. Tambah watermark dari foto galeri (`555432e`, `da2453e`)
- Pipeline render+simpan+riwayat diekstrak dari `CaptureController` ke `WatermarkPublisher` (dipakai bersama kamera dan impor). `PhotoImportService` membaca EXIF (`native_exif`). Dependensi baru: `image_picker`.
- Alur bersama `importFromGallery` (`history/gallery_import_flow.dart`); tombol "Tambah foto" berlabel di Riwayat (FAB) dan ikon di HUD kamera. Foto tanpa koordinat dilewati dan dilaporkan.

## 7. API key LocationIQ tidak terbaca / 401 (`69e2a24`)
- Penyebab: key di `GeoPatriot Web/.env.local` ditulis `KEY= pk.xxx` (spasi di depan); spasi ikut tersandi, LocationIQ membalas "Invalid key". Aplikasi mobile tidak memakai `.env`; key dimasukkan lewat `--dart-define=LOCATIONIQ_API_KEY_ENCODED=<hasil tool/encode_api_key.dart>`.
- Perbaikan: `_decodeApiKey` memakai `.trim()`.

## 8. Zoom awal kamera 1x (`45d1c37`)
- Sebelumnya zoom awal = minZoom (ultra-wide 0.6x) hanya di state UI, tidak diterapkan ke kamera. Kini diset 1x (`defaultZoomFor`) saat kamera dibuka, setelah switch kamera, dan setelah resume.

## 9. Audit bug dan perbaikannya (`b39f0dd`, `a41d781`, `7346bdd`)
- Resolusi foto hanya 720×1280 (0,9 MP) karena `ResolutionPreset.high` → naik ke `veryHigh` (1080p).
- Impor galeri menimpa koordinat/waktu semua foto dengan EXIF foto pertama → prefill hanya untuk 1 foto.
- Peta tidak valid menggagalkan seluruh foto → dilewati.
- Kamera gagal dibuka/resume/switch berujung spinner abadi → layar error + tombol "Coba lagi".
- Koordinat 0,0 ikut ke EXIF dan riwayat saat GPS tanpa fix → `LocationSnapshot.isPlaceholder`; `HistoryEntry.latitude/longitude` kini nullable.
- Riwayat rawan rusak → penulisan atomik (`.tmp` + rename), antrean serial, cadangan `.bak` saat JSON rusak, `pruneMissing` aman bila folder Pictures tidak terbaca.
- Salinan sementara `image_picker` tidak dihapus → `deletePickerCopy` + sapuan saat startup.
- GPS tetap menyala di background → dihentikan saat `paused`.
- Offline: geocoding dan peta paralel dengan timeout 5 dtk (sebelumnya berurutan ±16 dtk); timeout fix GPS 10 dtk; lokasi terakhir hanya dipakai bila ≤ 2 menit; pesan jelas + retry sekali bila gagal simpan ke galeri.
- Tidak dikerjakan penuh: foto yang sudah dirender tapi gagal disimpan ke galeri belum bisa dipulihkan (butuh layar coba-ulang).

## 10. Ukuran kotak watermark setelah resolusi naik (`5f25e22`)
- Penyebab: ukuran watermark piksel absolut (acuan 720 px) dan skala live bergantung `previewSize.width`; resolusi 1080p membuat keduanya ±0,67×.
- Perbaikan: ukuran diskalakan dengan `watermarkScaleFor` = sisi pendek foto / 720 (`watermark_configuration.dart`, `watermark_renderer.dart`); live preview memakai `lebar frame / 720` (`_liveScaleCalibration = 1.0`). Keterbatasan: font bitmap hanya 14/24/48 sehingga teks hasil bisa ±14% lebih besar dari live.

## 11. Zoom detail foto di Riwayat (`cf94c28`)
- Foto ter-crop saat dicubit: `InteractiveViewer` di dalam `Center` menyusut ke kotak gambar dan memotong → kini mengisi seluruh halaman.
- Satu jari malah pindah foto: `PageView` dikunci saat foto di-zoom; tambah double-tap (1× ↔ 2,5×); `cacheWidth` 2400.

## 12. Resolusi foto 2 MP → 12 MP (12 Okt 2026)
- Penyebab file kecil: `ResolutionPreset.veryHigh` = 1920×1080 ≈ 2 MP, dan preset yang sama dipakai preview DAN `takePicture()`. Kompresi (JPEG quality 90) bukan penyebab. "FHD" memang 2 MP menurut definisinya; 8 MP pada 16:9 berarti 3840×2160 (4K), jadi tidak ada "FHD 8 MP".
- Percobaan 1: `ultraHigh` (3840×2160, ~8 MP) → file ±1,5 MB tetapi bermasalah (butir 13).
- Perbaikan akhir: `ResolutionPreset.max` di `camera_controller_service.dart` (`_openCamera`). Di Galaxy S25+ (SM-S936B) hasilnya 4:3 ±12 MP, file 2,x MB. Preview jadi 4:3; UI sudah memakai `controller.value.aspectRatio` sehingga watermark live tetap proporsional.
- Batasan: plugin `camera` hanya punya preset diskret (720p/1080p/2160p/max), tidak ada `ResolutionSelector` CameraX, jadi 4:3 ~8 MP persis tidak bisa dipilih.

## 13. Pita hijau 32 px + blur warna pada foto 4K (12 Okt 2026)
- Gejala (`referensi/bug hasil foto*.jpg`): pita hijau tepat 32 piksel di tepi sensor-bawah (landscape baris 2128-2159 dari 2160; portrait kolom 0-31 setelah rotasi EXIF), warna ±RGB(0,217,1) = data YUV nol; bercak biru/cyan bergeser dari tepi objek (plane chroma tidak sejajar dengan Y) sementara luminans normal.
- Diagnosa: foto ORIGINAL (tanpa watermark) di galeri juga cacat → JPEG dari kamera sudah rusak pada jalur 3840×2160 (16:9 dari sensor 4:3), bukan dekoder `image` / renderer. Pola 32 px (= 2 MCU JPEG 4:2:0) + chroma bergeser = tanda error stride/padding YUV di sisi HAL/CameraX Samsung. Pada 1080p tidak muncul.
- Perbaikan: hindari `ultraHigh`, pakai `max` (butir 12). Terkonfirmasi bersih di HP. Cadangan bila `max` bermasalah di perangkat lain: kembali ke `veryHigh` (bersih, 2 MP).

## 14. Proses setelah shutter lama pada 12 MP (12 Okt 2026)
- Penyebab: dekode + `bakeOrientation` + encode ulang JPEG 12 MP oleh paket Dart `image` (pure Dart, satu thread) di `watermark_renderer.dart`. Menggambar panel/teks sendiri murah; tanpa watermark foto cukup disalin. `compute()` sudah mencegah UI freeze tetapi tidak mempercepat. Urutan lama juga serial: geocode+peta (sampai 5 dtk) baru dimulai SETELAH foto selesai.
- Perbaikan (preset tetap `max`):
  - Kompositor native: `MainActivity.kt` menambah `MethodChannel('geopatriot/compositor')` (`imageSize`, `composite`) memakai `BitmapFactory` + `Canvas`: putar sesuai EXIF, tempel overlay PNG, simpan JPEG quality 90 di thread latar. Wrapper Dart: `lib/watermark/native_compositor.dart`.
  - `WatermarkRenderer` dipecah menjadi `_layout` (perhitungan, memakai `watermarkScaleFor`) + `_paint`. `render()` (jalur Dart penuh, dipakai tes dan fallback) dan `renderOverlay()` (hanya panel + lencana ke kanvas RGBA kecil, PNG) memakai layout yang sama sehingga tampilan identik; ada tes yang membandingkan keduanya.
  - `WatermarkPublisher._renderToStaging`: coba native dulu; bila `imageSize`/`composite` gagal atau channel tidak ada (tes unit) jatuh ke jalur Dart lama.
  - `WatermarkPublisher.fetchOnlineData()` + parameter `onlineData` di `publish()`: geocode+peta dimulai paralel dengan `takePicture()` di `CaptureController.capture()` (impor galeri tetap memanggilnya di dalam `publish`).
  - `PhotoStorageService.saveOriginal(move: true)` memakai rename (fallback salin) untuk file sementara kamera; impor galeri tetap menyalin. Tambah `processedStagingFile()`.
- Log waktu per tahap tetap ada: `adb logcat -s flutter | grep perf` → `[perf] capture: takePicture`, `[perf] publish: geocode+peta (tunggu)`, `render watermark`, `tulis EXIF`, `publikasi ke galeri`, `capture: publish total`.
- Hasil: dikonfirmasi user "sudah cepat" di HP. `flutter analyze` bersih, 62 tes lolos (tes baru: overlay ditempel = render penuh pada 1080×1920, 1920×1080, 4000×3000).
- Catatan: hasil native tidak membawa EXIF kamera (sama seperti jalur Dart); GPS/waktu tetap ditulis `ExifWriter`. Bitmap 12 MP ≈ 48 MB heap (+ salinan saat dirotasi); bila OOM, publisher otomatis jatuh ke jalur Dart.

## 15. Mode Survei: nama file otomatis + kategori tanpa watermark (12 Okt 2026)
- Kebutuhan: surveyor sensus memotret lahan, rumah, dan dokumen (KK, KTP, SHM) per rumah penduduk; nama file harus seragam (`budi-lahan-sp3.jpg`) dan foto dokumen tidak boleh tertutup watermark.
- Keputusan desain (hasil diskusi): lokasi SP diisi jarang dan tersimpan; objek (rumah/penduduk) diketik tiap rumah dan SENGAJA tidak dipersist; kode opsional untuk nama kembar; kategori bisa diatur (bawaan Lahan, Rumah ber-watermark; KK, KTP, SHM, Dokumen lain bersih); bentrok nama pertama polos lalu `-2`, `-3`; tombol manual "Objek berikutnya" mengosongkan objek dan shutter menolak memotret sampai diisi; dokumen tetap di album galeri yang sama; impor galeri tidak berubah.
- Implementasi:
  - `lib/survey/`: `survey_naming.dart` (sanitasi + `buildSurveyBaseName` + `pickAvailableName`, murni), `models/survey_category.dart`, `survey_service.dart` (shared_preferences key `survey_json`, terpisah dari `AppSettings` supaya "reset setelan" tidak menghapus data sesi), `survey_controller.dart`.
  - `PhotoStorageService.reserveNamedBaseName` (cek bentrok album processed + original) dan `promoteOriginalToProcessed` (rename JPEG kamera ke staging processed).
  - `CaptureController`: `surveyShotProvider`/`surveyEnabledProvider`; mode aktif tapi data belum lengkap → `StateError`; kategori tanpa watermark melewati `fetchOnlineData`.
  - `WatermarkPublisher.publish(applyWatermark: false)` → `_publishPlain`: tanpa render/geocode/peta, EXIF GPS+waktu tetap ditulis, tanpa salinan original (`originalPath = processedPath`).
  - UI: `camera/widgets/survey_strip.dart` (chip objek, kategori, pratinjau nama, "Objek berikutnya"), `survey_object_sheet.dart`; `camera_screen.dart` menyembunyikan live watermark untuk kategori tanpa watermark, memuat ulang alamat/peta live saat kembali ke kategori ber-watermark, dan menambah clearance bawah (`surveyStripHeight`). Pengaturan: bagian "Mode Survei" di `settings_screen.dart` (switch, lokasi, kategori, catatan privasi).
- Tes: `flutter analyze` bersih, 80 tes lolos (tambahan `survey_naming_test.dart`, `survey_controller_test.dart`). Diuji user di HP: alur nama file dan kategori berjalan.
- **Tata letak UI kamera**: selesai diperbaiki menyeluruh pada 13 Okt 2026 (lihat butir 16).
- Catatan privasi: foto KK/KTP/SHM masuk galeri publik (`Pictures/GeoPatriot`), terbaca aplikasi lain dan ikut backup cloud galeri. Opsi penyimpanan privat dicatat sebagai pekerjaan lanjutan.
- Di luar cakupan: ganti nama file yang sudah ada (salah ketik), ekspor CSV daftar objek/foto, penamaan foto impor galeri, penyimpanan privat dokumen.

## 16. Perbaikan Tata Letak UI Mode Survei (Portrait & Landscape) + Kategori Baru (13 Okt 2026)
- Masalah visual awal:
  - Portrait: Live watermark terdorong ke kiri karena margin asimetris; strip survei menumpuk dengan zoom ruler.
  - Landscape: Kapsul kategori menindih Zoom Ruler di atas shutter; tombol aksi dan pill GPS bergeser ke kanan menjauhi tepi fisik HP; kolom objek dan tombol "Next Object" menjorok masuk ke dalam layar preview kamera.
- Solusi & Arsitektur Baru:
  - **Portrait**: Live watermark 100% simetris di tengah. Kolom objek diletakkan di baris ke-2 atas (`SurveyObjectHeader`). Kapsul kategori bergaya Samsung One UI (`SurveyCategorySlider`): *idle* berupa kapsul ringkas `[ 🏷️ Rumah > ]`, ketika diketuk membuka slider horizontal mengambang dengan tombol `[ ✕ ]`.
  - **Landscape**:
    - Kapsul kategori diposisikan di **Sudut Kanan Atas** layar (`Positioned(right: 16, bottom: 96)` pada `quarterTurns: 1`). Bebas >180 dp dari Zoom Ruler. Saat diketuk, slider membuka horizontal ke arah kiri di sepanjang tepi atas layar.
    - Top HUD menggunakan `CrossAxisAlignment.start` sehingga seluruh tombol aksi dan pill GPS menempel erat ke tepi luar ("mepet ke kiri").
    - Kolom objek compact dibatasi `maxWidth: 96` (bebas ~25 dp dari layar preview kamera). Tombol "Next Object" diletakkan di bawah kolom objek di sepanjang rel kiri (`[Aksi]` → `[Objek]` → `[Next Object]` → `[GPS]`).
  - **Panah Dinamis**: Kapsul kategori mengarah ke kanan (`chevron_right`) saat portrait dan ke kiri (`chevron_left`) saat landscape (sesuai arah ekspansi slider). Chip objek di landscape mengarah ke kanan (`chevron_right`).
  - **Kategori Bawaan Baru**: Rumah (default aktif ber-watermark), Lahan (watermark), KK (dokumen tanpa watermark), SHM (dokumen tanpa watermark), Sarpras (watermark), Barang (watermark).
  - **Reset Nilai**: `SurveyController.resetToDefaults()` mengosongkan nama objek, kode objek, lokasi objek, serta mereset kategori. Terhubung ke dialog Reset Pengaturan utama dan tombol "Kembalikan bawaan" di pengaturan survei.
- Tes: `flutter analyze` 0 issues, `flutter test` 93/93 lolos. Diuji via automated test suite.

## Perlu diuji di HP (belum dikonfirmasi)
- Ukuran kotak watermark live vs hasil setelah perbaikan skala (item 10).
- Zoom detail foto: tidak terpotong, pan satu jari, double-tap, swipe antar foto di 1× (item 11).
- Mode pesawat di luar ruangan: watermark berisi koordinat tanpa alamat/peta, waktu proses ≤ ±6 dtk.
- ~~Waktu render foto 1080p~~ → sudah terjawab: preset `max` (12 MP) cepat setelah kompositor native (butir 14). Belum diuji: kamera depan di semua orientasi, foto dengan EXIF mirror, perangkat lain selain Galaxy S25+.
- Impor foto galeri (ber-EXIF GPS dan tanpa), input manual, watermark di 4 orientasi, riwayat sinkron.

## Catatan teknis
- Build rilis: `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define=LOCATIONIQ_API_KEY_ENCODED=<hasil encode>` (key ada di `GeoPatriot Web/.env.local`, harus di-trim spasinya sebelum disandikan).
- Mengambil key dengan benar (bash): `KEY=$(grep -E '^NEXT_PUBLIC_LOCATIONIQ_API_KEY=' "../GeoPatriot Web/.env.local" | head -1 | cut -d= -f2- | tr -d ' \r"')` (jangan `grep -i LOCATIONIQ`: kena baris komentar). Sandikan: `ENC=$(dart run tool/encode_api_key.dart "$KEY" 2>&1 | tr -d '\r' | sed 's/Running build hooks\.\.\.//g' | tail -1)` (`dart run` menempelkan teks "Running build hooks..." di depan hasil). Validasi sebelum build: panjang `ENC` 48 dan dekode XOR sama dengan `KEY` (35 karakter, awalan `pk.`). Gejala key salah: log `flutter` berisi "API key kosong, lewati request" (`adb logcat -s flutter`).
- Rilis GitHub: repo pindah ke `abyan28/GeoPatriot`; `gh release create/upload ... --repo abyan28/GeoPatriot`. Verifikasi tanda tangan: `apksigner verify --print-certs` dengan `JAVA_HOME` = JDK Android Studio (`jbr`).
- Insiden v1.1.0: APK rilis pertama terbit tanpa key (key kosong), diganti dengan `gh release upload --clobber` setelah diuji di HP.
- Pasang ke HP lewat wireless debugging: `adb pair IP:PORT_PAIRING` (sekali), lalu `adb connect IP:PORT_KONEKSI` (port berubah tiap diaktifkan ulang), `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Bila tanda tangan beda, uninstall dulu.
- Build uji cepat (bash, tanpa `--obfuscate`): `KEY=$(grep '^NEXT_PUBLIC_LOCATIONIQ_API_KEY=' "../GeoPatriot Web/.env.local" | cut -d= -f2- | tr -d '\r' | xargs)`, `ENC=$(dart run tool/encode_api_key.dart "$KEY" | tail -1)`, lalu `flutter build apk --release --split-per-abi --dart-define=LOCATIONIQ_API_KEY_ENCODED="$ENC"` dan `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
- Heredoc Python berisi tanda kutip tiga/apostrof di tool Bash bisa gagal ("unexpected EOF"); tulis skrip ke file dulu lalu jalankan.
- Semua commit masih lokal, belum di-push.

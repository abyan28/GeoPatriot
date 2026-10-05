- [x] perbaiki live watermark yg offside ketika mode portrait yg satunya (atas-bawah). ("D:\Aplikasi\GeoPatriot\referensi\bug rotasi ke atas.jpg")
- [x] tambahkan menu manual input koordinat yg nantinya bakal di-reverse geocoding + thumbnail petanya.
- [x] tambahkan menu input manual timestamp-nya.
- [x] tambahkan fitur untuk menambahkan watermark secara manual dari foto yg ada di galeri.
- [x] kenapa fitur galeri di aplikasinya ketika sebuah foto di galeri tersebut dihapus melalui galeri bawaan HP, terdapat jejaknya di galeri aplikasi. Susah jelaskannya, aku kasih ss-nya saja. "D:\Aplikasi\GeoPatriot\referensi\tampak galeri apps.jpg" dan "D:\Aplikasi\GeoPatriot\referensi\tampilan foto yg dihapus.jpg".
- [x] Switcher camera depannya sepertinya bermasalah. Coba cek deh. Tiap kali tekan tombol switcher ke kamera depan, layar selalu black gitu dan kayak hang. Ada juga muncul error seperti berikut: "D:\Aplikasi\GeoPatriot\referensi\Screenshot_20261006_060704.jpg". Bahkan ketika kamera depan berhasil diakses, ketika kembali ke kamera belakang juga layar jadi black dan kayak hang gitu. Coba dicek lagi ya.
- [x] Oh iya, untuk referensi pengerjaan tambahan fiturnya bisa coba dicek ke folder "D:\Aplikasi\GeoPatriot Web" ini ya. Itu versi web dari aplikasi ini. (dipakai sebagai acuan parser koordinat dan alur impor foto)

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

## Perlu diuji di HP (belum dikonfirmasi)
- Ukuran kotak watermark live vs hasil setelah perbaikan skala (item 10).
- Zoom detail foto: tidak terpotong, pan satu jari, double-tap, swipe antar foto di 1× (item 11).
- Mode pesawat di luar ruangan: watermark berisi koordinat tanpa alamat/peta, waktu proses ≤ ±6 dtk.
- Waktu render foto 1080p (jika lambat, kembali ke preset lebih rendah).
- Impor foto galeri (ber-EXIF GPS dan tanpa), input manual, watermark di 4 orientasi, riwayat sinkron.

## Catatan teknis
- Build rilis: `flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols --dart-define=LOCATIONIQ_API_KEY_ENCODED=<hasil encode>` (key ada di `GeoPatriot Web/.env.local`, harus di-trim spasinya sebelum disandikan).
- Pasang ke HP lewat wireless debugging: `adb pair IP:PORT_PAIRING` (sekali), lalu `adb connect IP:PORT_KONEKSI` (port berubah tiap diaktifkan ulang), `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Bila tanda tangan beda, uninstall dulu.
- Semua commit masih lokal, belum di-push.

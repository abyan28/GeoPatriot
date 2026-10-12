# GeoPatriot

Aplikasi kamera Flutter yang menandai setiap foto dengan lokasi GPS,
alamat, thumbnail peta, dan waktu pengambilan lewat watermark yang
dirender langsung ke gambar. Dibangun **local-first**: tidak ada backend,
login, atau database server. Lihat `agents/prd-free-first.md`,
`agents/workflow-free-first.md`, dan `agents/rules-free-first.md` untuk
spesifikasi lengkap.

## Status implementasi saat ini

Fase 0-13 dari `workflow-free-first.md` sudah selesai (lihat
`agents/tasklist.md` untuk rincian per fase):

- Camera: preview, shutter, switch kamera, orientasi capture dikunci ke
  posisi device saat ini.
  Resolusi foto memakai `ResolutionPreset.max` (4:3, ±12 MP di Galaxy S25+);
  preset `ultraHigh` (4K 16:9) dihindari karena menghasilkan pita hijau dan
  warna bergeser pada Samsung S25+ (lihat `agents/notes.md` butir 13).
- Mode Survei (opsional, Pengaturan): nama file otomatis
  `objek-kategori-lokasi.jpg`, kategori dokumen (KK/KTP/SHM) tanpa watermark
  dan tanpa live watermark. Catatan: tata letak UI kamera pada mode ini
  masih dalam perbaikan (lihat `agents/notes.md` butir 15).
- Location: status GPS live + kategori akurasi, freeze snapshot saat capture.
- Watermark: panel lokasi/alamat/koordinat/tanggal/waktu/akurasi/altitude +
  thumbnail peta, 3 template (Default/Ringkas/Detail), sepenuhnya bisa
  dikonfigurasi lewat Settings. Panel digambar di Dart lalu ditempel ke foto
  penuh oleh kompositor native Android (`MainActivity.kt`,
  `lib/watermark/native_compositor.dart`); bila native tidak tersedia
  otomatis memakai render Dart penuh.
- Reverse geocoding & map thumbnail: **LocationIQ** (butuh API key gratis,
  lihat bagian "Menjalankan project" di bawah).
- EXIF: GPS + DateTimeOriginal ditulis ke file processed (best-effort).
- History: gallery, detail, share, delete foto (index lokal, tanpa database).
- Settings: seluruh pengaturan watermark tersimpan lokal dan langsung
  memengaruhi capture berikutnya.
- Offline-first: kegagalan geocoding/map/EXIF tidak pernah menggagalkan
  capture (lihat `lib/core/network/safe_fetch.dart`).

**Belum dikerjakan**: satellite imagery (Fase 14, sengaja opsional/bukan
MVP), checklist rilis (Fase 15: app icon custom, signing config produksi).

**Bug diketahui, belum diperbaiki**: watermark/foto belum konsisten
mengikuti orientasi landscape pada sebagian device (lihat
`agents/tasklist.md` bagian "Catatan Non-Fase" untuk detail diagnostik
yang sedang dikumpulkan).

### Kenapa LocationIQ, bukan Nominatim/OSM tile publik?

Versi awal aplikasi memakai Nominatim publik dan `tile.openstreetmap.org`
langsung (sesuai visi free-first di PRD). Uji di device fisik menunjukkan
kedua layanan itu memblokir traffic aplikasi ini (Nominatim membalas HTTP
403 mengarah ke halaman policy resminya; tile server membalas gambar
"diblokir" pengganti, bukan peta asli). LocationIQ dipilih sebagai
gantinya karena satu API key gratis mencakup keduanya dan memang didesain
untuk dipakai aplikasi. Implementasi Nominatim/OSM tile lama tetap ada di
`lib/geocoding/nominatim_geocoding_provider.dart` dan
`lib/map/osm_raster_map_thumbnail_provider.dart` sebagai referensi/alternatif
provider (arsitektur provider abstraction memang dirancang supaya mudah diganti).

## Menjalankan project

```
flutter pub get
```

Daftar API key gratis di [locationiq.com](https://locationiq.com) (jatah
gratis: 5.000 request/hari, 2 request/detik). API key TIDAK ditanam sebagai
string polos di kode maupun hasil build — harus disandikan dulu lewat
`tool/encode_api_key.dart` supaya tidak langsung terlihat kalau APK dibuka
pakai `strings`/pembuka teks biasa (bukan keamanan sungguhan — cuma
menaikkan sedikit kesulitan pengambilannya, lihat penjelasan lengkap di
`lib/core/config/api_keys.dart`):

```
dart run tool/encode_api_key.dart <API_KEY_ASLI>
```

Salin hasilnya, lalu jalankan:

```
flutter run --dart-define=LOCATIONIQ_API_KEY_ENCODED=<hasil_encode>
```

Tanpa API key, aplikasi tetap berjalan normal, hanya reverse geocoding dan
map thumbnail yang tidak aktif (watermark fallback ke koordinat saja).

Izin kamera dan lokasi akan diminta saat aplikasi pertama kali dibuka.

## Rilis APK publik (mis. GitHub Release)

Supaya user baru bisa langsung pakai tanpa mendaftar API key sendiri, build
APK rilis dengan API key milikmu sendiri (sudah disandikan seperti di atas)
ikut ditanam:

```
flutter build apk --release --dart-define=LOCATIONIQ_API_KEY_ENCODED=<hasil_encode>
```

**Perlu disadari**: jatah 5.000 request/hari akan dipakai BERSAMA oleh
semua orang yang memakai APK rilisanmu (bukan per-user), dan siapa pun yang
niat membongkar (decompile) aplikasinya tetap bisa menemukan API key
aslinya. Pantau pemakaian lewat dashboard LocationIQ, dan reset/ganti key
kapan saja kalau mulai terlihat disalahgunakan.

## Verifikasi

```
flutter analyze
flutter test
flutter build apk --debug --dart-define=LOCATIONIQ_API_KEY_ENCODED=<hasil_encode>
```

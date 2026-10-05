import 'dart:convert';

/// API key pihak ketiga untuk rilis publik (APK GitHub Release): TIDAK
/// disimpan sebagai string polos di manapun (source, build command, atau
/// binary hasil compile) — cuma bentuk TERSANDI yang ditanam lewat
/// `--dart-define=LOCATIONIQ_API_KEY_ENCODED=...`, didekode saat runtime.
///
/// PENTING (jujur ke diri sendiri, bukan klaim "aman total"): TIDAK ADA
/// cara membuat secret yang ditanam di aplikasi client benar-benar tidak
/// bisa diambil — siapa pun yang niat decompile/reverse-engineer aplikasi
/// ini tetap bisa menemukan API key aslinya (mis. dengan intersep request
/// jaringan, atau menjalankan fungsi decode ini sendiri). Penyandian ini
/// CUMA menaikkan kesulitan dari "kelihatan langsung kalau APK dibuka
/// pakai `strings`/pembuka teks biasa" jadi "perlu usaha decompile aktif".
///
/// Cara pakai (lihat juga `tool/encode_api_key.dart` & README.md):
/// 1. `dart run tool/encode_api_key.dart <API_KEY_ASLI>` → hasil tersandi.
/// 2. `flutter build apk --dart-define=LOCATIONIQ_API_KEY_ENCODED=<hasil>`
const _encodedLocationIqApiKey = String.fromEnvironment(
  'LOCATIONIQ_API_KEY_ENCODED',
);

/// Kunci XOR untuk membalik penyandian di atas. Nilai ini SENDIRI tidak
/// rahasia (memang tidak mungkin dirahasiakan bersama kodenya) — cuma
/// bagian dari mekanisme penyamaran, bukan lapisan keamanan sungguhan.
const _obfuscationPassphrase = 'GeoPatriot-2026-watermark-camera';

/// API key LocationIQ hasil dekode saat runtime. Kosong (bukan crash) jika
/// belum di-set atau gagal didekode — provider yang membutuhkan key ini
/// wajib mengembalikan null dengan aman, sama seperti sebelumnya.
final String locationIqApiKey = _decodeApiKey(
  _encodedLocationIqApiKey,
  _obfuscationPassphrase,
);

/// Balikkan penyandian XOR+base64 dari [encodeApiKey] (lihat
/// `tool/encode_api_key.dart`, algoritmanya harus identik).
String _decodeApiKey(String encodedBase64, String passphrase) {
  if (encodedBase64.isEmpty) return '';
  try {
    final bytes = base64.decode(encodedBase64);
    final keyBytes = utf8.encode(passphrase);
    final decoded = List<int>.generate(
      bytes.length,
      (i) => bytes[i] ^ keyBytes[i % keyBytes.length],
    );
    // trim: spasi/baris baru ikut tersandi bila key disalin dari file .env
    // yang tidak rapi, dan itu membuat LocationIQ membalas 401 "Invalid key".
    return utf8.decode(decoded).trim();
  } catch (_) {
    return '';
  }
}

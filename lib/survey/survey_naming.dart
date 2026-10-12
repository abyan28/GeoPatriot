// Penamaan file untuk Mode Survei: `{objek}[-{kode}]-{kategori}-{lokasi}`.
//
// Semua fungsi murni (tanpa I/O) supaya mudah dites.

const _maxPartLength = 40;

const _accentMap = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ý': 'y', 'ÿ': 'y',
};

/// Ubah teks bebas jadi satu bagian nama file: huruf kecil, aksen dibuang,
/// hanya `a-z`, `0-9`, dan `-`. Mengembalikan string kosong bila tidak ada
/// karakter yang tersisa.
String sanitizeNamePart(String input) {
  final lower = input.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_accentMap[char] ?? char);
  }

  var text = buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  text = text.replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  if (text.length > _maxPartLength) {
    text = text.substring(0, _maxPartLength).replaceAll(RegExp(r'-+$'), '');
  }
  return text;
}

/// Susun nama dasar file (tanpa ekstensi). Mengembalikan null bila salah satu
/// bagian wajib ([objek], [kategori], [lokasi]) kosong setelah dibersihkan.
/// [kode] opsional, ditaruh tepat setelah objek.
String? buildSurveyBaseName({
  required String objek,
  String? kode,
  required String kategori,
  required String lokasi,
}) {
  final objekPart = sanitizeNamePart(objek);
  final kodePart = sanitizeNamePart(kode ?? '');
  final kategoriPart = sanitizeNamePart(kategori);
  final lokasiPart = sanitizeNamePart(lokasi);
  if (objekPart.isEmpty || kategoriPart.isEmpty || lokasiPart.isEmpty) return null;

  return [objekPart, if (kodePart.isNotEmpty) kodePart, kategoriPart, lokasiPart].join('-');
}

/// Pilih nama yang belum terpakai: [desired] bila bebas, selain itu
/// `desired-2`, `desired-3`, dst. [isTaken] memeriksa satu kandidat.
Future<String> pickAvailableName(String desired, Future<bool> Function(String candidate) isTaken) async {
  var candidate = desired;
  var counter = 2;
  while (await isTaken(candidate)) {
    candidate = '$desired-$counter';
    counter++;
  }
  return candidate;
}

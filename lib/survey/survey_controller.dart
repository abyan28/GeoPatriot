import 'package:flutter/foundation.dart';

import 'models/survey_category.dart';
import 'survey_naming.dart';
import 'survey_service.dart';

/// Satu foto survei yang akan diambil: nama dasar yang diinginkan dan apakah
/// watermark diterapkan.
class SurveyShot {
  const SurveyShot({required this.desiredBaseName, required this.applyWatermark});

  final String desiredBaseName;
  final bool applyWatermark;
}

/// Sumber kebenaran Mode Survei. Data persisten (aktif, lokasi SP, kategori,
/// objek terakhir) disimpan lewat [SurveyService]; objek, kode, dan kategori
/// terpilih hanya di memori.
class SurveyController extends ChangeNotifier {
  SurveyController({SurveyService? service}) : _service = service ?? SurveyService() {
    _loadFromDisk();
  }

  static const maxRecentObjects = 5;

  final SurveyService _service;

  SurveyData _data = const SurveyData();
  bool isLoaded = false;

  String objectName = '';
  String objectCode = '';
  String? _selectedCategoryId;

  bool get enabled => _data.enabled;
  String get locationName => _data.locationName;
  List<SurveyCategory> get categories => _data.categories;
  List<String> get recentObjects => _data.recentObjects;

  SurveyCategory? get selectedCategory {
    final cats = categories;
    if (cats.isEmpty) return null;
    for (final c in cats) {
      if (c.id == _selectedCategoryId) return c;
    }
    return cats.first;
  }

  /// Nama dasar yang akan dipakai untuk foto berikutnya, null bila data
  /// belum lengkap (objek/lokasi/kategori kosong).
  String? get previewBaseName {
    final category = selectedCategory;
    if (category == null) return null;
    return buildSurveyBaseName(
      objek: objectName,
      kode: objectCode,
      kategori: category.label,
      lokasi: locationName,
    );
  }

  String? get previewFileName {
    final base = previewBaseName;
    return base == null ? null : '$base.jpg';
  }

  /// Mode aktif dan semua bagian nama sudah terisi, siap memotret.
  bool get isReady => enabled && previewBaseName != null;

  /// Data foto berikutnya, atau null bila mode mati / belum siap.
  SurveyShot? get currentShot {
    if (!enabled) return null;
    final base = previewBaseName;
    final category = selectedCategory;
    if (base == null || category == null) return null;
    return SurveyShot(desiredBaseName: base, applyWatermark: category.applyWatermark);
  }

  Future<void> _loadFromDisk() async {
    _data = await _service.load();
    isLoaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) => _update(_data.copyWith(enabled: value));

  Future<void> setLocation(String value) => _update(_data.copyWith(locationName: value.trim()));

  /// Set objek aktif dan catat ke daftar objek terakhir (terbaru di depan,
  /// tanpa duplikat, maksimal [maxRecentObjects]).
  Future<void> setObject(String name, {String code = ''}) async {
    objectName = name.trim();
    objectCode = code.trim();
    if (objectName.isEmpty) {
      notifyListeners();
      return;
    }
    final recent = [
      objectName,
      ..._data.recentObjects.where((e) => e.toLowerCase() != objectName.toLowerCase()),
    ].take(maxRecentObjects).toList();
    await _update(_data.copyWith(recentObjects: recent));
  }

  /// Kosongkan objek dan kode (pindah rumah); kategori kembali ke yang pertama.
  void nextObject() {
    objectName = '';
    objectCode = '';
    _selectedCategoryId = null;
    notifyListeners();
  }

  void selectCategory(String id) {
    _selectedCategoryId = id;
    notifyListeners();
  }

  Future<void> upsertCategory(SurveyCategory category) async {
    final cats = [...categories];
    final index = cats.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      cats[index] = category;
    } else {
      cats.add(category);
    }
    await _update(_data.copyWith(categories: cats));
  }

  /// Buat kategori baru dari [label] bebas; id diturunkan dari label dan
  /// dibuat unik. Mengembalikan null bila label kosong setelah dibersihkan.
  Future<SurveyCategory?> addCategory(String label, {bool applyWatermark = true}) async {
    final slug = sanitizeNamePart(label);
    if (slug.isEmpty) return null;
    var id = slug;
    var counter = 2;
    while (categories.any((c) => c.id == id)) {
      id = '$slug-$counter';
      counter++;
    }
    final category = SurveyCategory(id: id, label: label.trim(), applyWatermark: applyWatermark);
    await upsertCategory(category);
    return category;
  }

  /// Hapus kategori; daftar tidak boleh kosong sama sekali.
  Future<void> removeCategory(String id) async {
    if (categories.length <= 1) return;
    if (_selectedCategoryId == id) _selectedCategoryId = null;
    await _update(_data.copyWith(categories: categories.where((c) => c.id != id).toList()));
  }

  /// Reset seluruh setelan survei ke nilai awal pabrik:
  /// nama objek, kode objek, lokasi objek ikut dikosongkan.
  Future<void> resetToDefaults() async {
    objectName = '';
    objectCode = '';
    _selectedCategoryId = null;
    await _update(
      const SurveyData(
        enabled: false,
        locationName: '',
        categories: SurveyCategory.defaults,
        recentObjects: [],
      ),
    );
  }

  /// Kembalikan kategori ke bawaan serta kosongkan objek & lokasi.
  Future<void> resetCategories() async {
    objectName = '';
    objectCode = '';
    _selectedCategoryId = null;
    await _update(
      _data.copyWith(
        categories: SurveyCategory.defaults,
        locationName: '',
      ),
    );
  }

  Future<void> _update(SurveyData updated) async {
    _data = updated;
    notifyListeners();
    await _service.save(updated);
  }
}

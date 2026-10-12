import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/survey_category.dart';

/// Bagian Mode Survei yang dipersist (objek aktif sengaja TIDAK disimpan,
/// supaya aplikasi yang dibuka kembali tidak memakai nama rumah sebelumnya).
class SurveyData {
  const SurveyData({
    this.enabled = false,
    this.locationName = '',
    this.categories = SurveyCategory.defaults,
    this.recentObjects = const [],
  });

  final bool enabled;
  final String locationName;
  final List<SurveyCategory> categories;
  final List<String> recentObjects;

  SurveyData copyWith({
    bool? enabled,
    String? locationName,
    List<SurveyCategory>? categories,
    List<String>? recentObjects,
  }) {
    return SurveyData(
      enabled: enabled ?? this.enabled,
      locationName: locationName ?? this.locationName,
      categories: categories ?? this.categories,
      recentObjects: recentObjects ?? this.recentObjects,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'locationName': locationName,
        'categories': categories.map((c) => c.toJson()).toList(),
        'recentObjects': recentObjects,
      };

  factory SurveyData.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'] as List<dynamic>?;
    final categories = rawCategories
        ?.map((e) => SurveyCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    return SurveyData(
      enabled: json['enabled'] as bool? ?? false,
      locationName: json['locationName'] as String? ?? '',
      categories: (categories == null || categories.isEmpty) ? SurveyCategory.defaults : categories,
      recentObjects: (json['recentObjects'] as List<dynamic>?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// Baca/tulis [SurveyData] lewat shared_preferences.
class SurveyService {
  static const _key = 'survey_json';

  Future<SurveyData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const SurveyData();

    try {
      return SurveyData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const SurveyData();
    }
  }

  Future<void> save(SurveyData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }
}

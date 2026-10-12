/// Satu kategori foto survei (mis. Lahan, Rumah, KK). [applyWatermark] false
/// berarti hasil foto bersih tanpa watermark dan live watermark disembunyikan.
class SurveyCategory {
  const SurveyCategory({required this.id, required this.label, this.applyWatermark = true});

  final String id;
  final String label;
  final bool applyWatermark;

  SurveyCategory copyWith({String? label, bool? applyWatermark}) => SurveyCategory(
        id: id,
        label: label ?? this.label,
        applyWatermark: applyWatermark ?? this.applyWatermark,
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'applyWatermark': applyWatermark};

  factory SurveyCategory.fromJson(Map<String, dynamic> json) => SurveyCategory(
        id: json['id'] as String,
        label: json['label'] as String,
        applyWatermark: json['applyWatermark'] as bool? ?? true,
      );

  /// Daftar bawaan: foto lokasi ber-watermark, dokumen bersih.
  static const defaults = <SurveyCategory>[
    SurveyCategory(id: 'lahan', label: 'Lahan'),
    SurveyCategory(id: 'rumah', label: 'Rumah'),
    SurveyCategory(id: 'kk', label: 'KK', applyWatermark: false),
    SurveyCategory(id: 'ktp', label: 'KTP', applyWatermark: false),
    SurveyCategory(id: 'shm', label: 'SHM', applyWatermark: false),
    SurveyCategory(id: 'dokumen-lain', label: 'Dokumen lain', applyWatermark: false),
  ];
}

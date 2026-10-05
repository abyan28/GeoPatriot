import 'watermark_position.dart';

/// Konfigurasi tampilan watermark: field mana yang aktif, posisi, dan
/// appearance (opacity/ukuran/spacing). Watermark selalu berbasis
/// konfigurasi ini, tidak pernah hard-coded di renderer.
class WatermarkConfiguration {
  const WatermarkConfiguration({
    required this.showLocationName,
    required this.showAddress,
    required this.showCoordinates,
    required this.showDate,
    required this.showTime,
    required this.showTimezone,
    required this.showAccuracy,
    required this.showAltitude,
    required this.showMapThumbnail,
    required this.position,
    required this.opacity,
    required this.fontSize,
    required this.thumbnailSize,
    required this.margin,
    required this.cornerRadius,
    required this.spacing,
    required this.mapZoom,
    this.customText,
    this.appBrandingText = 'GeoPatriot',
  });

  final bool showLocationName;
  final bool showAddress;
  final bool showCoordinates;
  final bool showDate;
  final bool showTime;
  final bool showTimezone;
  final bool showAccuracy;
  final bool showAltitude;
  final bool showMapThumbnail;
  final WatermarkPosition position;

  /// Opacity panel watermark, 0.0 (transparan penuh) - 1.0 (solid).
  final double opacity;

  /// Ukuran font teks watermark dalam logical pixel.
  final double fontSize;

  /// Ukuran sisi thumbnail peta persegi dalam logical pixel.
  final double thumbnailSize;

  /// Margin panel watermark dari tepi foto, dalam logical pixel.
  final double margin;

  /// Radius sudut panel watermark, dalam logical pixel.
  final double cornerRadius;

  /// Jarak antar baris teks, dalam logical pixel.
  final double spacing;

  /// Level zoom peta untuk thumbnail (semakin besar semakin dekat).
  final int mapZoom;

  final String? customText;
  final String appBrandingText;

  /// Template default: disetel mengikuti preferensi user sendiri (hasil
  /// pengaturan yang sudah dicoba-coba di device nyata dan diminta jadi
  /// default), bukan lagi tebakan awal.
  factory WatermarkConfiguration.defaultTemplate() => const WatermarkConfiguration(
        showLocationName: true,
        showAddress: true,
        showCoordinates: true,
        showDate: true,
        showTime: true,
        showTimezone: true,
        showAccuracy: true,
        showAltitude: false,
        showMapThumbnail: true,
        position: WatermarkPosition.bottom,
        opacity: 0.40,
        fontSize: 14,
        thumbnailSize: 160,
        margin: 16,
        cornerRadius: 12,
        spacing: 4,
        mapZoom: 16,
      );

  /// Template ringkas: hanya koordinat dan tanggal/waktu, tanpa thumbnail
  /// peta, panel lebih kecil. Cocok untuk foto dengan watermark minimal.
  factory WatermarkConfiguration.compact() => const WatermarkConfiguration(
        showLocationName: false,
        showAddress: false,
        showCoordinates: true,
        showDate: true,
        showTime: true,
        showTimezone: false,
        showAccuracy: false,
        showAltitude: false,
        showMapThumbnail: false,
        position: WatermarkPosition.bottom,
        opacity: 0.5,
        fontSize: 14,
        thumbnailSize: 0,
        margin: 12,
        cornerRadius: 8,
        spacing: 2,
        mapZoom: 16,
      );

  /// Template detail: semua field aktif termasuk altitude dan timezone,
  /// panel lebih besar untuk dokumentasi yang butuh informasi lengkap.
  factory WatermarkConfiguration.detail() => const WatermarkConfiguration(
        showLocationName: true,
        showAddress: true,
        showCoordinates: true,
        showDate: true,
        showTime: true,
        showTimezone: true,
        showAccuracy: true,
        showAltitude: true,
        showMapThumbnail: true,
        position: WatermarkPosition.bottom,
        opacity: 0.65,
        fontSize: 22,
        thumbnailSize: 160,
        margin: 16,
        cornerRadius: 12,
        spacing: 5,
        mapZoom: 17,
      );

  /// Salinan dengan semua ukuran piksel (font, thumbnail, margin, sudut,
  /// spasi) dikalikan [factor]. Dipakai renderer agar ukuran watermark
  /// proporsional terhadap resolusi foto (lihat [watermarkScaleFor]).
  WatermarkConfiguration scaledBy(double factor) => copyWith(
        fontSize: fontSize * factor,
        thumbnailSize: thumbnailSize * factor,
        margin: margin * factor,
        cornerRadius: cornerRadius * factor,
        spacing: spacing * factor,
      );

  /// Buat salinan konfigurasi dengan field tertentu diganti, dipakai layar
  /// Settings saat pengguna mengubah satu opsi.
  WatermarkConfiguration copyWith({
    bool? showLocationName,
    bool? showAddress,
    bool? showCoordinates,
    bool? showDate,
    bool? showTime,
    bool? showTimezone,
    bool? showAccuracy,
    bool? showAltitude,
    bool? showMapThumbnail,
    WatermarkPosition? position,
    double? opacity,
    double? fontSize,
    double? thumbnailSize,
    double? margin,
    double? cornerRadius,
    double? spacing,
    int? mapZoom,
    String? customText,
    String? appBrandingText,
  }) {
    return WatermarkConfiguration(
      showLocationName: showLocationName ?? this.showLocationName,
      showAddress: showAddress ?? this.showAddress,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      showDate: showDate ?? this.showDate,
      showTime: showTime ?? this.showTime,
      showTimezone: showTimezone ?? this.showTimezone,
      showAccuracy: showAccuracy ?? this.showAccuracy,
      showAltitude: showAltitude ?? this.showAltitude,
      showMapThumbnail: showMapThumbnail ?? this.showMapThumbnail,
      position: position ?? this.position,
      opacity: opacity ?? this.opacity,
      fontSize: fontSize ?? this.fontSize,
      thumbnailSize: thumbnailSize ?? this.thumbnailSize,
      margin: margin ?? this.margin,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      spacing: spacing ?? this.spacing,
      mapZoom: mapZoom ?? this.mapZoom,
      customText: customText ?? this.customText,
      appBrandingText: appBrandingText ?? this.appBrandingText,
    );
  }

  /// Serialisasi ke Map untuk disimpan lewat shared_preferences (Fase 11).
  Map<String, dynamic> toJson() => {
        'showLocationName': showLocationName,
        'showAddress': showAddress,
        'showCoordinates': showCoordinates,
        'showDate': showDate,
        'showTime': showTime,
        'showTimezone': showTimezone,
        'showAccuracy': showAccuracy,
        'showAltitude': showAltitude,
        'showMapThumbnail': showMapThumbnail,
        'position': position.name,
        'opacity': opacity,
        'fontSize': fontSize,
        'thumbnailSize': thumbnailSize,
        'margin': margin,
        'cornerRadius': cornerRadius,
        'spacing': spacing,
        'mapZoom': mapZoom,
        'customText': customText,
        // appBrandingText SENGAJA tidak disimpan — field ini tidak pernah
        // bisa diubah dari UI Pengaturan (murni default kode), menyimpannya
        // cuma bikin nilai lama "basi" tersimpan kalau nama aplikasi
        // berubah di rilis berikutnya (pernah terjadi: tersimpan "GPS
        // Camera" walau kode sudah default "GeoPatriot").
      };

  /// Baca kembali konfigurasi dari Map hasil [toJson]. Field yang hilang
  /// (mis. karena versi lama) diisi nilai default template default supaya
  /// tidak crash pada upgrade aplikasi.
  factory WatermarkConfiguration.fromJson(Map<String, dynamic> json) {
    final fallback = WatermarkConfiguration.defaultTemplate();
    return WatermarkConfiguration(
      showLocationName: json['showLocationName'] as bool? ?? fallback.showLocationName,
      showAddress: json['showAddress'] as bool? ?? fallback.showAddress,
      showCoordinates: json['showCoordinates'] as bool? ?? fallback.showCoordinates,
      showDate: json['showDate'] as bool? ?? fallback.showDate,
      showTime: json['showTime'] as bool? ?? fallback.showTime,
      showTimezone: json['showTimezone'] as bool? ?? fallback.showTimezone,
      showAccuracy: json['showAccuracy'] as bool? ?? fallback.showAccuracy,
      showAltitude: json['showAltitude'] as bool? ?? fallback.showAltitude,
      showMapThumbnail: json['showMapThumbnail'] as bool? ?? fallback.showMapThumbnail,
      position: WatermarkPosition.values.firstWhere(
        (value) => value.name == json['position'],
        orElse: () => fallback.position,
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? fallback.opacity,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? fallback.fontSize,
      thumbnailSize: (json['thumbnailSize'] as num?)?.toDouble() ?? fallback.thumbnailSize,
      margin: (json['margin'] as num?)?.toDouble() ?? fallback.margin,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? fallback.cornerRadius,
      spacing: (json['spacing'] as num?)?.toDouble() ?? fallback.spacing,
      mapZoom: json['mapZoom'] as int? ?? fallback.mapZoom,
      customText: json['customText'] as String?,
      // appBrandingText tidak dibaca dari storage (lihat catatan di toJson)
      // — selalu pakai default terbaru dari kode.
    );
  }
}

/// Sisi pendek foto (dalam piksel) yang menjadi acuan desain ukuran
/// watermark: semua angka di [WatermarkConfiguration] (font 14, thumbnail 160,
/// margin 16, ...) adalah ukuran untuk foto selebar 720 px. Foto beresolusi
/// lebih tinggi memakai faktor [watermarkScaleFor] supaya kotak watermark
/// menempati porsi foto yang sama, tidak mengecil saat resolusi dinaikkan.
const kWatermarkReferenceShortSide = 720.0;

/// Faktor pengali ukuran watermark untuk foto berukuran [imageWidth] x
/// [imageHeight]: sisi pendek foto dibagi [kWatermarkReferenceShortSide],
/// dijepit 0,5-4 supaya foto sangat kecil/besar tidak menghasilkan ukuran
/// ekstrem.
double watermarkScaleFor(int imageWidth, int imageHeight) {
  final shortSide = imageWidth < imageHeight ? imageWidth : imageHeight;
  return (shortSide / kWatermarkReferenceShortSide).clamp(0.5, 4.0);
}

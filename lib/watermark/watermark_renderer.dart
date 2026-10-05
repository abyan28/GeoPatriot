import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../geocoding/address_formatter.dart';
import '../location/models/location_snapshot.dart';
import 'models/watermark_configuration.dart';
import 'models/watermark_data.dart';
import 'models/watermark_position.dart';

/// Watermark gagal dirender (mis. bytes foto sumber rusak/bukan gambar).
class WatermarkRenderException implements Exception {
  WatermarkRenderException(this.message);
  final String message;

  @override
  String toString() => 'WatermarkRenderException: $message';
}

/// Merender panel watermark (lokasi, alamat, koordinat, tanggal/waktu,
/// akurasi, thumbnail peta) ke atas foto sumber. Pure/semi-pure: hanya
/// menerima bytes gambar + data + konfigurasi, tidak melakukan HTTP,
/// tidak meminta GPS, tidak memanggil geocoder/map provider, tidak
/// mengubah application state global.
class WatermarkRenderer {
  static const _baseInnerPadding = 14;
  static const _jpegQuality = 90;

  /// Padding di dalam kotak lencana (badge) logo+nama aplikasi — lebih
  /// kecil dari `_innerPadding` panel utama karena badge memang dibuat
  /// ringkas ("tag" kecil), bukan sebesar panel info lokasi.
  static const _baseBadgePadding = 8;

  /// Berapa piksel kotak lencana logo+nama TUMPANG TINDIH ke kotak utama
  /// supaya terlihat "ditempelkan" (seperti label/tag), bukan sekadar
  /// mengambang terpisah dengan jarak kosong di antaranya.
  static const _baseBadgeOverlap = 6;

  /// Render watermark ke [sourceImageBytes] sesuai [config] dan [data].
  /// [appIconBytes] opsional (PNG/JPEG kecil) ditampilkan sebagai ikon
  /// aplikasi di KOTAK TERPISAH (lencana kecil) bersama
  /// [WatermarkConfiguration.appBrandingText], ditempelkan menempel ke sisi
  /// panel info lokasi (BUKAN bagian dari panel itu sendiri — supaya panel
  /// info tidak punya ruang kosong cuma gara-gara logo) — kalau
  /// null/gagal didekode, lencana tetap tampil tanpa ikon (teks saja).
  /// Mengembalikan bytes JPEG hasil akhir. Melempar
  /// [WatermarkRenderException] jika gambar sumber tidak dapat didekode.
  Uint8List render({
    required Uint8List sourceImageBytes,
    required WatermarkData data,
    required WatermarkConfiguration config,
    Uint8List? appIconBytes,
  }) {
    final source = img.decodeImage(sourceImageBytes);
    if (source == null) {
      throw WatermarkRenderException('Format gambar sumber tidak dikenali.');
    }

    // Normalisasi orientasi EXIF supaya piksel sesuai tampilan portrait/landscape asli.
    final oriented = img.bakeOrientation(source);

    // Semua ukuran watermark diskalakan terhadap resolusi foto (acuan 720 px
    // sisi pendek), supaya kotaknya tidak mengecil saat resolusi dinaikkan.
    final scale = watermarkScaleFor(oriented.width, oriented.height);
    return _renderOnImage(
      oriented,
      data: data,
      config: config.scaledBy(scale),
      appIconBytes: appIconBytes,
      scale: scale,
    );
  }

  /// Gambar watermark ke [oriented] memakai [config] yang SUDAH diskalakan
  /// dengan faktor [scale] (padding internal ikut dikalikan [scale]).
  Uint8List _renderOnImage(
    img.Image oriented, {
    required WatermarkData data,
    required WatermarkConfiguration config,
    required Uint8List? appIconBytes,
    required double scale,
  }) {
    final innerPadding = (_baseInnerPadding * scale).round();
    final badgePadding = (_baseBadgePadding * scale).round();
    final badgeOverlap = (_baseBadgeOverlap * scale).round();

    // Peta bersifat opsional: bytes yang tidak bisa didekode (bukan gambar
    // valid) cukup dilewati, tidak boleh menggagalkan seluruh foto.
    final mapImage = config.showMapThumbnail ? _decodeMapSafely(data) : null;
    final showThumbnail = mapImage != null;
    final entries = _buildTextLines(data, config, showMapAttribution: showThumbnail);
    final bodyFont = _fontFor(config.fontSize);
    final titleFont = _titleFontFor(bodyFont);

    final thumbnailSize = showThumbnail ? config.thumbnailSize.round() : 0;
    final thumbnailReservedWidth = showThumbnail ? thumbnailSize + config.spacing.round() : 0;
    final maxTextWidth = oriented.width - 2 * config.margin.round() - 2 * innerPadding - thumbnailReservedWidth;

    // Wrap tiap baris memakai font-nya sendiri (judul lebih besar dari body),
    // supaya batas karakter per baris sesuai lebar huruf yang sebenarnya dipakai.
    final rendered = entries.expand((entry) {
      final font = entry.isTitle ? titleFont : bodyFont;
      final maxChars = (maxTextWidth / _approxCharWidth(font)).floor().clamp(6, 200);
      return _wrapLine(entry.text, maxChars, entry.maxLines).map((line) => _RenderedLine(line, font));
    }).toList();

    // Box menyesuaikan lebar konten aktual (bukan dipaksa selebar foto),
    // dibatasi maksimum supaya tidak pernah melebihi lebar foto.
    final actualTextWidth = rendered.isEmpty
        ? 0
        : rendered.map((line) => (line.text.length * _approxCharWidth(line.font)).round()).reduce((a, b) => a > b ? a : b);
    final textBlockWidth = actualTextWidth.clamp(0, maxTextWidth);

    final lineHeights = rendered.map((line) => _lineHeightFor(line.font) + config.spacing.round()).toList();
    final textBlockHeight = lineHeights.fold<int>(0, (sum, height) => sum + height);
    final contentHeight = showThumbnail ? (thumbnailSize > textBlockHeight ? thumbnailSize : textBlockHeight) : textBlockHeight;
    final panelHeight = contentHeight + 2 * innerPadding;
    final panelWidth = thumbnailReservedWidth + textBlockWidth + 2 * innerPadding;

    final panelOrigin = _panelOrigin(
      imageWidth: oriented.width,
      imageHeight: oriented.height,
      panelWidth: panelWidth,
      panelHeight: panelHeight,
      margin: config.margin.round(),
      position: config.position,
    );

    _drawPanel(oriented, panelOrigin.dx, panelOrigin.dy, panelWidth, panelHeight, config);

    _drawBrandBadge(
      oriented,
      config: config,
      appIconBytes: appIconBytes,
      panelOrigin: panelOrigin,
      panelWidth: panelWidth,
      panelHeight: panelHeight,
      imageHeight: oriented.height,
      badgePadding: badgePadding,
      badgeOverlap: badgeOverlap,
    );

    var textX = panelOrigin.dx + innerPadding;
    final textY = panelOrigin.dy + innerPadding;

    if (showThumbnail) {
      final resizedMap = img.copyResize(
        mapImage,
        width: thumbnailSize,
        height: thumbnailSize,
      );
      final thumbY = panelOrigin.dy + (panelHeight - thumbnailSize) ~/ 2;
      img.compositeImage(oriented, resizedMap, dstX: textX, dstY: thumbY);
      textX += thumbnailReservedWidth;
    }

    var y = textY;
    for (var i = 0; i < rendered.length; i++) {
      img.drawString(
        oriented,
        rendered[i].text,
        font: rendered[i].font,
        x: textX,
        y: y,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      y += lineHeights[i];
    }

    return Uint8List.fromList(img.encodeJpg(oriented, quality: _jpegQuality));
  }

  /// Susun daftar baris teks watermark sesuai field yang diaktifkan di
  /// [config]. Baris kosong (field aktif tapi datanya tidak tersedia)
  /// dilewati, tidak pernah mengarang isi. Baris alamat ditandai boleh
  /// wrap sampai 2 baris karena secara alami paling berisiko panjang.
  /// Baris nama lokasi ditandai sebagai judul (font lebih besar).
  List<_WatermarkLine> _buildTextLines(
    WatermarkData data,
    WatermarkConfiguration config, {
    required bool showMapAttribution,
  }) {
    final lines = <_WatermarkLine>[];
    final address = data.address;
    final formatter = AddressFormatter();

    if (config.showLocationName && address != null) {
      final name = address.village ?? address.regency;
      if (name != null && name.isNotEmpty) lines.add(_WatermarkLine(name, isTitle: true));
    }

    if (config.showAddress) {
      if (address != null && !address.isEmpty) {
        final formatted = formatter.format(address, includeStreet: true, maxLength: 220);
        if (formatted.isNotEmpty) lines.add(_WatermarkLine(formatted, maxLines: 2));
      } else if (!config.showCoordinates) {
        // Offline fallback: alamat tidak tersedia dan koordinat tidak
        // ditampilkan terpisah, jadi tetap tampilkan koordinat di sini
        // supaya foto tidak kehilangan informasi lokasi sama sekali.
        lines.add(_WatermarkLine(_coordinatesText(data.location)));
      }
    }

    if (config.showCoordinates) {
      lines.add(_WatermarkLine(_coordinatesText(data.location)));
    }

    if (config.showDate) {
      lines.add(_WatermarkLine(DateFormat('dd MMM yyyy', 'id_ID').format(data.timestamp)));
    }

    if (config.showTime) {
      final time = DateFormat('HH:mm:ss', 'id_ID').format(data.timestamp);
      lines.add(_WatermarkLine(config.showTimezone ? '$time (${data.timeZoneName})' : time));
    }

    if (config.showAccuracy && data.location.accuracy != null) {
      final accuracy = data.location.accuracy!.round();
      lines.add(_WatermarkLine('Akurasi: ±$accuracy m (${data.location.accuracyCategory.label})'));
    }

    if (config.showAltitude && data.location.altitude != null) {
      lines.add(_WatermarkLine('Alt: ${data.location.altitude!.round()} m'));
    }

    if (config.customText != null && config.customText!.trim().isNotEmpty) {
      lines.add(_WatermarkLine(config.customText!.trim(), maxLines: 2));
    }

    // appBrandingText TIDAK lagi jadi baris teks biasa di sini — sekarang
    // jadi baris header terpisah di pojok kanan-atas panel, lihat `render()`.

    if (showMapAttribution) {
      lines.add(_WatermarkLine(data.map!.attributionText));
    }

    return lines;
  }

  /// Dekode bytes peta menjadi gambar, atau null jika tidak ada/rusak.
  img.Image? _decodeMapSafely(WatermarkData data) {
    final map = data.map;
    if (map == null) return null;
    try {
      return img.decodeImage(map.imageBytes);
    } catch (_) {
      return null;
    }
  }

  String _coordinatesText(LocationSnapshot location) {
    if (location.isPlaceholder) {
      return 'Mencari sinyal GPS...';
    }
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }

  /// Tentukan titik kiri-atas panel berdasarkan posisi yang dipilih.
  ({int dx, int dy}) _panelOrigin({
    required int imageWidth,
    required int imageHeight,
    required int panelWidth,
    required int panelHeight,
    required int margin,
    required WatermarkPosition position,
  }) {
    switch (position) {
      case WatermarkPosition.top:
        return (dx: (imageWidth - panelWidth) ~/ 2, dy: margin);
      case WatermarkPosition.bottom:
        return (dx: (imageWidth - panelWidth) ~/ 2, dy: imageHeight - margin - panelHeight);
      case WatermarkPosition.topLeft:
        return (dx: margin, dy: margin);
      case WatermarkPosition.topRight:
        return (dx: imageWidth - margin - panelWidth, dy: margin);
      case WatermarkPosition.bottomLeft:
        return (dx: margin, dy: imageHeight - margin - panelHeight);
      case WatermarkPosition.bottomRight:
        return (dx: imageWidth - margin - panelWidth, dy: imageHeight - margin - panelHeight);
    }
  }

  /// Gambar panel latar semi-transparan dengan sudut membulat sesuai
  /// [config].
  void _drawPanel(img.Image image, int x, int y, int width, int height, WatermarkConfiguration config) {
    final alpha = (config.opacity.clamp(0, 1) * 255).round();
    img.fillRect(
      image,
      x1: x,
      y1: y,
      x2: x + width,
      y2: y + height,
      color: img.ColorRgba8(0, 0, 0, alpha),
      radius: config.cornerRadius,
    );
  }

  /// Gambar kotak lencana (badge) kecil berisi ikon aplikasi + nama brand,
  /// ditempelkan menempel ke SISI panel info lokasi (bukan bagian dari
  /// panel itu) — meniru posisi logo di aplikasi referensi. Ditempel di
  /// sisi yang menjauhi tepi gambar terdekat (kalau panel dekat tepi atas,
  /// lencana ditempel di BAWAH panel; kalau panel dekat tepi bawah,
  /// lencana ditempel di ATAS panel), supaya lencananya tidak pernah
  /// terpotong keluar batas gambar apa pun posisi watermark yang dipilih.
  void _drawBrandBadge(
    img.Image image, {
    required WatermarkConfiguration config,
    required Uint8List? appIconBytes,
    required ({int dx, int dy}) panelOrigin,
    required int panelWidth,
    required int panelHeight,
    required int imageHeight,
    required int badgePadding,
    required int badgeOverlap,
  }) {
    final font = _fontFor(config.fontSize);
    final iconSize = (config.fontSize * 1.1).round();

    img.Image? icon;
    if (appIconBytes != null) {
      final decoded = img.decodeImage(appIconBytes);
      if (decoded != null) {
        icon = img.copyResize(decoded, width: iconSize, height: iconSize);
      }
    }

    final iconReservedWidth = icon != null ? iconSize + config.spacing.round() : 0;
    final textWidth = (config.appBrandingText.length * _approxCharWidth(font)).round();
    final rowWidth = iconReservedWidth + textWidth;
    final rowHeight = icon != null ? (iconSize > _lineHeightFor(font) ? iconSize : _lineHeightFor(font)) : _lineHeightFor(font);

    final badgeWidth = rowWidth + 2 * badgePadding;
    final badgeHeight = rowHeight + 2 * badgePadding;

    // Rata kanan terhadap panel utama, menempel di sisi yang menjauhi tepi
    // gambar terdekat (lihat dokumentasi method).
    final badgeX = (panelOrigin.dx + panelWidth - badgeWidth).clamp(0, image.width - badgeWidth);
    final attachAbovePanel = panelOrigin.dy > (imageHeight / 2);
    final badgeY = attachAbovePanel
        ? (panelOrigin.dy - badgeHeight + badgeOverlap).clamp(0, image.height - badgeHeight)
        : (panelOrigin.dy + panelHeight - badgeOverlap).clamp(0, image.height - badgeHeight);

    _drawPanel(image, badgeX, badgeY, badgeWidth, badgeHeight, config);

    final rowX = badgeX + badgePadding;
    final rowY = badgeY + badgePadding;
    if (icon != null) {
      final iconY = rowY + (rowHeight - iconSize) ~/ 2;
      img.compositeImage(image, icon, dstX: rowX, dstY: iconY);
    }
    final textY = rowY + (rowHeight - _lineHeightFor(font)) ~/ 2;
    img.drawString(
      image,
      config.appBrandingText,
      font: font,
      x: rowX + iconReservedWidth,
      y: textY,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
  }

  /// Pilih bitmap font bawaan `image` package yang paling mendekati ukuran
  /// font yang diminta konfigurasi.
  img.BitmapFont _fontFor(double fontSize) {
    // Ambang di tengah (geometrik) antar ukuran bitmap 14/24/48 karena
    // [fontSize] sudah diskalakan terhadap resolusi foto.
    if (fontSize <= 18) return img.arial14;
    if (fontSize <= 34) return img.arial24;
    return img.arial48;
  }

  /// Font untuk baris judul (nama lokasi): satu tingkat lebih besar dari
  /// font body, meniru hierarki visual referensi GPS Map Camera.
  img.BitmapFont _titleFontFor(img.BitmapFont bodyFont) {
    if (bodyFont == img.arial14) return img.arial24;
    return img.arial48;
  }

  int _lineHeightFor(img.BitmapFont font) {
    if (font == img.arial48) return 52;
    if (font == img.arial24) return 28;
    return 18;
  }

  /// Perkiraan lebar rata-rata satu karakter untuk font ini, dipakai untuk
  /// membatasi panjang baris tanpa perlu mengukur setiap teks secara presisi.
  double _approxCharWidth(img.BitmapFont font) {
    if (font == img.arial48) return 26;
    if (font == img.arial24) return 13;
    return 8;
  }

  /// Potong teks yang lebih panjang dari [maxChars], menambahkan elipsis
  /// supaya tidak keluar dari panel.
  String _truncateToWidth(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 1)}…';
  }

  /// Pecah [text] jadi maksimal [maxLines] baris, memutus pada batas kata
  /// jika memungkinkan (bukan di tengah kata). Baris terakhir dipotong
  /// dengan elipsis jika teks masih tersisa setelah [maxLines] baris.
  List<String> _wrapLine(String text, int maxChars, int maxLines) {
    if (text.length <= maxChars || maxLines <= 1) {
      return [_truncateToWidth(text, maxChars)];
    }

    final result = <String>[];
    var remaining = text;
    while (remaining.isNotEmpty && result.length < maxLines) {
      final isLastAllowedLine = result.length == maxLines - 1;
      if (remaining.length <= maxChars || isLastAllowedLine) {
        result.add(_truncateToWidth(remaining, maxChars));
        remaining = '';
      } else {
        final breakIndex = _lastWordBreak(remaining, maxChars);
        result.add(remaining.substring(0, breakIndex).trimRight());
        remaining = remaining.substring(breakIndex).trimLeft();
      }
    }
    return result;
  }

  /// Cari indeks pemutusan kata terbaik di dalam [maxChars] karakter
  /// pertama, jatuh kembali ke pemutusan karakter jika tidak ada spasi
  /// yang wajar.
  int _lastWordBreak(String text, int maxChars) {
    final slice = text.substring(0, maxChars);
    final lastSpace = slice.lastIndexOf(' ');
    return lastSpace > (maxChars * 0.4).round() ? lastSpace : maxChars;
  }
}

/// Satu baris teks watermark sebelum di-wrap, dengan jumlah maksimum baris
/// yang diizinkan setelah wrap (kebanyakan field pendek cukup 1 baris;
/// alamat/teks custom boleh sampai 2 baris) dan apakah ini baris judul
/// (font lebih besar).
class _WatermarkLine {
  const _WatermarkLine(this.text, {this.maxLines = 1, this.isTitle = false});

  final String text;
  final int maxLines;
  final bool isTitle;
}

/// Satu baris yang sudah di-wrap dan siap digambar, dengan font final-nya.
class _RenderedLine {
  const _RenderedLine(this.text, this.font);

  final String text;
  final img.BitmapFont font;
}

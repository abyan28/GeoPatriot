import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../geocoding/address_formatter.dart';
import '../geocoding/models/address_snapshot.dart';
import '../location/models/location_snapshot.dart';
import '../settings/settings_controller.dart';
import '../watermark/models/watermark_configuration.dart';
import '../watermark/models/watermark_position.dart';
import 'device_rotation_controller.dart';
import 'edge_anchored_rotated.dart';

/// Padding dalam panel watermark hasil foto akhir (`WatermarkRenderer._innerPadding`),
/// dipakai sebagai acuan supaya padding panel live proporsional dengan hasil akhir.
const _finalInnerPadding = 14.0;

/// Pengali tambahan untuk `previewScale`. `previewScale` sudah memetakan
/// ukuran watermark (acuan sisi pendek foto 720 px) ke logical pixel layar,
/// jadi tidak perlu kalibrasi lagi: 1.0. (Dulu 1.8, kalibrasi empiris yang
/// diam-diam menutup selisih lebar foto 720 vs sisi panjang preview 1280 pada
/// resolusi 720p; nilainya sama dengan perilaku lama dalam ±1,3%.)
const _liveScaleCalibration = 1.0;

/// Lebar maksimum panel saat portrait (device tidak dimiringkan) — dipilih
/// pas untuk lebar layar portrait, JANGAN diubah (sudah dikonfirmasi user
/// pas apa adanya).
const _portraitMaxWidth = 320.0;

/// Proporsi tinggi area preview yang dipakai sebagai lebar maksimum panel
/// SAAT LANDSCAPE (device dimiringkan 90°). Karena panel diputar sebagai
/// satu blok (`RotatedBox`), lebar panel SEBELUM diputar menjadi tinggi
/// visualnya SESUDAH diputar — ruang yang tersedia untuk "melebar" saat
/// landscape sebenarnya jauh lebih lega (setinggi layar portrait), bukan
/// dibatasi lebar layar portrait yang sempit (~320) seperti saat portrait.
/// Melebarkan ini membuat baris teks (terutama alamat) tidak perlu
/// menumpuk jadi banyak baris.
const _landscapeMaxWidthFraction = 0.62;

/// Padding di dalam kotak lencana (badge) logo+nama aplikasi — lebih kecil
/// dari padding panel utama karena badge memang dibuat ringkas ("tag"
/// kecil), meniru `WatermarkRenderer._badgePadding`.
const _badgeInnerPadding = 8.0;

/// Berapa logical pixel kotak lencana TUMPANG TINDIH ke panel utama supaya
/// terlihat "ditempelkan" (seperti label/tag), bukan mengambang terpisah
/// dengan jarak kosong — meniru `WatermarkRenderer._badgeOverlap`.
const _badgeOverlap = 6.0;

/// Overlay watermark LIVE di atas viewfinder, sebelum shutter ditekan.
/// Dirender dengan widget Flutter biasa (bukan `WatermarkRenderer` yang
/// berbasis `image` package), jadi tidak identik piksel-demi-piksel dengan
/// hasil akhir, tapi cukup merepresentasikan tata letak/isi supaya
/// pengguna tahu kira-kira hasilnya sebelum memotret.
class LiveWatermarkOverlay extends StatelessWidget {
  const LiveWatermarkOverlay({
    super.key,
    required this.location,
    required this.address,
    required this.mapThumbnailBytes,
    required this.previewScale,
    required this.previewAreaSize,
    this.timestampOverride,
    this.topClearance = 0,
    this.bottomClearance = 0,
  });

  final LocationSnapshot? location;
  final AddressSnapshot? address;
  final Uint8List? mapThumbnailBytes;

  /// Ukuran area preview kamera (dari `LayoutBuilder` di `_CameraBody`),
  /// dipakai untuk menghitung lebar maksimum panel saat landscape (lihat
  /// `_landscapeMaxWidthFraction`).
  final Size previewAreaSize;

  /// Jarak tambahan dari tepi ATAS/BAWAH frame preview untuk watermark yang
  /// jatuh di sisi fisik tersebut, supaya tidak tumpang-tindih dengan HUD
  /// atas (pill GPS + tombol pengaturan) atau baris tombol bawah (galeri +
  /// shutter + switch kamera). Dihitung pemanggil dari seberapa jauh kontrol
  /// itu benar-benar menjorok ke dalam frame preview. Overlay ini harus
  /// ditempatkan di dalam `Stack` yang berukuran sama dengan frame preview.
  final double topClearance;

  /// Waktu manual (lihat `ManualOverride`); null berarti pakai jam perangkat.
  final DateTime? timestampOverride;
  final double bottomClearance;

  /// Faktor skala dari "1 piksel resolusi asli kamera" ke "1 logical pixel
  /// di layar" (lihat `_CameraBody._previewScale`). Dikalikan ke semua
  /// ukuran berbasis `WatermarkConfiguration` supaya panel live sebanding
  /// secara proporsi dengan panel watermark pada hasil foto akhir, bukan
  /// memakai angka konfigurasi yang sama mentah-mentah (yang didesain untuk
  /// gambar beresolusi tinggi, sehingga akan terlihat jauh lebih besar di
  /// preview kecil).
  final double previewScale;

  /// Bangun panel watermark live sesuai konfigurasi watermark aktif saat
  /// ini, diposisikan sesuai `config.position`.
  @override
  Widget build(BuildContext context) {
    final location = this.location;
    if (location == null) return const SizedBox.shrink();

    final config = context.watch<SettingsController>().settings.watermark;
    final quarterTurns = context.watch<DeviceRotationController>().quarterTurns;
    final isLandscape = quarterTurns.isOdd;

    final scale = previewScale * _liveScaleCalibration;
    final fontSize = config.fontSize * scale;
    final spacing = config.spacing * scale;
    final cornerRadius = config.cornerRadius * scale;
    final margin = config.margin * scale;
    final innerPadding = _finalInnerPadding * scale;
    final maxWidth = isLandscape ? previewAreaSize.height * _landscapeMaxWidthFraction : _portraitMaxWidth;

    // Batasi thumbnail supaya TIDAK PERNAH lebih besar dari ruang yang
    // tersisa di dalam `maxWidth` (dikurangi padding & spacing) — sebelum
    // ini, thumbnail dihitung independen dari `maxWidth` sehingga pada
    // kalibrasi ukuran yang besar, thumbnail sendirian bisa hampir/melebihi
    // `maxWidth`, membuat baris (thumbnail + teks) meluber keluar kotak
    // (indikator overflow kuning-hitam Flutter di mode debug).
    final maxContentWidth = maxWidth - 2 * innerPadding;
    final maxThumbnailSize = ((maxContentWidth - spacing) * 0.5).clamp(0.0, double.infinity);
    final thumbnailSize = (config.thumbnailSize * scale).clamp(0.0, maxThumbnailSize);

    final lines = _buildLines(
      config,
      location,
      address,
      now: timestampOverride ?? DateTime.now(),
      fontSize: fontSize,
      spacing: spacing,
    );
    final showThumbnail = config.showMapThumbnail && mapThumbnailBytes != null;

    final panel = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: EdgeInsets.all(innerPadding),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: config.opacity.clamp(0, 1)),
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showThumbnail) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6 * scale),
              child: Image.memory(
                mapThumbnailBytes!,
                width: thumbnailSize,
                height: thumbnailSize,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: spacing),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines,
            ),
          ),
        ],
      ),
    );

    // Kotak lencana (badge) TERPISAH dari panel utama — ikon aplikasi kecil
    // + nama aplikasi, ditempelkan menempel ke sisi panel (bukan bagian
    // dari panel), meniru posisi logo di aplikasi referensi. Ditempel di
    // sisi yang menjauhi tepi layar terdekat (kalau panel di atas, badge
    // ditempel di BAWAH panel; kalau panel di bawah, badge ditempel di ATAS
    // panel) lewat `Transform.translate` supaya sedikit tumpang tindih
    // ("ditempelkan"), tanpa menambah ruang kosong di panel utama.
    final badgeIconSize = fontSize * 1.1;
    final badgePadding = _badgeInnerPadding * scale;
    final badge = Container(
      padding: EdgeInsets.all(badgePadding),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: config.opacity.clamp(0, 1)),
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3 * scale),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: badgeIconSize,
              height: badgeIconSize,
            ),
          ),
          SizedBox(width: spacing),
          Text(
            config.appBrandingText,
            style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    final isTopPosition = _isTop(config.position);
    final overlap = _badgeOverlap * scale;
    // Transform.translate murni pergeseran visual saat digambar, TIDAK
    // mengubah ukuran layout — badge tetap dianggap seukuran aslinya oleh
    // Column, cuma "dilukis" bergeser supaya tumpang-tindih ke panel.
    final translatedBadge = Transform.translate(
      offset: Offset(0, isTopPosition ? -overlap : overlap),
      child: badge,
    );

    // PENTING: crossAxisAlignment.end (BUKAN stretch) — `stretch` memaksa
    // Column mengambil lebar PENUH area yang tersedia (karena constraint
    // dari `Center` di pemanggil bersifat longgar-tak-terbatas), lalu
    // memaksa `panel` ikut selebar itu juga, MENGABAIKAN `maxWidth: 320`
    // milik `panel` sendiri (constraint ketat dari parent selalu menang
    // atas `maxWidth` yang dideklarasikan child) — itu sebabnya kotak
    // watermark live sempat jadi selebar layar. `end` cuma merapatkan
    // badge ke sisi kanan lebar Column (yang mengikuti lebar `panel`,
    // elemen terlebar), tanpa memaksa ukuran siapa pun.
    final panelWithBadge = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: isTopPosition ? [panel, translatedBadge] : [translatedBadge, panel],
    );

    // Posisi tengah (top/bottom, kasus default): pakai EdgeAnchoredRotated
    // supaya sisi yang ditempeli ikut menyesuaikan saat device dimiringkan
    // (misal watermark tetap tampak di BAWAH dari sudut pandang pengguna,
    // bukan cuma menempel di tepi fisik bawah HP yang berpindah makna saat
    // landscape), sekaligus mencegah bug ukuran panel membesar tegas
    // selebar/setinggi layar saat kontennya ditukar orientasi.
    if (config.position == WatermarkPosition.top ||
        config.position == WatermarkPosition.bottom) {
      return EdgeAnchoredRotated(
        targetEdge: config.position == WatermarkPosition.top
            ? ScreenEdge.top
            : ScreenEdge.bottom,
        quarterTurns: quarterTurns,
        margin: margin,
        // Cuma dipakai kalau sisi target ini memang berakhir di fisik-atas
        // / fisik-bawah (lihat `EdgeAnchoredRotated`).
        extraTopMargin: topClearance,
        extraBottomMargin: bottomClearance,
        child: panelWithBadge,
      );
    }

    // Posisi sudut (topLeft/topRight/bottomLeft/bottomRight): tetap menempel
    // di sudut fisik yang sama, cuma kontennya yang berputar di tempat.
    return Positioned(
      top: _isTop(config.position) ? margin + topClearance : null,
      bottom: _isTop(config.position) ? null : margin + bottomClearance,
      left: _isRightAligned(config.position) ? null : margin,
      right: _isRightAligned(config.position) ? margin : null,
      child: RotatedBox(quarterTurns: quarterTurns, child: panelWithBadge),
    );
  }

  bool _isTop(WatermarkPosition position) {
    return position == WatermarkPosition.top ||
        position == WatermarkPosition.topLeft ||
        position == WatermarkPosition.topRight;
  }

  bool _isRightAligned(WatermarkPosition position) {
    return position == WatermarkPosition.topRight ||
        position == WatermarkPosition.bottomRight;
  }

  /// Susun baris teks live sesuai field yang diaktifkan, meniru urutan
  /// `WatermarkRenderer._buildTextLines` supaya preview konsisten dengan
  /// hasil akhir. [fontSize]/[spacing] sudah dikalikan `previewScale`.
  List<Widget> _buildLines(
    WatermarkConfiguration config,
    LocationSnapshot location,
    AddressSnapshot? address, {
    required DateTime now,
    required double fontSize,
    required double spacing,
  }) {
    final widgets = <Widget>[];
    final formatter = AddressFormatter();
    final bodyStyle = TextStyle(color: Colors.white, fontSize: fontSize);
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: fontSize * 1.3,
      fontWeight: FontWeight.bold,
    );

    // maxLines dibatasi meniru `WatermarkRenderer._buildTextLines` — baris
    // alamat/custom text boleh sampai 2 baris (paling berisiko panjang),
    // baris lain cukup 1. Tanpa batas ini, teks bisa menumpuk jadi banyak
    // baris pada font besar (lihat `_liveScaleCalibration`), bikin panel
    // jadi sangat tinggi.
    void addLine(String text, {bool isTitle = false, int maxLines = 1}) {
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Text(
            text,
            style: isTitle ? titleStyle : bodyStyle,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (config.showLocationName && address != null) {
      final name = address.village ?? address.regency;
      if (name != null && name.isNotEmpty) addLine(name, isTitle: true);
    }

    if (config.showAddress) {
      if (address != null && !address.isEmpty) {
        final formatted = formatter.format(
          address,
          includeStreet: true,
          maxLength: 220,
        );
        if (formatted.isNotEmpty) addLine(formatted, maxLines: 2);
      } else if (!config.showCoordinates) {
        addLine(_coordinatesText(location));
      }
    }

    if (config.showCoordinates) addLine(_coordinatesText(location));
    if (config.showDate) {
      addLine(DateFormat('dd MMM yyyy', 'id_ID').format(now));
    }
    if (config.showTime) {
      final time = DateFormat('HH:mm:ss', 'id_ID').format(now);
      addLine(config.showTimezone ? '$time (${now.timeZoneName})' : time);
    }
    if (config.showAccuracy && location.accuracy != null) {
      addLine(
        'Akurasi: ±${location.accuracy!.round()} m (${location.accuracyCategory.label})',
      );
    }
    if (config.showAltitude && location.altitude != null) {
      addLine('Alt: ${location.altitude!.round()} m');
    }
    if (config.customText != null && config.customText!.trim().isNotEmpty) {
      addLine(config.customText!.trim(), maxLines: 2);
    }
    // appBrandingText TIDAK lagi jadi baris teks biasa di sini — sekarang
    // jadi baris header terpisah di pojok kanan-atas panel, lihat `headerRow`.

    return widgets;
  }

  String _coordinatesText(LocationSnapshot location) {
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }
}

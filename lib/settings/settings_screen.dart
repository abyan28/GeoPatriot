import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/camera_tokens.dart';
import '../watermark/models/watermark_configuration.dart';
import '../watermark/models/watermark_position.dart';
import '../watermark/models/watermark_template.dart';
import 'settings_controller.dart';

/// Layar pengaturan watermark dan aplikasi: template, pratinjau langsung,
/// field visibility, posisi, appearance slider, dan opsi penyimpanan.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();

    if (!controller.isLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengaturan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final watermark = controller.settings.watermark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        actions: [
          IconButton(
            tooltip: 'Kembalikan setelan awal',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => _confirmReset(context, controller),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // --- PRATINJAU LANGSUNG ---
          _SectionHeader('Pratinjau Watermark'),
          _LiveWatermarkPreview(watermark: watermark),
          const SizedBox(height: 16),

          // --- TEMPLATE ---
          _SectionHeader('Template Cepat'),
          _TemplatePicker(controller: controller),
          const SizedBox(height: 16),

          // --- INFORMASI YANG DITAMPILKAN ---
          _SectionHeader('Informasi Lapangan'),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Nama lokasi'),
                  subtitle: const Text('Desa / Kelurahan / Kecamatan'),
                  value: watermark.showLocationName,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showLocationName: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Alamat lengkap'),
                  subtitle: const Text('Jalan, nomor, dan wilayah administratif'),
                  value: watermark.showAddress,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showAddress: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Koordinat'),
                  subtitle: const Text('Latitude & Longitude GPS'),
                  value: watermark.showCoordinates,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showCoordinates: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Tanggal'),
                  value: watermark.showDate,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showDate: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Waktu'),
                  value: watermark.showTime,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showTime: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Zona waktu'),
                  subtitle: const Text('Contoh: WIB / WITA / WIT'),
                  value: watermark.showTimezone,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showTimezone: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Akurasi GPS'),
                  subtitle: const Text('Radius akurasi dalam meter'),
                  value: watermark.showAccuracy,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showAccuracy: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Ketinggian (Altitude)'),
                  subtitle: const Text('Elevasi di atas permukaan laut (meter)'),
                  value: watermark.showAltitude,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showAltitude: value)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Thumbnail peta'),
                  subtitle: const Text('Peta mini penunjuk lokasi'),
                  value: watermark.showMapThumbnail,
                  onChanged: (value) => controller.updateWatermark((c) => c.copyWith(showMapThumbnail: value)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- POSISI WATERMARK ---
          _SectionHeader('Posisi Watermark'),
          _PositionPicker(controller: controller),
          const SizedBox(height: 16),

          // --- TAMPILAN & UKURAN ---
          _SectionHeader('Tampilan & Ukuran'),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _SliderSetting(
                    label: 'Transparansi panel',
                    value: watermark.opacity,
                    min: 0.1,
                    max: 1.0,
                    labelFormatter: (value) => '${(value * 100).round()}%',
                    onChanged: (value) => controller.updateWatermark((c) => c.copyWith(opacity: value)),
                  ),
                  const Divider(height: 16),
                  _SliderSetting(
                    label: 'Ukuran teks',
                    value: watermark.fontSize,
                    min: 10,
                    max: 32,
                    onChanged: (value) => controller.updateWatermark((c) => c.copyWith(fontSize: value)),
                  ),
                  if (watermark.showMapThumbnail) ...[
                    const Divider(height: 16),
                    _SliderSetting(
                      label: 'Ukuran thumbnail peta',
                      value: watermark.thumbnailSize,
                      min: 60,
                      max: 180,
                      onChanged: (value) => controller.updateWatermark((c) => c.copyWith(thumbnailSize: value)),
                    ),
                    const Divider(height: 16),
                    _SliderSetting(
                      label: 'Zoom peta',
                      value: watermark.mapZoom.toDouble(),
                      min: 12,
                      max: 19,
                      divisions: 7,
                      onChanged: (value) => controller.updateWatermark((c) => c.copyWith(mapZoom: value.round())),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- CATATAN TAMBAHAN ---
          _SectionHeader('Catatan Lapangan'),
          _CustomTextInput(
            initialValue: watermark.customText ?? '',
            onChanged: (value) => controller.updateWatermark(
              (c) => c.copyWith(customText: value.trim().isEmpty ? null : value.trim()),
            ),
          ),
          const SizedBox(height: 16),

          // --- PENYIMPANAN & RESET ---
          _SectionHeader('Penyimpanan & Sistem'),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Simpan foto asli'),
                  subtitle: const Text('Foto tanpa watermark tetap disimpan terpisah ke galeri'),
                  value: controller.settings.saveOriginal,
                  onChanged: controller.setSaveOriginal,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: const Text('Kembalikan ke Setelan Awal'),
                  subtitle: const Text('Reset seluruh pengaturan watermark ke bawaan'),
                  onTap: () => _confirmReset(context, controller),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, SettingsController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Pengaturan?'),
        content: const Text('Seluruh konfigurasi watermark akan dikembalikan ke setelan awal pabrik.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.resetToDefaults();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: CameraTokens.brandOchreLight,
          fontSize: 14,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Kartu pratinjau live yang menampilkan simulasi visual watermark di atas
/// contoh foto kamera secara reaktif.
class _LiveWatermarkPreview extends StatelessWidget {
  const _LiveWatermarkPreview({required this.watermark});

  final WatermarkConfiguration watermark;

  @override
  Widget build(BuildContext context) {
    final isTop = watermark.position == WatermarkPosition.top ||
        watermark.position == WatermarkPosition.topLeft ||
        watermark.position == WatermarkPosition.topRight;

    final isLeft = watermark.position == WatermarkPosition.topLeft ||
        watermark.position == WatermarkPosition.bottomLeft;
    final isRight = watermark.position == WatermarkPosition.topRight ||
        watermark.position == WatermarkPosition.bottomRight;

    Alignment alignment;
    if (watermark.position == WatermarkPosition.top) {
      alignment = Alignment.topCenter;
    } else if (watermark.position == WatermarkPosition.bottom) {
      alignment = Alignment.bottomCenter;
    } else if (isTop && isLeft) {
      alignment = Alignment.topLeft;
    } else if (isTop && isRight) {
      alignment = Alignment.topRight;
    } else if (!isTop && isLeft) {
      alignment = Alignment.bottomLeft;
    } else {
      alignment = Alignment.bottomRight;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: CameraTokens.navyBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CameraTokens.petrolBlue.withValues(alpha: 0.45), width: 1.2),
        ),
        child: Stack(
          children: [
            // Latar simulasi viewfinder foto
            Positioned.fill(
              child: Opacity(
                opacity: 0.20,
                child: Center(
                  child: Icon(
                    Icons.landscape_outlined,
                    size: 80,
                    color: CameraTokens.brandOchre.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            // Panel watermark simulasi
            Align(
              alignment: alignment,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CameraTokens.navySurface.withValues(alpha: watermark.opacity.clamp(0.4, 1.0)),
                    borderRadius: BorderRadius.circular(watermark.cornerRadius.clamp(4, 16)),
                    border: Border.all(
                      color: CameraTokens.petrolBlue.withValues(alpha: 0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (watermark.showMapThumbnail) ...[
                        Container(
                          width: (watermark.thumbnailSize * 0.35).clamp(32.0, 56.0),
                          height: (watermark.thumbnailSize * 0.35).clamp(32.0, 56.0),
                          decoration: BoxDecoration(
                            color: CameraTokens.navyPrimary,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: CameraTokens.petrolBlue.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          child: const Icon(Icons.map_outlined, size: 20, color: CameraTokens.brandOchreLight),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (watermark.showLocationName)
                              const Text(
                                'Menteng, Jakarta Pusat',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (watermark.showAddress)
                              Text(
                                'Jl. M.H. Thamrin No. 1, DKI Jakarta',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (watermark.showCoordinates)
                              const Text(
                                '-6.195412, 106.823145',
                                style: TextStyle(
                                  color: CameraTokens.telemetryCyan,
                                  fontSize: 9,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (watermark.showDate || watermark.showTime)
                              Text(
                                '${watermark.showDate ? '15 Sep 2026' : ''} ${watermark.showTime ? '14:00:25' : ''}${watermark.showTimezone ? ' (WIB)' : ''}'
                                    .trim(),
                                style: const TextStyle(
                                  color: CameraTokens.brandOchreLight,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (watermark.showAccuracy)
                              Text(
                                'Akurasi: ±4 m (Sangat baik)',
                                style: TextStyle(
                                  color: CameraTokens.gpsExcellent,
                                  fontSize: 8,
                                ),
                              ),
                            if (watermark.showAltitude)
                              Text(
                                'Ketinggian: 18 m',
                                style: TextStyle(
                                  color: CameraTokens.telemetryCyan.withValues(alpha: 0.85),
                                  fontSize: 8,
                                ),
                              ),
                            if (watermark.customText != null && watermark.customText!.isNotEmpty)
                              Text(
                                watermark.customText!,
                                style: const TextStyle(
                                  color: CameraTokens.brandOchreLight,
                                  fontSize: 8,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.activeTemplate;

    return Wrap(
      spacing: 8,
      children: WatermarkTemplate.values.map((template) {
        final isSelected = current == template;
        return ChoiceChip(
          label: Text(template.label),
          labelStyle: TextStyle(
            color: isSelected ? CameraTokens.navyBackground : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          selected: isSelected,
          selectedColor: CameraTokens.brandOchre,
          backgroundColor: CameraTokens.navySurface,
          side: BorderSide(
            color: isSelected
                ? CameraTokens.brandOchreLight
                : CameraTokens.petrolBlue.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (_) => controller.applyTemplate(template),
        );
      }).toList(),
    );
  }
}

class _PositionPicker extends StatelessWidget {
  const _PositionPicker({required this.controller});

  final SettingsController controller;

  static const _labels = {
    WatermarkPosition.top: 'Atas Penuh',
    WatermarkPosition.bottom: 'Bawah Penuh',
    WatermarkPosition.topLeft: 'Kiri Atas',
    WatermarkPosition.topRight: 'Kanan Atas',
    WatermarkPosition.bottomLeft: 'Kiri Bawah',
    WatermarkPosition.bottomRight: 'Kanan Bawah',
  };

  @override
  Widget build(BuildContext context) {
    final current = controller.settings.watermark.position;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: WatermarkPosition.values.map((position) {
        final isSelected = current == position;
        return ChoiceChip(
          label: Text(_labels[position]!),
          labelStyle: TextStyle(
            color: isSelected ? CameraTokens.navyBackground : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          selected: isSelected,
          selectedColor: CameraTokens.brandOchre,
          backgroundColor: CameraTokens.navySurface,
          side: BorderSide(
            color: isSelected
                ? CameraTokens.brandOchreLight
                : CameraTokens.petrolBlue.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (_) => controller.updateWatermark((c) => c.copyWith(position: position)),
        );
      }).toList(),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  const _SliderSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.labelFormatter,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final String Function(double value)? labelFormatter;

  @override
  Widget build(BuildContext context) {
    final formattedValue = labelFormatter?.call(value) ?? value.round().toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
              Text(
                formattedValue,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: CameraTokens.brandOchreLight,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: CameraTokens.brandOchre,
            inactiveColor: CameraTokens.petrolBlue.withValues(alpha: 0.3),
            thumbColor: CameraTokens.brandOchreLight,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CustomTextInput extends StatefulWidget {
  const _CustomTextInput({required this.initialValue, required this.onChanged});

  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  State<_CustomTextInput> createState() => _CustomTextInputState();
}

class _CustomTextInputState extends State<_CustomTextInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _CustomTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Catatan tambahan watermark',
        labelStyle: const TextStyle(color: Colors.white70),
        hintText: 'Misal: Tim Survey 1 / Inspeksi Proyek A',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        filled: true,
        fillColor: CameraTokens.navyBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CameraTokens.petrolBlue.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: CameraTokens.petrolBlue.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CameraTokens.brandOchre, width: 1.5),
        ),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 20, color: Colors.white70),
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
              )
            : null,
      ),
      onChanged: widget.onChanged,
    );
  }
}

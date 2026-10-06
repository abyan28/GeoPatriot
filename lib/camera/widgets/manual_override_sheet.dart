import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/camera_tokens.dart';
import '../../capture/manual_override.dart';

/// Bottom sheet untuk mengisi koordinat dan/atau waktu secara manual.
/// Ditutup dengan [ManualOverride] baru ("Terapkan"), [ManualOverride] kosong
/// ("Kembali ke otomatis"), atau null (dismiss tanpa perubahan).
class ManualOverrideSheet extends StatefulWidget {
  const ManualOverrideSheet({
    super.key,
    this.initial,
    this.title = 'Input Koordinat & Waktu Manual',
    this.description = 'Isi koordinat atau waktu bila berada di area tanpa sinyal GPS. '
        'Kosongkan untuk kembali memakai sensor GPS dan jam perangkat.',
    this.resetLabel = 'Kembali ke Otomatis',
  });

  final ManualOverride? initial;
  final String title;
  final String description;
  final String resetLabel;

  @override
  State<ManualOverrideSheet> createState() => _ManualOverrideSheetState();
}

class _ManualOverrideSheetState extends State<ManualOverrideSheet> {
  late final TextEditingController _coordinates;
  DateTime? _timestamp;
  String? _coordinatesError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _coordinates = TextEditingController(
      text: initial != null && initial.hasCoordinates ? '${initial.latitude}, ${initial.longitude}' : '',
    );
    _timestamp = initial?.timestamp;
  }

  @override
  void dispose() {
    _coordinates.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final base = _timestamp ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: CameraTokens.brandOchre,
              surface: CameraTokens.navySurface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _timestamp = DateTime(picked.year, picked.month, picked.day, base.hour, base.minute));
  }

  Future<void> _pickTime() async {
    final base = _timestamp ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: CameraTokens.brandOchre,
              surface: CameraTokens.navySurface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _timestamp = DateTime(base.year, base.month, base.day, picked.hour, picked.minute));
  }

  void _apply() {
    final text = _coordinates.text.trim();
    CoordinatePair? pair;
    if (text.isNotEmpty) {
      pair = parseCoordinatePair(text);
      if (pair == null) {
        setState(() => _coordinatesError = 'Format harus "lat, lon" (lat -90..90, lon -180..180).');
        return;
      }
    }
    Navigator.of(context).pop(
      ManualOverride(latitude: pair?.latitude, longitude: pair?.longitude, timestamp: _timestamp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timestamp = _timestamp;
    return Container(
      decoration: const BoxDecoration(
        color: CameraTokens.navySurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CameraTokens.navyBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CameraTokens.brandOchre.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.edit_location_alt_outlined, color: CameraTokens.brandOchre, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _coordinates,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Koordinat (lat, lon)',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: '-6.208800, 106.845600',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                errorText: _coordinatesError,
                filled: true,
                fillColor: CameraTokens.navyBackground,
                prefixIcon: const Icon(Icons.pin_drop_outlined, color: CameraTokens.telemetryCyan, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: CameraTokens.petrolBlue.withValues(alpha: 0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: CameraTokens.petrolBlue.withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: CameraTokens.brandOchre, width: 1.5),
                ),
              ),
              onChanged: (_) {
                if (_coordinatesError != null) setState(() => _coordinatesError = null);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: CameraTokens.navyBackground,
                      side: BorderSide(color: CameraTokens.petrolBlue.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16, color: CameraTokens.brandOchre),
                    label: Text(
                      timestamp == null ? 'Tanggal' : DateFormat('dd MMM yyyy', 'id_ID').format(timestamp),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: CameraTokens.navyBackground,
                      side: BorderSide(color: CameraTokens.petrolBlue.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.schedule, size: 16, color: CameraTokens.brandOchreLight),
                    label: Text(
                      timestamp == null ? 'Jam' : DateFormat('HH:mm').format(timestamp),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
            if (timestamp != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _timestamp = null),
                  icon: const Icon(Icons.refresh, size: 14, color: CameraTokens.brandOchre),
                  label: const Text('Pakai waktu sekarang', style: TextStyle(color: CameraTokens.brandOchre, fontSize: 12)),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const ManualOverride()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(widget.resetLabel, style: const TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: CameraTokens.brandOchre,
                      foregroundColor: CameraTokens.navyBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Terapkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


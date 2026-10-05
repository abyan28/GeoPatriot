import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../capture/manual_override.dart';

/// Bottom sheet untuk mengisi koordinat dan/atau waktu secara manual.
/// Ditutup dengan [ManualOverride] baru ("Terapkan"), [ManualOverride] kosong
/// ("Kembali ke otomatis"), atau null (dismiss tanpa perubahan).
class ManualOverrideSheet extends StatefulWidget {
  const ManualOverrideSheet({
    super.key,
    this.initial,
    this.title = 'Input manual',
    this.description = 'Kosongkan koordinat/waktu untuk tetap memakai GPS dan jam perangkat. '
        'Berlaku untuk foto berikutnya sampai app ditutup.',
    this.resetLabel = 'Kembali ke otomatis',
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
    );
    if (picked == null) return;
    setState(() => _timestamp = DateTime(picked.year, picked.month, picked.day, base.hour, base.minute));
  }

  Future<void> _pickTime() async {
    final base = _timestamp ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              widget.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _coordinates,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Koordinat (lat, lon)',
                hintText: '-9.589109, 124.871050',
                errorText: _coordinatesError,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_coordinatesError != null) setState(() => _coordinatesError = null);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(timestamp == null ? 'Tanggal' : DateFormat('dd MMM yyyy', 'id_ID').format(timestamp)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(timestamp == null ? 'Jam' : DateFormat('HH:mm').format(timestamp)),
                  ),
                ),
              ],
            ),
            if (timestamp != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _timestamp = null),
                  child: const Text('Pakai waktu sekarang'),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(const ManualOverride()),
                    child: Text(widget.resetLabel),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: _apply, child: const Text('Terapkan')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

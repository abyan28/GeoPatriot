import 'package:flutter/material.dart';

import '../../core/theme/camera_tokens.dart';
import '../../survey/survey_controller.dart';

/// Buka sheet pengisian objek survei. Mengembalikan true bila disimpan.
Future<bool> showSurveyObjectSheet(BuildContext context, SurveyController survey) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => SurveyObjectSheet(survey: survey),
  );
  return saved ?? false;
}

/// Sheet untuk mengisi objek (rumah/penduduk), kode pembeda opsional, dan
/// lokasi SP. Field objek langsung fokus supaya keyboard terbuka seketika.
class SurveyObjectSheet extends StatefulWidget {
  const SurveyObjectSheet({super.key, required this.survey});

  final SurveyController survey;

  @override
  State<SurveyObjectSheet> createState() => _SurveyObjectSheetState();
}

class _SurveyObjectSheetState extends State<SurveyObjectSheet> {
  late final TextEditingController _object;
  late final TextEditingController _code;
  late final TextEditingController _location;
  String? _error;

  @override
  void initState() {
    super.initState();
    _object = TextEditingController(text: widget.survey.objectName);
    _code = TextEditingController(text: widget.survey.objectCode);
    _location = TextEditingController(text: widget.survey.locationName);
  }

  @override
  void dispose() {
    _object.dispose();
    _code.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_object.text.trim().isEmpty || _location.text.trim().isEmpty) {
      setState(() => _error = 'Nama objek dan lokasi SP wajib diisi.');
      return;
    }
    await widget.survey.setLocation(_location.text);
    await widget.survey.setObject(_object.text, code: _code.text);
    if (widget.survey.previewBaseName == null) {
      setState(() => _error = 'Nama tidak valid, gunakan huruf atau angka.');
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  InputDecoration _decoration(String label, {String? hint, IconData? icon}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: CameraTokens.petrolBlue.withValues(alpha: 0.4)),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
      filled: true,
      fillColor: CameraTokens.navyBackground,
      prefixIcon: icon == null ? null : Icon(icon, color: CameraTokens.telemetryCyan, size: 20),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CameraTokens.brandOchre, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = widget.survey.recentObjects;
    return Container(
      decoration: const BoxDecoration(
        color: CameraTokens.navySurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Objek Survei',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Nama objek (rumah/penduduk) dipakai sebagai awalan nama file. '
              'Isi kode bila ada nama yang sama dalam satu lokasi.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _object,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Nama objek', hint: 'mis. Budi', icon: Icons.home_work_outlined),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final name in recent)
                    ActionChip(
                      label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: CameraTokens.navyBackground,
                      side: BorderSide(color: CameraTokens.petrolBlue.withValues(alpha: 0.5)),
                      onPressed: () => setState(() {
                        _object.text = name;
                        _object.selection = TextSelection.collapsed(offset: name.length);
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Kode (opsional)', hint: 'mis. no. rumah 12', icon: Icons.tag),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              textInputAction: TextInputAction.done,
              style: const TextStyle(color: Colors.white),
              decoration: _decoration('Lokasi / SP', hint: 'mis. SP3 Kapitanmeo', icon: Icons.location_city_outlined),
              onSubmitted: (_) => _save(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: CameraTokens.brandOchre,
                foregroundColor: CameraTokens.navyBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/camera_tokens.dart';
import '../../survey/survey_controller.dart';
import 'survey_object_sheet.dart';

/// Tinggi area strip survei (di atas baris shutter) menurut orientasi, dipakai
/// layar kamera untuk menghitung clearance live watermark dan zoom ruler.
double surveyStripHeight({required bool landscape}) => landscape ? 168 : 112;

/// Strip Mode Survei di atas tombol shutter: objek aktif, kategori, pratinjau
/// nama file, dan tombol "Objek berikutnya". Tiap chip diputar di tempat
/// (RotatedBox) mengikuti orientasi device, pola yang sama dengan kontrol HUD.
class SurveyStrip extends StatelessWidget {
  const SurveyStrip({super.key, required this.quarterTurns});

  final int quarterTurns;

  Widget _rotate(Widget child) => RotatedBox(quarterTurns: quarterTurns, child: child);

  @override
  Widget build(BuildContext context) {
    final survey = context.watch<SurveyController>();
    final landscape = quarterTurns.isOdd;
    final hasObject = survey.objectName.isNotEmpty;
    final category = survey.selectedCategory;

    return Container(
      height: surveyStripHeight(landscape: landscape),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _rotate(
                    _ObjectChip(
                      objectName: survey.objectName,
                      code: survey.objectCode,
                      locationName: survey.locationName,
                      onTap: () => showSurveyObjectSheet(context, survey),
                    ),
                  ),
                ),
              ),
              if (hasObject)
                _rotate(
                  TextButton.icon(
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      survey.nextObject();
                      await showSurveyObjectSheet(context, survey);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: CameraTokens.hudBackground,
                      foregroundColor: CameraTokens.brandOchreLight,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.skip_next_rounded, size: 18),
                    label: const Text('Objek berikutnya', style: TextStyle(fontSize: 12)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: landscape ? 92 : 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: survey.categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = survey.categories[index];
                final selected = item.id == category?.id;
                return _rotate(
                  ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    label: Text(item.label),
                    avatar: item.applyWatermark ? null : const Icon(Icons.description_outlined, size: 14),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? CameraTokens.navyBackground : Colors.white,
                    ),
                    selectedColor: CameraTokens.brandOchre,
                    backgroundColor: CameraTokens.hudBackground,
                    side: BorderSide(color: selected ? CameraTokens.brandOchreLight : CameraTokens.hudBorder),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      survey.selectCategory(item.id);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: _rotate(
              Text(
                survey.previewFileName ?? 'Isi objek dan lokasi untuk mulai',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: survey.previewFileName == null ? Colors.orangeAccent : Colors.white70,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectChip extends StatelessWidget {
  const _ObjectChip({
    required this.objectName,
    required this.code,
    required this.locationName,
    required this.onTap,
  });

  final String objectName;
  final String code;
  final String locationName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = objectName.isEmpty;
    final title = empty ? 'Isi nama objek' : (code.isEmpty ? objectName : '$objectName · $code');
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: empty ? Colors.orange.withValues(alpha: 0.9) : CameraTokens.hudBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: empty ? Colors.orangeAccent : CameraTokens.brandOchre, width: 1.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              empty ? Icons.edit_outlined : Icons.home_work_outlined,
              size: 18,
              color: empty ? CameraTokens.navyBackground : CameraTokens.brandOchre,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: empty ? CameraTokens.navyBackground : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (locationName.isNotEmpty)
                    Text(
                      locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: empty ? CameraTokens.navyBackground.withValues(alpha: 0.8) : Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

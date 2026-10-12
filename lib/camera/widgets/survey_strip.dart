import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/camera_tokens.dart';
import '../../survey/models/survey_category.dart';
import '../../survey/survey_controller.dart';
import 'survey_object_sheet.dart';

/// Tinggi area kontrol kategori di atas baris shutter.
/// Dipakai layar kamera untuk menghitung clearance Live Watermark.
double surveyStripHeight({required bool landscape}) => landscape ? 0.0 : 64.0;

/// Pemetaan ikon kategori survei.
IconData surveyCategoryIcon(SurveyCategory category) {
  switch (category.id) {
    case 'rumah':
      return Icons.home_outlined;
    case 'lahan':
      return Icons.terrain_outlined;
    case 'kk':
      return Icons.family_restroom_outlined;
    case 'shm':
    case 'dokumen-lain':
      return Icons.description_outlined;
    case 'sarpras':
      return Icons.apartment_outlined;
    case 'barang':
      return Icons.inventory_2_outlined;
    default:
      return category.applyWatermark ? Icons.label_outline : Icons.description_outlined;
  }
}

/// Header objek survei untuk mode PORTRAIT:
/// Terletak di baris kedua atas tepat di bawah Top HUD agar nama panjang
/// (misal "Muhammad Abyan Dzaka · Kapitan Meo") terbaca penuh tanpa terpotong.
class SurveyObjectHeader extends StatelessWidget {
  const SurveyObjectHeader({super.key, required this.survey});

  final SurveyController survey;

  @override
  Widget build(BuildContext context) {
    final hasObject = survey.objectName.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SurveyObjectChip(survey: survey),
            ),
          ),
          if (hasObject) ...[
            const SizedBox(width: 8),
            SurveyNextObjectButton(survey: survey),
          ],
        ],
      ),
    );
  }
}

/// Kolom objek survei ringkas untuk mode LANDSCAPE:
/// Diletakkan di rel kiri pandangan pengguna (celah antara Pill GPS dan tombol upload foto).
/// Berbatas lebar (maxWidth ~130) agar tidak meluber keluar area baris HUD saat diputar.
class SurveyObjectInline extends StatelessWidget {
  const SurveyObjectInline({super.key, required this.survey});

  final SurveyController survey;

  @override
  Widget build(BuildContext context) {
    final hasObject = survey.objectName.isNotEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SurveyObjectChip(survey: survey, compact: true),
        if (hasObject) ...[
          const SizedBox(width: 4),
          SurveyNextObjectButton(survey: survey, compact: true),
        ],
      ],
    );
  }
}

/// Kontrol Kategori Kamera Bergaya Samsung One UI:
/// - **Status Idle (Tertutup)**: Kapsul ringkas mengambang `[ 🏷️ <Nama Kategori> ▾ ]`
///   + pratinjau nama file di bawahnya. Viewfinder luas dan hemat ruang layar hingga 70%.
/// - **Status Expanded (Terbuka)**: Slider horizontal mengambang berisi chip pilihan
///   kategori `[ Lahan ] [ Rumah* ] [ KK ] [ KTP ] [ SHM ] ... [ ✕ ]`.
/// - Memilih kategori langsung mengubah status & nama file, lalu menutup kembali.
class SurveyCategorySlider extends StatefulWidget {
  const SurveyCategorySlider({
    super.key,
    required this.survey,
    this.quarterTurns = 0,
    this.isLandscape = false,
  });

  final SurveyController survey;
  final int quarterTurns;
  final bool isLandscape;

  @override
  State<SurveyCategorySlider> createState() => _SurveyCategorySliderState();
}

class _SurveyCategorySliderState extends State<SurveyCategorySlider> {
  bool _isExpanded = false;

  void _toggle(bool expanded) {
    HapticFeedback.selectionClick();
    setState(() => _isExpanded = expanded);
  }

  @override
  Widget build(BuildContext context) {
    final survey = widget.survey;
    final category = survey.selectedCategory;
    if (category == null) return const SizedBox.shrink();

    final landscape = widget.isLandscape || widget.quarterTurns.isOdd;
    final fileName = survey.previewFileName;

    return Center(
      child: RotatedBox(
        quarterTurns: widget.quarterTurns,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.90, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: _isExpanded
              ? _CategorySlider(
                  key: const ValueKey('survey-category-slider-expanded'),
                  survey: survey,
                  fileName: landscape ? null : fileName,
                  onClose: () => _toggle(false),
                  onSelect: (id) {
                    survey.selectCategory(id);
                    _toggle(false);
                  },
                )
              : _CategoryPill(
                  key: const ValueKey('survey-category-pill-collapsed'),
                  category: category,
                  fileName: landscape ? null : fileName,
                  isLandscape: landscape,
                  onTap: () => _toggle(true),
                ),
        ),
      ),
    );
  }
}

/// Kapsul Kategori saat Tertutup (Idle):
/// Menampilkan ikon kategori aktif + nama kategori aktif + tanda panah ekspansi.
/// Pada mode portrait mengarah ke kanan, pada mode landscape mengarah ke kiri (arah slider).
class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    super.key,
    required this.category,
    this.fileName,
    this.isLandscape = false,
    required this.onTap,
  });

  final SurveyCategory category;
  final String? fileName;
  final bool isLandscape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clean = !category.applyWatermark;
    final accent = clean ? CameraTokens.telemetryCyan : CameraTokens.brandOchre;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: CameraTokens.hudBackground.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent, width: 1.3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(surveyCategoryIcon(category), size: 16, color: accent),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isLandscape ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
        if (fileName != null) ...[
          const SizedBox(height: 4),
          Text(
            fileName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: CameraTokens.brandOchreLight,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

/// Slider Kategori saat Terbuka (Expanded):
/// Menampilkan seluruh pilihan kategori dalam kapsul horizontal mengambang + tombol `✕`.
class _CategorySlider extends StatelessWidget {
  const _CategorySlider({
    super.key,
    required this.survey,
    this.fileName,
    required this.onClose,
    required this.onSelect,
  });

  final SurveyController survey;
  final String? fileName;
  final VoidCallback onClose;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final selectedId = survey.selectedCategory?.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 380),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: CameraTokens.hudBackground.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: CameraTokens.hudBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in survey.categories) ...[
                    _SliderChip(
                      item: item,
                      selected: item.id == selectedId,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelect(item.id);
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
          Container(width: 1, height: 22, color: CameraTokens.hudBorder),
          IconButton(
            tooltip: 'Tutup',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
            onPressed: onClose,
          ),
        ],
      ),
    ),
    if (fileName != null) ...[
      const SizedBox(height: 4),
      Text(
        fileName!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: CameraTokens.brandOchreLight,
          fontSize: 11,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ],
);
  }
}

class _SliderChip extends StatelessWidget {
  const _SliderChip({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SurveyCategory item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final clean = !item.applyWatermark;
    final accent = clean ? CameraTokens.telemetryCyan : CameraTokens.brandOchre;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? accent : CameraTokens.hudBorder,
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              surveyCategoryIcon(item),
              size: 15,
              color: selected ? CameraTokens.navyBackground : accent,
            ),
            const SizedBox(width: 5),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? CameraTokens.navyBackground : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip objek aktif: oranye jika kosong, kapsul elegan jika terisi.
class SurveyObjectChip extends StatelessWidget {
  const SurveyObjectChip({
    super.key,
    required this.survey,
    this.compact = false,
  });

  final SurveyController survey;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final objectName = survey.objectName;
    final code = survey.objectCode;
    final locationName = survey.locationName;
    final empty = objectName.isEmpty;
    final title = empty ? 'Isi nama objek' : (code.isEmpty ? objectName : '$objectName · $code');

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showSurveyObjectSheet(context, survey);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 96 : 240),
        height: compact ? 36 : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: empty ? Colors.orange.withValues(alpha: 0.9) : CameraTokens.hudBackground,
          borderRadius: BorderRadius.circular(compact ? 18 : 12),
          border: Border.all(
            color: empty ? Colors.orangeAccent : CameraTokens.brandOchre,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              empty ? Icons.edit_outlined : Icons.home_work_outlined,
              size: compact ? 15 : 16,
              color: empty ? CameraTokens.navyBackground : CameraTokens.brandOchre,
            ),
            const SizedBox(width: 5),
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
                      fontSize: compact ? 12 : 13,
                    ),
                  ),
                  if (locationName.isNotEmpty && !compact)
                    Text(
                      locationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: empty
                            ? CameraTokens.navyBackground.withValues(alpha: 0.8)
                            : Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            if (compact) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: empty ? CameraTokens.navyBackground : Colors.white70,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tombol "Objek berikutnya". Versi compact (ikon saja) untuk landscape celah HUD.
class SurveyNextObjectButton extends StatelessWidget {
  const SurveyNextObjectButton({
    super.key,
    required this.survey,
    this.compact = false,
  });

  final SurveyController survey;
  final bool compact;

  Future<void> _onPressed(BuildContext context) async {
    HapticFeedback.selectionClick();
    survey.nextObject();
    await showSurveyObjectSheet(context, survey);
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Objek berikutnya',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        style: IconButton.styleFrom(
          backgroundColor: CameraTokens.hudBackground,
          side: BorderSide(color: CameraTokens.hudBorder, width: 1.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.skip_next_rounded, size: 16, color: CameraTokens.brandOchreLight),
        onPressed: () => _onPressed(context),
      );
    }

    return TextButton.icon(
      onPressed: () => _onPressed(context),
      style: TextButton.styleFrom(
        backgroundColor: CameraTokens.hudBackground,
        foregroundColor: CameraTokens.brandOchreLight,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: CameraTokens.hudBorder, width: 1.1),
        ),
      ),
      icon: const Icon(Icons.skip_next_rounded, size: 18),
      label: const Text(
        'Objek berikutnya',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Alias backward compatibility jika ada file lain yang memanggil SurveyCategoryControl / SurveyStrip.
class SurveyCategoryControl extends StatelessWidget {
  const SurveyCategoryControl({
    super.key,
    required this.survey,
    this.quarterTurns = 0,
  });

  final SurveyController survey;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return SurveyCategorySlider(survey: survey, quarterTurns: quarterTurns);
  }
}

class SurveyStrip extends StatelessWidget {
  const SurveyStrip({super.key, required this.quarterTurns});

  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    final survey = context.read<SurveyController>();
    return SurveyCategorySlider(survey: survey, quarterTurns: quarterTurns);
  }
}

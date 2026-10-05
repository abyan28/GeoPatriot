import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../camera/widgets/manual_override_sheet.dart';
import '../capture/manual_override.dart';
import '../capture/photo_import_service.dart';
import '../capture/watermark_publisher.dart';
import '../geocoding/cached_geocoding_provider.dart';
import '../geocoding/locationiq_geocoding_provider.dart';
import '../location/models/location_snapshot.dart';
import '../map/cached_map_thumbnail_provider.dart';
import '../map/locationiq_map_thumbnail_provider.dart';
import '../settings/settings_controller.dart';
import '../storage/photo_storage_service.dart';
import 'models/history_entry.dart';
import 'photo_history_service.dart';

/// Layar riwayat foto: gallery grid dari [PhotoHistoryService], dengan
/// detail (swipe antar-foto, pinch-to-zoom), share, delete, dan pilih-banyak.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  final _historyService = PhotoHistoryService();
  final _storageService = PhotoStorageService();

  List<HistoryEntry>? _entries;
  final Set<String> _selectedBaseNames = {};

  bool get _isSelecting => _selectedBaseNames.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEntries();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Foto bisa dihapus lewat Galeri bawaan saat app di background, jadi
  /// sinkronkan ulang daftar setiap app kembali aktif.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadEntries();
  }

  /// Muat ulang daftar riwayat foto dari index lokal, membuang entri yang
  /// fotonya sudah tidak ada di penyimpanan.
  Future<void> _loadEntries() async {
    final entries = await _historyService.pruneMissing(await _historyService.loadAll());
    if (!mounted) return;
    setState(() {
      _entries = entries;
      final names = entries.map((e) => e.baseName).toSet();
      _selectedBaseNames.removeWhere((name) => !names.contains(name));
    });
  }

  /// Masuk/toggle mode pilih-banyak lewat tekan-tahan atau tombol pilih.
  void _toggleSelection(HistoryEntry entry) {
    setState(() {
      if (_selectedBaseNames.contains(entry.baseName)) {
        _selectedBaseNames.remove(entry.baseName);
      } else {
        _selectedBaseNames.add(entry.baseName);
      }
    });
  }

  void _cancelSelection() {
    setState(_selectedBaseNames.clear);
  }

  /// Hapus semua foto yang sedang dipilih di mode pilih-banyak.
  Future<void> _deleteSelected() async {
    final confirmed = await _confirmDelete(count: _selectedBaseNames.length);
    if (confirmed != true) return;

    for (final baseName in _selectedBaseNames) {
      await _storageService.deleteByBaseName(baseName);
      await _historyService.remove(baseName);
    }
    _selectedBaseNames.clear();
    await _loadEntries();
  }

  Future<bool?> _confirmDelete({required int count}) {
    final message = count == 1
        ? 'Foto asli dan foto ber-watermark akan dihapus permanen.'
        : '$count foto (foto asli dan foto ber-watermark) akan dihapus permanen.';
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(count == 1 ? 'Hapus foto ini?' : 'Hapus $count foto ini?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  /// Bagikan semua foto yang sedang dipilih sekaligus lewat satu share sheet.
  Future<void> _shareSelected() async {
    final entries = _entries ?? [];
    final files = entries
        .where((entry) => _selectedBaseNames.contains(entry.baseName))
        .map((entry) => XFile(entry.processedPath))
        .toList();
    if (files.isEmpty) return;
    await Share.shareXFiles(files);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    return Scaffold(
      appBar: _isSelecting ? _buildSelectionAppBar() : _buildNormalAppBar(entries),
      body: entries == null
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const _EmptyHistory()
              : RefreshIndicator(
                  onRefresh: _loadEntries,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final selected = _selectedBaseNames.contains(entry.baseName);
                      return _HistoryThumbnail(
                        entry: entry,
                        selected: selected,
                        selectionMode: _isSelecting,
                        onTap: () => _isSelecting ? _toggleSelection(entry) : _openDetail(entries, index),
                        onLongPress: () => _toggleSelection(entry),
                      );
                    },
                  ),
                ),
    );
  }

  AppBar _buildNormalAppBar(List<HistoryEntry>? entries) {
    return AppBar(
      title: const Text('Riwayat Foto'),
      actions: [
        IconButton(
          tooltip: 'Tambah watermark dari galeri',
          icon: const Icon(Icons.add_photo_alternate_outlined),
          onPressed: _addFromGallery,
        ),
        if (entries != null && entries.isNotEmpty)
          TextButton.icon(
            onPressed: () => _toggleSelection(entries.first),
            icon: const Icon(Icons.checklist, size: 18),
            label: const Text('Pilih'),
          ),
      ],
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        tooltip: 'Batal pilih',
        icon: const Icon(Icons.close),
        onPressed: _cancelSelection,
      ),
      title: Text('${_selectedBaseNames.length} dipilih'),
      actions: [
        IconButton(tooltip: 'Bagikan', icon: const Icon(Icons.share_outlined), onPressed: _shareSelected),
        IconButton(tooltip: 'Hapus', icon: const Icon(Icons.delete_outline), onPressed: _deleteSelected),
      ],
    );
  }

  /// Beri watermark pada foto-foto yang dipilih dari galeri HP. Koordinat
  /// dan waktu diambil dari EXIF masing-masing foto; nilai yang diisi di
  /// sheet menggantikannya untuk semua foto yang dipilih. Foto tanpa
  /// koordinat (EXIF kosong dan tidak diisi manual) dilewati.
  Future<void> _addFromGallery() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isEmpty || !mounted) return;

    final settings = context.read<SettingsController>();
    final importer = PhotoImportService(
      storageService: _storageService,
      publisher: WatermarkPublisher(
        storageService: _storageService,
        geocodingProvider: CachedGeocodingProvider(LocationIqGeocodingProvider()),
        mapThumbnailProvider: CachedMapThumbnailProvider(LocationIqMapThumbnailProvider()),
        historyService: _historyService,
        watermarkConfigProvider: () => settings.settings.watermark,
      ),
    );

    final firstExif = await importer.readExif(picked.first.path);
    if (!mounted) return;
    final hasFirstCoords = firstExif.latitude != null && firstExif.longitude != null;
    final manual = await showModalBottomSheet<ManualOverride>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ManualOverrideSheet(
        initial: ManualOverride(
          latitude: hasFirstCoords ? firstExif.latitude : null,
          longitude: hasFirstCoords ? firstExif.longitude : null,
          timestamp: firstExif.capturedAt,
        ),
        title: 'Tambah watermark (${picked.length} foto)',
        description: 'Koordinat dan waktu yang diisi berlaku untuk SEMUA foto yang dipilih. '
            'Kosongkan untuk memakai data EXIF masing-masing foto; foto tanpa koordinat dilewati.',
        resetLabel: 'Pakai data EXIF',
      ),
    );
    if (manual == null || !mounted) return;

    final progress = ValueNotifier<int>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, done, _) => Row(
              children: [
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                const SizedBox(width: 16),
                Expanded(child: Text('Memproses ${done + 1 > picked.length ? picked.length : done + 1} dari ${picked.length}...')),
              ],
            ),
          ),
        ),
      ),
    );

    var succeeded = 0;
    var skipped = 0;
    var failed = 0;
    for (final file in picked) {
      try {
        final exif = await importer.readExif(file.path);
        final latitude = manual.latitude ?? exif.latitude;
        final longitude = manual.longitude ?? exif.longitude;
        if (latitude == null || longitude == null) {
          skipped++;
        } else {
          final timestamp = manual.timestamp ?? exif.capturedAt ?? await importer.fileModifiedAt(file.path);
          await importer.importPhoto(
            sourcePath: file.path,
            location: LocationSnapshot(
              latitude: latitude,
              longitude: longitude,
              accuracy: null,
              capturedAt: timestamp,
            ),
            timestamp: timestamp,
          );
          succeeded++;
        }
      } catch (e) {
        debugPrint('Gagal memproses foto galeri: $e');
        failed++;
      }
      progress.value++;
    }
    progress.dispose();

    if (!mounted) return;
    Navigator.of(context).pop();
    await _loadEntries();
    if (!mounted) return;
    final parts = [
      '$succeeded foto berhasil',
      if (skipped > 0) '$skipped dilewati (tanpa koordinat)',
      if (failed > 0) '$failed gagal',
    ];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parts.join(', '))));
  }

  /// Buka layar detail mulai dari foto ke-[initialIndex], dengan seluruh
  /// [entries] supaya bisa swipe kiri/kanan pindah foto tanpa kembali ke grid.
  void _openDetail(List<HistoryEntry> entries, int initialIndex) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _HistoryDetailScreen(entries: entries, initialIndex: initialIndex),
      ),
    );
    // Foto mungkin dihapus selagi di layar detail — muat ulang supaya grid selalu sinkron.
    await _loadEntries();
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 56, color: Theme.of(context).hintColor),
            const SizedBox(height: 16),
            Text('Belum ada foto', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            const Text(
              'Foto ber-watermark yang Anda ambil akan tersimpan dan tampil di sini.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryThumbnail extends StatelessWidget {
  const _HistoryThumbnail({
    required this.entry,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  final HistoryEntry entry;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(entry.processedPath),
              fit: BoxFit.cover,
              cacheWidth: 400,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.white54),
                ),
              ),
            ),
          ),
          if (selectionMode)
            Positioned(
              top: 6,
              right: 6,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: selected ? Theme.of(context).colorScheme.primary : Colors.black.withValues(alpha: 0.5),
                child: Icon(
                  selected ? Icons.check : Icons.circle_outlined,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Layar detail foto: `PageView` supaya bisa swipe kiri/kanan pindah foto,
/// dengan `InteractiveViewer` untuk pinch-to-zoom foto & membaca watermark detail.
class _HistoryDetailScreen extends StatefulWidget {
  const _HistoryDetailScreen({required this.entries, required this.initialIndex});

  final List<HistoryEntry> entries;
  final int initialIndex;

  @override
  State<_HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<_HistoryDetailScreen> with WidgetsBindingObserver {
  final _historyService = PhotoHistoryService();
  final _storageService = PhotoStorageService();
  late final PageController _pageController;
  late List<HistoryEntry> _entries;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.entries);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  /// Foto yang sedang dilihat bisa dihapus lewat Galeri bawaan saat app di
  /// background: buang entri yang filenya hilang begitu app kembali aktif.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _dropMissingEntries();
  }

  Future<void> _dropMissingEntries() async {
    final currentName = _entries.isEmpty ? null : _current.baseName;
    final kept = await _historyService.pruneMissing(List.of(_entries));
    if (!mounted || kept.length == _entries.length) return;
    if (kept.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final index = kept.indexWhere((e) => e.baseName == currentName);
    setState(() {
      _entries = kept;
      _currentIndex = index >= 0 ? index : _currentIndex.clamp(0, kept.length - 1);
    });
    _pageController.jumpToPage(_currentIndex);
  }

  HistoryEntry get _current => _entries[_currentIndex];

  Future<void> _share() async {
    await Share.shareXFiles([XFile(_current.processedPath)]);
  }

  /// Tampilkan detail (tanggal/koordinat/alamat) lewat modal bottom sheet,
  /// dengan tombol salin koordinat cepat ke clipboard.
  void _showInfo() {
    final entry = _current;
    final formattedDate = DateFormat('dd MMMM yyyy, HH:mm:ss', 'id_ID').format(entry.timestamp);
    final coordText = '${entry.latitude.toStringAsFixed(6)}, ${entry.longitude.toStringAsFixed(6)}';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Informasi Lokasi & Foto', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Waktu Pengambilan'),
                subtitle: Text(formattedDate),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Koordinat GPS'),
                subtitle: Text(coordText),
                trailing: IconButton(
                  tooltip: 'Salin Koordinat',
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: coordText));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Koordinat disalin ke clipboard')),
                    );
                  },
                ),
              ),
              if (entry.addressText != null && entry.addressText!.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Alamat Terdata'),
                  subtitle: Text(entry.addressText!),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Hapus foto yang sedang tampil.
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus foto ini?'),
        content: const Text('Foto asli dan foto ber-watermark akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final entry = _current;
    await _storageService.deleteByBaseName(entry.baseName);
    await _historyService.remove(entry.baseName);
    if (!mounted) return;

    final deletedIndex = _currentIndex;
    setState(() {
      _entries.removeAt(deletedIndex);
      if (_entries.isNotEmpty && _currentIndex >= _entries.length) {
        _currentIndex = _entries.length - 1;
      }
    });

    if (_entries.isEmpty) {
      Navigator.of(context).pop();
    } else {
      _pageController.jumpToPage(_currentIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          children: [
            Text(
              'Foto ${_currentIndex + 1} dari ${_entries.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(_current.timestamp),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Info foto', icon: const Icon(Icons.info_outline), onPressed: _showInfo),
          IconButton(tooltip: 'Bagikan', icon: const Icon(Icons.share_outlined), onPressed: _share),
          IconButton(tooltip: 'Hapus', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: _entries.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.file(
                File(_entries[index].processedPath),
                fit: BoxFit.contain,
                cacheWidth: 1600,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, size: 48, color: Colors.white38),
                        SizedBox(height: 12),
                        Text('Foto tidak ditemukan di penyimpanan.', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

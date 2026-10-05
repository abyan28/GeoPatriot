import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/camera_tokens.dart';

/// Bar kontrol bawah kamera ergonomis untuk satu tangan:
/// [Thumbnail Galeri Cepat] <---> [Tombol Rana] <---> [Tombol Ganti Kamera].
class CameraBottomBar extends StatelessWidget {
  const CameraBottomBar({
    super.key,
    required this.cameraReady,
    required this.busy,
    required this.hasMultipleCameras,
    required this.lastCapturedFile,
    this.quarterTurns = 0,
    required this.onShutterPressed,
    required this.onSwitchCamera,
    required this.onOpenGallery,
  });

  final bool cameraReady;
  final bool busy;
  final bool hasMultipleCameras;
  final File? lastCapturedFile;
  final int quarterTurns;
  final VoidCallback onShutterPressed;
  final VoidCallback onSwitchCamera;
  final VoidCallback onOpenGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. AKSES GALERI CEPAT (Kiri)
          _QuickGalleryButton(
            lastCapturedFile: lastCapturedFile,
            quarterTurns: quarterTurns,
            onTap: onOpenGallery,
          ),

          // 2. TOMBOL SHUTTER BESAR (Tengah)
          _ShutterButton(
            busy: busy,
            onPressed: cameraReady ? onShutterPressed : null,
          ),

          // 3. GANTI KAMERA (Kanan)
          if (hasMultipleCameras)
            IconButton(
              tooltip: 'Ganti kamera',
              iconSize: 28,
              color: Colors.white,
              style: IconButton.styleFrom(
                backgroundColor: CameraTokens.hudBackground,
                side: BorderSide(color: CameraTokens.hudBorder, width: 1),
                padding: const EdgeInsets.all(14),
              ),
              icon: RotatedBox(
                quarterTurns: quarterTurns,
                child: const Icon(Icons.cameraswitch_outlined),
              ),
              onPressed: onSwitchCamera,
            )
          else
            const SizedBox(width: 56),
        ],
      ),
    );
  }
}

class _QuickGalleryButton extends StatelessWidget {
  const _QuickGalleryButton({
    required this.lastCapturedFile,
    required this.quarterTurns,
    required this.onTap,
  });

  final File? lastCapturedFile;
  final int quarterTurns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final file = lastCapturedFile;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: CameraTokens.hudBackground,
          shape: BoxShape.circle,
          border: Border.all(color: CameraTokens.hudBorder, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: RotatedBox(
          quarterTurns: quarterTurns,
          child: file != null && file.existsSync()
              ? Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: 160,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
                )
              : const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatefulWidget {
  const _ShutterButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.busy && widget.onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy ? 'Sedang memproses foto' : 'Ambil foto',
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _isDown = true) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _isDown = false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: enabled ? () => setState(() => _isDown = false) : null,
        child: AnimatedScale(
          scale: _isDown ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: CameraTokens.shutterRing, width: 4),
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isDown ? CameraTokens.shutterPressed : CameraTokens.shutterInner,
              ),
              child: widget.busy
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

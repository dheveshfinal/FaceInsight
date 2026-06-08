// ==============================================================
//  camera_capture_web.dart  — Web-only implementation
//  Embeds a <video> element via HtmlElementView + getUserMedia.
//  Captures a frame to <canvas> and returns it as XFile bytes.
// ==============================================================

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert' show base64;

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';

// ── Shared video element ────────────────────────────────────────

html.VideoElement? _videoEl;
html.MediaStream? _stream;
bool _registered = false;
final String _viewId = 'fi-camera-feed';

void _ensureRegistered() {
  if (_registered) return;
  _registered = true;

  _videoEl = html.VideoElement()
    ..autoplay = true
    ..muted = true
    ..setAttribute('playsinline', 'true')
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'cover'
    ..style.transform = 'scaleX(-1)'; // mirror for selfie feel

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    _viewId,
    (int id) => _videoEl!,
  );
}

Future<void> _startCamera() async {
  try {
    _stream = await html.window.navigator.mediaDevices!.getUserMedia({
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      },
      'audio': false,
    });
    _videoEl?.srcObject = _stream;
    await _videoEl?.play();
  } catch (e) {
    debugPrint('Camera start error: $e');
    rethrow;
  }
}

void _stopCamera() {
  _stream?.getTracks().forEach((t) => t.stop());
  _stream = null;
  if (_videoEl != null) {
    _videoEl!.srcObject = null;
  }
}

/// Capture current frame from video element, return as XFile
Future<XFile> _captureFrame() async {
  final video = _videoEl;
  if (video == null) throw Exception('Camera not initialized');

  final w = video.videoWidth;
  final h = video.videoHeight;
  if (w == 0 || h == 0) throw Exception('Camera not ready yet, try again');

  final canvas = html.CanvasElement(width: w, height: h);
  final ctx = canvas.context2D;

  // Un-mirror the CSS transform so the captured image is natural
  ctx.translate(w.toDouble(), 0);
  ctx.scale(-1, 1);
  ctx.drawImage(video, 0, 0);

  final dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
  final b64 = dataUrl.split(',').last;
  final bytes = base64.decode(b64);

  return XFile.fromData(
    bytes,
    name: 'face_${DateTime.now().millisecondsSinceEpoch}.jpg',
    mimeType: 'image/jpeg',
  );
}

// ── Camera feed widget ─────────────────────────────────────────

class CameraFeedWidget extends StatefulWidget {
  final void Function(XFile? xfile) onCapture;
  final void Function(String msg) onStatusChange;
  final void Function(bool) onCapturing;

  const CameraFeedWidget({
    super.key,
    required this.onCapture,
    required this.onStatusChange,
    required this.onCapturing,
  });

  @override
  State<CameraFeedWidget> createState() => _CameraFeedWidgetState();
}

class _CameraFeedWidgetState extends State<CameraFeedWidget> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ensureRegistered();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _init();
    });
  }

  Future<void> _init() async {
    widget.onStatusChange('Starting camera…');
    try {
      await _startCamera();
      if (!mounted) return;
      // Let video metadata load
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _ready = true);
      widget.onStatusChange('Position your face in the oval, then tap 📷');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Camera access denied.\nPlease allow camera access and reload.');
      widget.onStatusChange('Camera unavailable');
    }
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off, color: Colors.white54, size: 56),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_ready) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation(AppColors.accentCyan),
              ),
              SizedBox(height: 16),
              Text('Starting camera…',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return HtmlElementView(viewType: _viewId);
  }
}

// ── Capture button ─────────────────────────────────────────────

class CaptureButton extends StatefulWidget {
  final bool capturing;
  final void Function(dynamic xfile) onCapture;

  const CaptureButton({
    super.key,
    required this.capturing,
    required this.onCapture,
  });

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final xfile = await _captureFrame();
      widget.onCapture(xfile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Capture failed: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: _busy ? null : (_) => _anim.reverse(),
            onTapUp: _busy
                ? null
                : (_) {
                    _anim.forward();
                    _capture();
                  },
            onTapCancel: _busy ? null : () => _anim.forward(),
            child: ScaleTransition(
              scale: _anim,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF0077FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.45),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: _busy
                    ? const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.black),
                        ),
                      )
                    : const Icon(Icons.camera_alt,
                        color: Colors.black, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap to capture',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

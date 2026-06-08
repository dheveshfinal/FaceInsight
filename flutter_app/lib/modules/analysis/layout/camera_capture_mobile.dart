// ==============================================================
//  camera_capture_mobile.dart  — Mobile/desktop stub
//  Uses image_picker with ImageSource.camera for native camera.
// ==============================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';

// ── Camera feed widget (mobile) ────────────────────────────────

class CameraFeedWidget extends StatefulWidget {
  final void Function(dynamic xfile) onCapture;
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCamera());
  }

  Future<void> _openCamera() async {
    widget.onStatusChange('Opening camera…');
    widget.onCapturing(true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 92,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      widget.onCapture(xfile);
    } catch (e) {
      widget.onStatusChange('Camera error: $e');
      widget.onCapturing(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.accentCyan),
            ),
            SizedBox(height: 20),
            Text(
              'Opening camera…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Capture button (hidden on mobile — camera opens natively) ──

class CaptureButton extends StatelessWidget {
  final bool capturing;
  final void Function(dynamic xfile) onCapture;

  const CaptureButton({
    super.key,
    required this.capturing,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_state.dart';
import '../ui/tinni_style.dart';

class CallVerificationScreen extends StatefulWidget {
  const CallVerificationScreen({super.key, required this.state});

  final AppState state;

  @override
  State<CallVerificationScreen> createState() =>
      _CallVerificationScreenState();
}

class _CallVerificationScreenState extends State<CallVerificationScreen> {
  final ImagePicker picker = ImagePicker();
  final FaceDetector detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true,
      enableLandmarks: true,
    ),
  );

  bool loading = true;
  bool submitting = false;
  String gender = 'female';
  Map<String, dynamic> verification = const <String, dynamic>{};
  final List<XFile?> photos = <XFile?>[null, null, null];
  final List<double?> yaw = <double?>[null, null, null];
  final List<bool> faceValid = <bool>[false, false, false];

  AppState get state => widget.state;

  static const prompts = <String>[
    'Look straight at the camera',
    'Turn your face to the left',
    'Turn your face to the right',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    detector.close();
    super.dispose();
  }

  Future<void> _load() async {
    final value = await state.backend.callVerificationStatus(
      userId: state.userId,
    );
    if (!mounted) return;
    final raw = value?['verification'];
    setState(() {
      verification =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
      final currentGender =
          verification['gender']?.toString().trim().toLowerCase();
      if (currentGender == 'male' || currentGender == 'female') {
        gender = currentGender!;
      }
      loading = false;
    });
  }

  bool get verified => verification['verified'] == true;

  String get status {
    final value = verification['status']?.toString().trim();
    return value == null || value.isEmpty ? 'unverified' : value;
  }

  bool _poseOk(int index, double? angle) {
    if (angle == null) return index == 0;
    if (index == 0) return angle.abs() <= 20;
    return angle.abs() >= 10;
  }

  Future<void> _capture(int index) async {
    final file = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 88,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (file == null || !mounted) return;

    var valid = false;
    double? angle;
    try {
      final faces =
          await detector.processImage(InputImage.fromFilePath(file.path));
      if (faces.length == 1) {
        angle = faces.first.headEulerAngleY;
        valid = _poseOk(index, angle);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      photos[index] = file;
      yaw[index] = angle;
      faceValid[index] = valid;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          valid
              ? 'Face captured for ${prompts[index].toLowerCase()}.'
              : 'Face was captured, but the pose check did not fully pass. Retake for best verification.',
        ),
      ),
    );
  }

  bool get _oppositeSidePoses {
    final left = yaw[1];
    final right = yaw[2];
    if (left == null || right == null) return false;
    return left.abs() >= 10 &&
        right.abs() >= 10 &&
        ((left < 0 && right > 0) || (left > 0 && right < 0));
  }

  bool get _systemPassed =>
      faceValid[0] && faceValid[1] && faceValid[2] && _oppositeSidePoses;

  Future<void> _submit() async {
    if (submitting || photos.any((file) => file == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture all 3 live photos first.')),
      );
      return;
    }
    setState(() => submitting = true);
    final keys = <String>[];
    try {
      const names = <String>['front', 'left', 'right'];
      for (var index = 0; index < photos.length; index++) {
        final file = photos[index]!;
        final bytes = await file.readAsBytes();
        final key = await state.backend.uploadImage(
          key:
              'call-verifications/${state.userId}/${names[index]}-${DateTime.now().microsecondsSinceEpoch}.jpg',
          bytes: bytes,
          contentType: 'image/jpeg',
        );
        if (key == null) throw StateError('photo_upload_failed');
        keys.add(key);
      }
      final result = await state.backend.submitCallVerification(
        userId: state.userId,
        gender: gender,
        photoKeys: keys,
        systemPassed: _systemPassed,
      );
      if (!mounted) return;
      if (result?['ok'] == true) {
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?['already_verified'] == true
                  ? 'Call ID is already verified.'
                  : 'Verification submitted for Owner review.',
            ),
          ),
        );
      } else {
        final error = result?['error']?.toString() ?? 'verification_failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.replaceAll('_', ' '))),
        );
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Color _statusColor() {
    if (verified) return Colors.greenAccent;
    if (status.contains('pending')) return Colors.orangeAccent;
    if (status.contains('reject') || status.contains('revoked')) {
      return Colors.redAccent;
    }
    return TinniPalette.muted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TinniPalette.black,
      appBar: AppBar(
        title: const Text(
          'Verify Call ID',
          style: TextStyle(
            color: TinniPalette.gold,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: TinniBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                children: [
                  TinniPanel(
                    child: Row(
                      children: [
                        const TinniGlowIcon(
                          icon: Icons.verified_user_rounded,
                          size: 25,
                          boxSize: 48,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Call verification',
                                style: TextStyle(
                                  color: TinniPalette.cream,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                verified
                                    ? 'Verified'
                                    : status.replaceAll('_', ' '),
                                style: TextStyle(
                                  color: _statusColor(),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (verified)
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.greenAccent,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gender',
                    style: TextStyle(
                      color: TinniPalette.gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'female',
                        label: Text('Female'),
                        icon: Icon(Icons.woman_rounded),
                      ),
                      ButtonSegment<String>(
                        value: 'male',
                        label: Text('Male'),
                        icon: Icon(Icons.man_rounded),
                      ),
                    ],
                    selected: <String>{gender},
                    onSelectionChanged: verified
                        ? null
                        : (value) => setState(() => gender = value.first),
                  ),
                  const SizedBox(height: 16),
                  for (var index = 0; index < 3; index++) ...[
                    TinniPanel(
                      onTap: verified ? null : () => _capture(index),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 62,
                            height: 62,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: photos[index] == null
                                  ? const ColoredBox(
                                      color: TinniPalette.panel2,
                                      child: Icon(
                                        Icons.photo_camera_rounded,
                                        color: TinniPalette.gold,
                                      ),
                                    )
                                  : Image.file(
                                      File(photos[index]!.path),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${index + 1}. ${prompts[index]}',
                                  style: const TextStyle(
                                    color: TinniPalette.cream,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  photos[index] == null
                                      ? 'Tap to capture a live photo'
                                      : faceValid[index]
                                          ? 'Face pose check passed'
                                          : 'Retake recommended',
                                  style: TextStyle(
                                    color: photos[index] == null
                                        ? TinniPalette.muted
                                        : faceValid[index]
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            faceValid[index]
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            color: faceValid[index]
                                ? Colors.greenAccent
                                : TinniPalette.gold,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  const TinniPanel(
                    child: Text(
                      'Random Call costs 500,000 coins per minute. Direct friend calls cost 400,000 coins per minute. Verified female receivers earn 80% of the per-minute call cost as diamonds. Final verification is controlled by the Owner.',
                      style: TextStyle(
                        color: TinniPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: verified || submitting ? null : _submit,
                    icon: submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: Text(
                      verified
                          ? 'Verified'
                          : status.contains('pending')
                              ? 'Resubmit verification'
                              : 'Submit verification',
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

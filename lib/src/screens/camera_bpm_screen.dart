import 'dart:async';

import 'package:flutter/material.dart';
import 'package:heart_bpm/heart_bpm.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/bpm_filter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State Machine
// ─────────────────────────────────────────────────────────────────────────────
enum _BpmState { waitingForFinger, stabilizing, ready }

class CameraBpmScreen extends StatefulWidget {
  // ── Production constructor ────────────────────────────────────────────────
  const CameraBpmScreen({
    super.key,
    this.forced = false,
    this.message,
  })  : bpmStream = null,
        grantCameraForTesting = false;

  // ── Test constructor ──────────────────────────────────────────────────────
  /// FOR TESTING ONLY.
  ///
  /// Bypasses the real camera and permission flow entirely:
  /// * [bpmStream] is listened to directly in place of [HeartBPMDialog].
  /// * Camera permission is treated as already granted.
  const CameraBpmScreen.forTesting({
    super.key,
    required this.bpmStream,
    this.forced = false,
    this.message,
  }) : grantCameraForTesting = true;

  final Stream<int>? bpmStream;
  final bool grantCameraForTesting;
  final bool forced;
  final String? message;

  @override
  State<CameraBpmScreen> createState() => _CameraBpmScreenState();
}

class _CameraBpmScreenState extends State<CameraBpmScreen>
    with WidgetsBindingObserver {
  static const _hiltTeal = Color(0xFF00897B);

  _BpmState _state = _BpmState.waitingForFinger;
  final List<int> _readings = [];
  bool _fingerDetected = false;
  bool _cameraPermissionGranted = false;
  int _warmupCount = 0; // frames discarded per finger placement (auto-exposure settle)

  StreamSubscription<int>? _bpmSubscription;

  // ── Derived state (delegates to BpmFilter) ───────────────────────────────
  double get _progress =>
      (_readings.length / BpmFilter.bufferTarget).clamp(0.0, 1.0);

  bool get _canLock => BpmFilter.canLock(_readings);

  int get _currentMedian => BpmFilter.currentMedian(_readings);

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.grantCameraForTesting) {
      _cameraPermissionGranted = true;
      _bpmSubscription = widget.bpmStream?.listen(_onBpmData);
    } else {
      _requestCamera();
    }
  }

  @override
  void dispose() {
    _bpmSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() {
        _cameraPermissionGranted = status.isGranted;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Data handler
  // ─────────────────────────────────────────────────────────────────────────

  void _onBpmData(int bpm) {
    if (!mounted) return;
    setState(() {
      // Finger detection heuristic: BPM within the physiological range.
      final inRange = bpm >= 40 && bpm <= 220;
      _fingerDetected = inRange;

      if (!inRange) {
        // Finger removed — clear stale readings so the next placement
        // starts from a clean slate and can't be biased by earlier data.
        _readings.clear();
        _warmupCount = 0;
        _state = _BpmState.waitingForFinger;
        return;
      }

      // Warm-up: the camera's auto-exposure takes a few frames to settle.
      // Discard [BpmFilter.warmupReadings] readings before buffering anything.
      if (_warmupCount < BpmFilter.warmupReadings) {
        _warmupCount++;
        _state = _BpmState.stabilizing;
        return;
      }

      // Pre-buffer artefact gate: reject readings that deviate too far from
      // the established median (motion spikes, finger shift artefacts).
      if (!BpmFilter.isPlausibleReading(bpm, _readings)) return;

      if (_readings.length < BpmFilter.bufferTarget) {
        _readings.add(bpm);
      }
      _state = BpmFilter.canLock(_readings)
          ? _BpmState.ready
          : _BpmState.stabilizing;
    });
  }

  void _lockIn() {
    final result = _currentMedian;
    if (result > 0) Navigator.of(context).pop(result);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.forced,
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text(
            'HEART RATE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
        ),
        body: !_cameraPermissionGranted
            ? _buildPermissionPrompt()
            : _buildMeasurementUI(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Permission denied UI
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Camera permission is required\nto measure heart rate.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _requestCamera,
              style: OutlinedButton.styleFrom(
                foregroundColor: _hiltTeal,
                side: const BorderSide(color: _hiltTeal),
              ),
              child: const Text('GRANT PERMISSION'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main measurement UI
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMeasurementUI() {
    return Stack(
      children: [
        // ── Camera preview (production only; skipped when bpmStream injected) ──
        if (widget.bpmStream == null)
          Opacity(
            opacity: 0.0,
            child: HeartBPMDialog(
              context: context,
              onRawData: (_) {},
              onBPM: _onBpmData,
              showTextValues: false,
            ),
          ),

        // ── Full-screen dark overlay UI ──
        SafeArea(
          child: Column(
            children: [
              const Spacer(),

              // 1. Instruction
              _buildInstructionLabel(),

              const SizedBox(height: 40),

              // 2. BPM ring + number
              _buildBpmRing(),

              const SizedBox(height: 40),

              // 3. Finger cue
              _buildFingerCue(),

              const Spacer(),

              // 4. Lock In button
              _buildLockInButton(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionLabel() {
    return Column(
      children: [
        Text(
          _state == _BpmState.waitingForFinger
              ? 'COVER THE LENS WITH YOUR FINGER'
              : _state == _BpmState.stabilizing
                  ? 'HOLD STILL…'
                  : 'READING LOCKED',
          style: TextStyle(
            color: _state == _BpmState.waitingForFinger
                ? Colors.white54
                : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Press your fingertip firmly over the rear camera + flash',
          style: TextStyle(
            color: Colors.white30,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _hiltTeal,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBpmRing() {
    const ringSize = 220.0;
    const strokeWidth = 8.0;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: const CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1C1C1C)),
            ),
          ),
          // Animated teal progress ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return SizedBox(
                width: ringSize,
                height: ringSize,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _canLock ? _hiltTeal : _hiltTeal.withOpacity(0.75),
                  ),
                ),
              );
            },
          ),
          // BPM number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _currentMedian > 0 ? '$_currentMedian' : '--',
                style: TextStyle(
                  color: _currentMedian > 0 ? Colors.white : Colors.white30,
                  fontSize: 72,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -2,
                ),
              ),
              Text(
                'BPM',
                style: TextStyle(
                  color: _hiltTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFingerCue() {
    final isDetected = _fingerDetected;
    final label = isDetected ? 'FINGER DETECTED ✓' : 'NO FINGER DETECTED';
    final color = isDetected ? _hiltTeal : const Color(0xFFFFB300);
    final icon =
        isDetected ? Icons.fingerprint : Icons.pan_tool_alt_outlined;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(isDetected),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockInButton() {
    return AnimatedOpacity(
      opacity: _canLock ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _canLock ? _lockIn : null,
            style: FilledButton.styleFrom(
              backgroundColor: _hiltTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  'LOCK IN  $_currentMedian BPM',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

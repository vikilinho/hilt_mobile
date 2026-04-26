import 'dart:async';
import 'package:flutter/material.dart';
import 'package:heart_bpm/heart_bpm.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/bpm_filter.dart';

class CameraBpmScreen extends StatefulWidget {
  const CameraBpmScreen({
    super.key,
    this.forced = false,
    this.message,
    this.previewMode = false,
    this.previewFingerDetected = false,
    this.previewHasPulseSignal = false,
    this.previewBpm,
    this.previewAcquiring = false,
    this.previewRedChannelStable,
  }) : grantCameraForTesting = false,
       bpmStream = null;

  const CameraBpmScreen.forTesting({
    super.key,
    required this.bpmStream,
    this.forced = false,
    this.message,
  })  : grantCameraForTesting = true,
        previewMode = false,
        previewFingerDetected = false,
        previewHasPulseSignal = false,
        previewBpm = null,
        previewAcquiring = false,
        previewRedChannelStable = null;

  final bool grantCameraForTesting;
  final Stream<int>? bpmStream;
  final bool forced;
  final String? message;
  final bool previewMode;
  final bool previewFingerDetected;
  final bool previewHasPulseSignal;
  final int? previewBpm;
  final bool previewAcquiring;
  final bool? previewRedChannelStable;

  @override
  State<CameraBpmScreen> createState() => _CameraBpmScreenState();
}

class _CameraBpmScreenState extends State<CameraBpmScreen>
    with SingleTickerProviderStateMixin {
  static const _hiltTeal = Color(0xFF00897B);
  static const _surfaceTint = Color(0xFFF4F7F6);
  static const _cardTint = Color(0xFFEAF4F2);
  static const _lockInDurationSeconds = 30;
  static const _coverageWindowSize = 10;
  static const _coverageMinBrightness = 15.0;
  static const _coverageMaxBrightness = 90.0;
  static const _coverageStartThreshold = 0.72;
  static const _coverageStopThreshold = 0.58;

  bool _cameraPermissionGranted = false;
  final List<int> _readings = [];
  final List<double> _brightnessSamples = [];
  int _currentMedian = 0;
  bool _fingerDetected = false;
  double _coverageScore = 0.0;
  double _averageBrightness = 0.0;
  
  Stopwatch? _lockInCountdown;
  Timer? _uiTimer;
  bool _isLockingIn = false;
  StreamSubscription<int>? _bpmSubscription;

  @override
  void initState() {
    super.initState();
    _requestCamera();
    
    if (widget.bpmStream != null) {
      _bpmSubscription = widget.bpmStream!.listen((bpm) {
        if (!mounted) return;
        _onBPM(bpm);
        _onRawData(SensorValue(time: DateTime.now(), value: 50.0));
      });
    }

    _uiTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (_lockInCountdown != null &&
          _lockInCountdown!.elapsed.inSeconds >= _lockInDurationSeconds &&
          _currentMedian > 0) {
        _lockIn();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _bpmSubscription?.cancel();
    _uiTimer?.cancel();
    _lockInCountdown?.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _cameraPermissionGranted = status.isGranted;
    });
    if (status.isGranted) {
      await WakelockPlus.enable();
    }
  }

  void _onBPM(int bpm) {
    if (!mounted) return;
    setState(() {
      if (bpm >= 40 && bpm <= 220) {
        if (_readings.length < BpmFilter.bufferTarget) {
          _readings.add(bpm);
        } else {
          _readings.removeAt(0);
          _readings.add(bpm);
        }
        
        final sorted = List<int>.from(_readings)..sort();
        if (sorted.isNotEmpty) {
          _currentMedian = sorted[sorted.length ~/ 2];
        }

        if (BpmFilter.canLock(_readings)) {
          _lockInCountdown ??= Stopwatch()..start();
        } else {
          _lockInCountdown?.stop();
          _lockInCountdown = null;
        }
      }
    });
  }

  void _onRawData(SensorValue value) {
    if (!mounted) return;

    final brightness = value.value.toDouble();
    _brightnessSamples.add(brightness);
    if (_brightnessSamples.length > _coverageWindowSize) {
      _brightnessSamples.removeAt(0);
    }

    final averageBrightness = _brightnessSamples.isEmpty
        ? 0.0
        : _brightnessSamples.reduce((a, b) => a + b) / _brightnessSamples.length;
    final normalizedBrightness =
        ((averageBrightness - _coverageMinBrightness) /
                (_coverageMaxBrightness - _coverageMinBrightness))
            .clamp(0.0, 1.0);
    final normalizedScore = (1.0 - normalizedBrightness).clamp(0.0, 1.0);
    final nextFingerDetected = _fingerDetected
        ? normalizedScore >= _coverageStopThreshold
        : normalizedScore >= _coverageStartThreshold;

    setState(() {
      _coverageScore = normalizedScore;
      _averageBrightness = averageBrightness;
      _fingerDetected = nextFingerDetected;
      if (!_fingerDetected) {
        _readings.clear();
        _currentMedian = 0;
        _lockInCountdown?.stop();
        _lockInCountdown = null;
      }
    });
  }

  Future<void> _lockIn() async {
    if (_isLockingIn || !mounted) return;
    setState(() {
      _isLockingIn = true;
    });
    
    _uiTimer?.cancel();
    _lockInCountdown?.stop();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    Navigator.of(context).pop(_currentMedian);
  }

  bool get _canLock => BpmFilter.canLock(_readings) && _currentMedian > 0;

  double get _progress {
    if (widget.previewMode) return 0.5;
    if (!_canLock || _lockInCountdown == null) return 0.0;
    return (_lockInCountdown!.elapsedMilliseconds / (_lockInDurationSeconds * 1000)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.forced
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.black87),
                onPressed: () => Navigator.of(context).pop(0),
              ),
        title: const Text(
          'HEART RATE',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontSize: 15,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _cameraPermissionGranted || widget.previewMode || widget.grantCameraForTesting
            ? _buildMainContent()
            : const Center(
                child: Text(
                  'Camera permission required.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        const SizedBox(height: 24),
        _buildVisualizerRing(),
        const Spacer(),
        _buildBpmReadout(),
        const Spacer(),
        _buildInstructionCard(),
        const SizedBox(height: 12),
        _buildLockInButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildBpmReadout() {
    final displayedBpm = widget.previewMode ? (widget.previewBpm ?? 0) : _currentMedian;
    final bpmText = displayedBpm > 0 ? displayedBpm.toString().padLeft(2, '0') : '--';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          bpmText,
          style: const TextStyle(
            color: _hiltTeal,
            fontSize: 64,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'BPM',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVisualizerRing() {
    final size = MediaQuery.of(context).size.width * 0.58;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: _progress),
            duration: const Duration(milliseconds: 300),
            builder: (context, val, child) {
              return CircularProgressIndicator(
                value: val,
                strokeWidth: 6,
                backgroundColor: _surfaceTint,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _canLock ? _hiltTeal : Colors.grey.shade300,
                ),
              );
            },
          ),
        ),
        ClipPath(
          clipper: _HeartClipper(),
          child: Container(
            width: size - 32,
            height: size - 32,
            color: _surfaceTint,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!widget.previewMode && !widget.grantCameraForTesting)
                  HeartBPMDialog(
                    context: context,
                    showTextValues: false,
                    cameraWidgetWidth: size - 32,
                    cameraWidgetHeight: size - 32,
                    borderRadius: 0,
                    onRawData: _onRawData,
                    onBPM: _onBPM,
                    centerLoadingWidget: const Center(
                      child: CircularProgressIndicator(color: _hiltTeal),
                    ),
                  ),
                Container(
                  color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                ),
                if (_fingerDetected || widget.previewFingerDetected)
                  const _ScanAnimationOverlay(isActive: true),
              ],
            ),
          ),
        ),
        if (!_fingerDetected && !widget.previewMode)
          ClipPath(
            clipper: _HeartClipper(),
            child: Container(
              width: size - 32,
              height: size - 32,
              alignment: Alignment.center,
              color: Colors.white.withValues(alpha: 0.7),
              child: const Text(
                'COVER LENS',
                style: TextStyle(
                  color: _hiltTeal,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInstructionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _cardTint,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Text(
              _fingerDetected
                  ? 'Acquiring Pulse...'
                  : 'Place finger over the camera lens and flash.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _hiltTeal,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.message != null) ...[
              const SizedBox(height: 14),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _hiltTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Coverage ${(100 * _coverageScore).round()}%  Brightness ${_averageBrightness.toStringAsFixed(0)}',
                style: TextStyle(
                  color: _fingerDetected ? _hiltTeal : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _canLock ? _lockIn : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hiltTeal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.black.withValues(alpha: 0.05),
              disabledForegroundColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: _isLockingIn
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'LOCK IN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Heart shape clipper
// ─────────────────────────────────────────────────────────────────────────────

class _HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, size.height * 0.9);
    path.cubicTo(
      size.width * 0.12, size.height * 0.68,
      0, size.height * 0.34,
      size.width * 0.24, size.height * 0.2,
    );
    path.cubicTo(
      size.width * 0.4, size.height * 0.08,
      size.width * 0.5, size.height * 0.16,
      size.width / 2, size.height * 0.26,
    );
    path.cubicTo(
      size.width * 0.5, size.height * 0.16,
      size.width * 0.6, size.height * 0.08,
      size.width * 0.76, size.height * 0.2,
    );
    path.cubicTo(
      size.width, size.height * 0.34,
      size.width * 0.88, size.height * 0.68,
      size.width / 2, size.height * 0.9,
    );
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Fingerprint scan animation
// ─────────────────────────────────────────────────────────────────────────────

class _ScanAnimationOverlay extends StatefulWidget {
  const _ScanAnimationOverlay({
    super.key,
    required this.isActive,
  });

  final bool isActive;

  @override
  State<_ScanAnimationOverlay> createState() => _ScanAnimationOverlayState();
}

class _ScanAnimationOverlayState extends State<_ScanAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _controller.repeat();
  }

  @override
  void didUpdateWidget(_ScanAnimationOverlay old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => CustomPaint(
        painter: _FingerprintScanPainter(progress: _controller.value),
      ),
    );
  }
}

class _FingerprintScanPainter extends CustomPainter {
  const _FingerprintScanPainter({required this.progress});

  final double progress;

  static const _ringCount = 3;
  static const _color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.shortestSide * 0.44;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < _ringCount; i++) {
      final phase = (progress + i / _ringCount) % 1.0;
      final radius = maxRadius * phase;
      final opacity = (1.0 - phase).clamp(0.0, 1.0) * 0.70;
      paint.color = _color.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }

    final dotOpacity = ((1.0 - progress * 2).clamp(0.0, 1.0) * 0.85);
    if (dotOpacity > 0) {
      canvas.drawCircle(
        center,
        4.0,
        Paint()..color = _color.withValues(alpha: dotOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_FingerprintScanPainter old) => old.progress != progress;
}

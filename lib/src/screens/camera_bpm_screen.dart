import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:heart_bpm/heart_bpm.dart' show SensorValue;
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
  static const _lockInHoldDuration = Duration(seconds: 2);
  static const _coverageWindowSize = 10;
  static const _coverageMinBrightness = 15.0;
  static const _coverageMaxBrightness = 90.0;
  static const _fingerAcquireCoverageThreshold = 0.75;
  static const _fingerReleaseCoverageThreshold = 0.55;
  static const _coverageStabilityTolerance = 0.12;
  static const _displayCoverageThreshold = 0.90;

  bool _cameraPermissionGranted = false;
  final List<int> _readings = [];
  final List<double> _brightnessSamples = [];
  final List<double> _coverageSamples = [];
  int _currentMedian = 0;
  bool _fingerDetected = false;
  double _coverageScore = 0.0;
  double _averageBrightness = 0.0;
  int _warmupReadingsRemaining = BpmFilter.warmupReadings;
  
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
          _lockInCountdown!.elapsedMilliseconds >=
              _lockInHoldDuration.inMilliseconds &&
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

  int _latestStableMedian() {
    if (_readings.isEmpty) return 0;
    if (_readings.length < BpmFilter.stabilityWindow) {
      return BpmFilter.medianOf(_readings);
    }
    final recent = _readings.sublist(
      _readings.length - BpmFilter.stabilityWindow,
    );
    return BpmFilter.medianOf(recent);
  }

  void _onBPM(int bpm) {
    if (!mounted) return;

    if (!_fingerDetected) return;
    if (_coverageScore < _displayCoverageThreshold) return;
    if (bpm < 40 || bpm > 220) return;

    setState(() {
      if (_warmupReadingsRemaining > 0) {
        _warmupReadingsRemaining--;
        _lockInCountdown?.stop();
        _lockInCountdown = null;
        return;
      }

      if (!BpmFilter.isPlausibleReading(bpm, _readings)) {
        _lockInCountdown?.stop();
        _lockInCountdown = null;
        return;
      }

      if (_readings.length < BpmFilter.bufferTarget) {
        _readings.add(bpm);
      } else {
        _readings.removeAt(0);
        _readings.add(bpm);
      }

      _currentMedian = _latestStableMedian();

      if (_canLock) {
        _lockInCountdown ??= Stopwatch()..start();
      } else {
        _lockInCountdown?.stop();
        _lockInCountdown = null;
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
    _coverageSamples.add(normalizedScore);
    if (_coverageSamples.length > _coverageWindowSize) {
      _coverageSamples.removeAt(0);
    }
    final nextFingerDetected = _fingerDetected
        ? normalizedScore >= _fingerReleaseCoverageThreshold
        : normalizedScore >= _fingerAcquireCoverageThreshold;
    setState(() {
      _coverageScore = normalizedScore;
      _averageBrightness = averageBrightness;
      _fingerDetected = nextFingerDetected;
      if (!_fingerDetected) {
        _readings.clear();
        _currentMedian = 0;
        _warmupReadingsRemaining = BpmFilter.warmupReadings;
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

  bool get _coverageStable {
    if (_coverageSamples.length < _coverageWindowSize) return false;
    final minCoverage = _coverageSamples.reduce((a, b) => a < b ? a : b);
    final maxCoverage = _coverageSamples.reduce((a, b) => a > b ? a : b);
    return (maxCoverage - minCoverage) <= _coverageStabilityTolerance;
  }

  bool get _coverageReady =>
      _fingerDetected && _coverageScore >= _displayCoverageThreshold;

  bool get _bpmStable =>
      _currentMedian > 0 && BpmFilter.canLock(_readings);

  bool get _canLock => _coverageReady && _coverageStable && _bpmStable;

  String get _lockQualityLabel {
    if (!_fingerDetected) return 'Waiting for finger';
    if (_coverageScore < _displayCoverageThreshold) {
      return 'Cover lens more fully';
    }
    if (!_coverageStable) return 'Hold finger steadier';
    if (!_bpmStable) return 'Collecting pulse';
    return 'Ready to lock';
  }

  double get _progress {
    if (widget.previewMode) return 0.5;
    if (!_canLock || _lockInCountdown == null) return 0.0;
    return (_lockInCountdown!.elapsedMilliseconds /
            _lockInHoldDuration.inMilliseconds)
        .clamp(0.0, 1.0);
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
    final displayedBpm = widget.previewMode
        ? (widget.previewBpm ?? 0)
        : (_coverageScore >= _displayCoverageThreshold ? _currentMedian : 0);
    final bpmText = displayedBpm.toString().padLeft(2, '0');
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
                  _HeartBpmCameraView(
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Lock quality: $_lockQualityLabel',
                style: TextStyle(
                  color: _canLock ? _hiltTeal : Colors.black54,
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

class _HeartBpmCameraView extends StatefulWidget {
  const _HeartBpmCameraView({
    required this.onBPM,
    required this.onRawData,
    this.centerLoadingWidget,
    this.cameraWidgetHeight,
    this.cameraWidgetWidth,
    this.showTextValues = false,
    this.borderRadius,
    this.sampleDelay = 2000 ~/ 30,
    this.alpha = 0.8,
  });

  final Widget? centerLoadingWidget;
  final double? cameraWidgetHeight;
  final double? cameraWidgetWidth;
  final bool showTextValues;
  final double? borderRadius;
  final void Function(int) onBPM;
  final void Function(SensorValue)? onRawData;
  final int sampleDelay;
  final double alpha;

  @override
  State<_HeartBpmCameraView> createState() => _HeartBpmCameraViewState();
}

class _HeartBpmCameraViewState extends State<_HeartBpmCameraView> {
  static const _windowLength = 50;

  CameraController? _controller;
  bool _processing = false;
  bool _isCameraInitialized = false;
  int _currentValue = 0;
  final List<SensorValue> _measureWindow = List<SensorValue>.filled(
    _windowLength,
    SensorValue(time: DateTime.now(), value: 0),
    growable: true,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_initController());
  }

  @override
  void dispose() {
    unawaited(_deinitController());
    super.dispose();
  }

  Future<void> _deinitController() async {
    _isCameraInitialized = false;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    await controller.dispose();
  }

  Future<void> _initController() async {
    if (_controller != null) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final controller = CameraController(
      backCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup:
          Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.torch);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.locked);
      } catch (_) {}
      try {
        await controller.setFocusMode(FocusMode.locked);
      } catch (_) {}

      await controller.startImageStream((image) {
        if (_processing || !mounted) return;
        _processing = true;
        _scanImage(image);
      });

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isCameraInitialized = true;
      });
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  void _scanImage(CameraImage image) {
    final average =
        image.planes.first.bytes.reduce((a, b) => a + b) /
        image.planes.first.bytes.length;

    _measureWindow.removeAt(0);
    _measureWindow.add(SensorValue(time: DateTime.now(), value: average));

    _smoothBpm(average).then((_) {
      widget.onRawData?.call(
        SensorValue(time: DateTime.now(), value: average),
      );

      Future<void>.delayed(Duration(milliseconds: widget.sampleDelay)).then((_) {
        if (!mounted) return;
        setState(() {
          _processing = false;
        });
      });
    });
  }

  Future<int> _smoothBpm(double newValue) async {
    double maxVal = 0;
    double avg = 0;

    for (final sample in _measureWindow) {
      avg += sample.value / _measureWindow.length;
      if (sample.value.toDouble() > maxVal) {
        maxVal = sample.value.toDouble();
      }
    }

    final threshold = (maxVal + avg) / 2;
    int counter = 0;
    int previousTimestamp = 0;
    double tempBpm = 0;

    for (int i = 1; i < _measureWindow.length; i++) {
      if (_measureWindow[i - 1].value < threshold &&
          _measureWindow[i].value > threshold) {
        if (previousTimestamp != 0) {
          counter++;
          tempBpm += 60000 /
              (_measureWindow[i].time.millisecondsSinceEpoch -
                  previousTimestamp);
        }
        previousTimestamp = _measureWindow[i].time.millisecondsSinceEpoch;
      }
    }

    if (counter > 0) {
      tempBpm /= counter;
      tempBpm = (1 - widget.alpha) * _currentValue + widget.alpha * tempBpm;
      if (mounted) {
        setState(() {
          _currentValue = tempBpm.toInt();
        });
      } else {
        _currentValue = tempBpm.toInt();
      }
      widget.onBPM(_currentValue);
    }

    return _currentValue;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return Center(
        child: widget.centerLoadingWidget ??
            const CircularProgressIndicator(color: _CameraBpmScreenState._hiltTeal),
      );
    }

    return Column(
      children: [
        Container(
          constraints: BoxConstraints.tightFor(
            width: widget.cameraWidgetWidth ?? 100,
            height: widget.cameraWidgetHeight ?? 130,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius ?? 10),
            child: _controller!.buildPreview(),
          ),
        ),
        if (widget.showTextValues) Text(_currentValue.toString()),
      ],
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

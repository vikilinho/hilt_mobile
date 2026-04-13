import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/bpm_filter.dart';
import '../services/signal_processor.dart';

enum _BpmState { waitingForFinger, stabilizing, ready }

class CameraBpmScreen extends StatefulWidget {
  const CameraBpmScreen({
    super.key,
    this.forced = false,
    this.message,
    this.previewMode = false,
    this.previewFingerDetected = false,
    this.previewHasPulseSignal = false,
    this.previewBpm,
  })  : bpmStream = null,
        grantCameraForTesting = false;

  const CameraBpmScreen.forTesting({
    super.key,
    required this.bpmStream,
    this.forced = false,
    this.message,
  })  : grantCameraForTesting = true,
        previewMode = false,
        previewFingerDetected = false,
        previewHasPulseSignal = false,
        previewBpm = null;

  final Stream<int>? bpmStream;
  final bool grantCameraForTesting;
  final bool forced;
  final String? message;
  final bool previewMode;
  final bool previewFingerDetected;
  final bool previewHasPulseSignal;
  final int? previewBpm;

  @override
  State<CameraBpmScreen> createState() => _CameraBpmScreenState();
}

class _CameraBpmScreenState extends State<CameraBpmScreen>
    with WidgetsBindingObserver {
  static const _hiltTeal = Color(0xFF00897B);
  static const _surfaceTint = Color(0xFFF4F7F6);
  static const _cardTint = Color(0xFFEAF4F2);
  static const _sampleBoxRadius = 14;
  static const _fingerLossGrace = Duration(milliseconds: 900);
  static const _autoLockDelay = Duration(milliseconds: 900);
  static const _fingerConfirmFrames = 4;
  static const _fingerReleaseFrames = 3;

  _BpmState _state = _BpmState.waitingForFinger;
  final List<int> _readings = [];
  bool _fingerDetected = false;
  bool _cameraPermissionGranted = false;
  int _warmupCount = 0;
  StreamSubscription<int>? _bpmSubscription;

  CameraController? _cameraController;
  bool _processingFrame = false;
  bool _isComputingSignal = false;
  Timer? _uiTimer;
  Stopwatch? _measurementClock;
  final List<double> _redBuffer = [];
  final List<int> _sampleTimestampsUs = [];
  final List<int> _candidateBpms = [];
  int _currentComputedBpm = 0;
  int _confidence = 0;
  DateTime? _lastFingerSeenAt;
  Timer? _autoLockTimer;
  int _consecutiveFingerFrames = 0;
  int _consecutiveMissingFingerFrames = 0;

  Duration get _warmupDuration =>
      Platform.isIOS ? const Duration(seconds: 4) : const Duration(seconds: 3);

  Duration get _measurementDuration =>
      Platform.isIOS ? const Duration(seconds: 18) : const Duration(seconds: 15);

  int get _minSignalSamples => Platform.isIOS ? 120 : 90;

  double get _minFingerRedMean => Platform.isIOS ? 122.0 : 132.0;

  double get _minFingerRedMeanRetained => Platform.isIOS ? 110.0 : 120.0;

  double get _minFingerBrightness => Platform.isIOS ? 38.0 : 44.0;

  double get _minFingerBrightnessRetained => Platform.isIOS ? 30.0 : 36.0;

  double get _maxFingerBrightness => Platform.isIOS ? 168.0 : 178.0;

  double get _maxFingerBrightnessRetained => Platform.isIOS ? 182.0 : 192.0;

  double get _minFingerRedGreenRatio => Platform.isIOS ? 1.08 : 1.10;

  double get _minFingerRedGreenRatioRetained => Platform.isIOS ? 1.05 : 1.07;

  double get _minFingerRedBlueRatio => Platform.isIOS ? 1.14 : 1.18;

  double get _minFingerRedBlueRatioRetained => Platform.isIOS ? 1.10 : 1.14;

  double get _minFingerCoverage => Platform.isIOS ? 0.50 : 0.55;

  double get _minFingerCoverageRetained => Platform.isIOS ? 0.38 : 0.42;

  double get _maxFingerBrightnessStdDev => Platform.isIOS ? 18.0 : 22.0;

  double get _maxFingerBrightnessStdDevRetained =>
      Platform.isIOS ? 28.0 : 32.0;

  int get _confidenceThreshold => Platform.isIOS ? 68 : 65;

  double get _progress {
    if (widget.grantCameraForTesting) {
      return (_readings.length / BpmFilter.bufferTarget).clamp(0.0, 1.0);
    }

    if (!_fingerDetected) return 0.0;
    final elapsedMs = _measurementClock?.elapsedMilliseconds ?? 0;
    final totalMs =
        (_warmupDuration + _measurementDuration).inMilliseconds.toDouble();
    return (elapsedMs / totalMs).clamp(0.0, 1.0);
  }

  bool get _canLock {
    if (widget.grantCameraForTesting) {
      return BpmFilter.canLock(_readings);
    }

    return _currentComputedBpm > 0 &&
        _confidence >= _confidenceThreshold &&
        _redBuffer.length >= _minSignalSamples;
  }

  int get _currentMedian {
    if (widget.grantCameraForTesting) {
      return BpmFilter.currentMedian(_readings);
    }
    return _currentComputedBpm;
  }

  bool get _hasPulseSignal =>
      widget.previewMode
          ? widget.previewHasPulseSignal
          : _currentComputedBpm > 0 || _candidateBpms.length >= 2;

  String get _statusText {
    if (!_fingerDetected) {
      return 'NO FINGER DETECTED';
    }
    if (!_hasPulseSignal) {
      return 'FINGER POSITIONED';
    }
    if (_state == _BpmState.ready) {
      return 'MEASUREMENT COMPLETE';
    }
    return 'MEASURING...';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.grantCameraForTesting) {
      _cameraPermissionGranted = true;
      _bpmSubscription = widget.bpmStream?.listen(_onSyntheticBpmData);
    } else if (widget.previewMode) {
      _cameraPermissionGranted = true;
      _fingerDetected = widget.previewFingerDetected;
      _currentComputedBpm = widget.previewBpm ?? 0;
      _state = widget.previewHasPulseSignal ? _BpmState.stabilizing : _BpmState.waitingForFinger;
    } else {
      unawaited(WakelockPlus.enable());
      _requestCamera();
    }
  }

  @override
  void dispose() {
    _bpmSubscription?.cancel();
    _uiTimer?.cancel();
    _autoLockTimer?.cancel();
    unawaited(_disposeCamera());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.grantCameraForTesting) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeCamera());
    } else if (state == AppLifecycleState.resumed &&
        _cameraPermissionGranted &&
        _cameraController == null) {
      unawaited(WakelockPlus.enable());
      unawaited(_startCameraMeasurement());
    }
  }

  Future<void> _requestCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    setState(() {
      _cameraPermissionGranted = status.isGranted;
    });

    if (status.isGranted) {
      await WakelockPlus.enable();
      await _startCameraMeasurement();
    }
  }

  Future<void> _startCameraMeasurement() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    final imageFormat = Platform.isIOS
        ? ImageFormatGroup.bgra8888
        : ImageFormatGroup.yuv420;

    final controller = CameraController(
      backCamera,
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: imageFormat,
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

      _cameraController = controller;
      _resetProductionSignal();
      await controller.startImageStream(_processFrame);
      _uiTimer?.cancel();
      _uiTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        setState(() {});
      });
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      await controller.dispose();
    }
  }

  Future<void> _disposeCamera() async {
    _uiTimer?.cancel();
    _uiTimer = null;
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
    final controller = _cameraController;
    _cameraController = null;
    _measurementClock?.stop();
    _measurementClock = null;
    await WakelockPlus.disable();

    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  void _resetProductionSignal() {
    _redBuffer.clear();
    _sampleTimestampsUs.clear();
    _candidateBpms.clear();
    _currentComputedBpm = 0;
    _confidence = 0;
    _fingerDetected = false;
    _lastFingerSeenAt = null;
    _consecutiveFingerFrames = 0;
    _consecutiveMissingFingerFrames = 0;
    _autoLockTimer?.cancel();
    _autoLockTimer = null;
    _state = _BpmState.waitingForFinger;
    _measurementClock?.stop();
    _measurementClock = null;
  }

  void _onSyntheticBpmData(int bpm) {
    if (!mounted) return;

    setState(() {
      final inRange = bpm >= 40 && bpm <= 220;
      _fingerDetected = inRange;

      if (!inRange) {
        _readings.clear();
        _warmupCount = 0;
        _state = _BpmState.waitingForFinger;
        return;
      }

      if (_warmupCount < BpmFilter.warmupReadings) {
        _warmupCount++;
        _state = _BpmState.stabilizing;
        return;
      }

      if (!BpmFilter.isPlausibleReading(bpm, _readings)) return;

      if (_readings.length < BpmFilter.bufferTarget) {
        _readings.add(bpm);
      }
      _state = BpmFilter.canLock(_readings)
          ? _BpmState.ready
          : _BpmState.stabilizing;
      _maybeScheduleAutoLock();
    });
  }

  void _processFrame(CameraImage image) {
    if (_processingFrame || !mounted) return;
    _processingFrame = true;

    try {
      final sample = _extractFrameSample(image);
      final fingerDetected = sample?.looksLikeFingerCover(
            minRedMean:
                _fingerDetected ? _minFingerRedMeanRetained : _minFingerRedMean,
            minBrightness: _fingerDetected
                ? _minFingerBrightnessRetained
                : _minFingerBrightness,
            maxBrightness: _fingerDetected
                ? _maxFingerBrightnessRetained
                : _maxFingerBrightness,
            minRedGreenRatio: _fingerDetected
                ? _minFingerRedGreenRatioRetained
                : _minFingerRedGreenRatio,
            minRedBlueRatio: _fingerDetected
                ? _minFingerRedBlueRatioRetained
                : _minFingerRedBlueRatio,
            minCoverage: _fingerDetected
                ? _minFingerCoverageRetained
                : _minFingerCoverage,
            maxBrightnessStdDev: _fingerDetected
                ? _maxFingerBrightnessStdDevRetained
                : _maxFingerBrightnessStdDev,
          ) ??
          false;

      if (fingerDetected) {
        _consecutiveFingerFrames++;
        _consecutiveMissingFingerFrames = 0;
        _lastFingerSeenAt = DateTime.now();
      } else {
        _consecutiveMissingFingerFrames++;
        _consecutiveFingerFrames = 0;
      }

      if (!_fingerDetected) {
        if (_consecutiveFingerFrames < _fingerConfirmFrames) {
          return;
        }
        setState(() {
          _fingerDetected = true;
          _state = _BpmState.stabilizing;
        });
      }

      if (!fingerDetected) {
        final now = DateTime.now();
        final recentlyHadFinger = _lastFingerSeenAt != null &&
            now.difference(_lastFingerSeenAt!) <= _fingerLossGrace;
        if (recentlyHadFinger ||
            _consecutiveMissingFingerFrames < _fingerReleaseFrames) {
          return;
        }
        if (_fingerDetected || _state != _BpmState.waitingForFinger) {
          setState(() {
            _resetProductionSignal();
          });
        }
        return;
      }

      final clock = _measurementClock ?? Stopwatch()..start();
      _measurementClock = clock;
      final elapsed = clock.elapsed;

      if (elapsed < _warmupDuration) {
        if (_state != _BpmState.stabilizing) {
          setState(() {
            _state = _BpmState.stabilizing;
          });
        }
        return;
      }

      final sampleValue = sample?.redMean;
      if (sampleValue == null) {
        return;
      }

      final nowUs = DateTime.now().microsecondsSinceEpoch;
      _redBuffer.add(sampleValue);
      _sampleTimestampsUs.add(nowUs);

      if (_redBuffer.length > 540) {
        _redBuffer.removeAt(0);
        _sampleTimestampsUs.removeAt(0);
      }

      _fingerDetected = true;
      _state = _canLock ? _BpmState.ready : _BpmState.stabilizing;

      if (!_isComputingSignal &&
          _redBuffer.length >= _minSignalSamples &&
          elapsed >= const Duration(seconds: 5)) {
        _isComputingSignal = true;
        final buffer = List<double>.from(_redBuffer);
        final timestamps = List<int>.from(_sampleTimestampsUs);
        compute(
          _estimateHeartRate,
          <String, dynamic>{
            'buffer': buffer,
            'timestampsUs': timestamps,
          },
        ).then((result) {
          if (!mounted) return;
          if (result != null) {
            setState(() {
              _candidateBpms.add((result['bpm'] as double).round());
              while (_candidateBpms.length > 7) {
                _candidateBpms.removeAt(0);
              }
              _currentComputedBpm =
                  SignalProcessor.smoothBpmEstimates(_candidateBpms).round();
              _confidence = (result['confidence'] as double).round();
              _state = _canLock ? _BpmState.ready : _BpmState.stabilizing;
              _maybeScheduleAutoLock();
            });
          }
        }).whenComplete(() {
          _isComputingSignal = false;
        });
      }
    } finally {
      _processingFrame = false;
    }
  }

  _FrameSample? _extractFrameSample(CameraImage image) {
    if (image.format.group == ImageFormatGroup.bgra8888 &&
        image.planes.isNotEmpty) {
      final bytes = image.planes.first.bytes;
      final bytesPerRow = image.planes.first.bytesPerRow;
      final width = image.width;
      final height = image.height;
      final centerX = width ~/ 2;
      final centerY = height ~/ 2;
      double redSum = 0;
      double greenSum = 0;
      double blueSum = 0;
      double brightnessSum = 0;
      double brightnessSquaredSum = 0;
      int redDominantCount = 0;
      int count = 0;

      for (int y = centerY - _sampleBoxRadius; y < centerY + _sampleBoxRadius; y++) {
        for (int x = centerX - _sampleBoxRadius; x < centerX + _sampleBoxRadius; x++) {
          if (x < 0 || y < 0 || x >= width || y >= height) continue;
          final dx = x - centerX;
          final dy = y - centerY;
          if (dx * dx + dy * dy > _sampleBoxRadius * _sampleBoxRadius) {
            continue;
          }
          final index = y * bytesPerRow + x * 4;
          if (index + 2 >= bytes.length) continue;
          final blue = bytes[index].toDouble();
          final green = bytes[index + 1].toDouble();
          final red = bytes[index + 2].toDouble();
          final brightness = (red + green + blue) / 3.0;
          redSum += red;
          greenSum += green;
          blueSum += blue;
          brightnessSum += brightness;
          brightnessSquaredSum += brightness * brightness;
          if (red > green * 1.05 && red > blue * 1.1) {
            redDominantCount++;
          }
          count++;
        }
      }

      if (count == 0) return null;
      return _FrameSample.fromSums(
        redSum: redSum,
        greenSum: greenSum,
        blueSum: blueSum,
        brightnessSum: brightnessSum,
        brightnessSquaredSum: brightnessSquaredSum,
        redDominantCount: redDominantCount,
        count: count,
      );
    }

    if (image.planes.length < 3) return null;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final width = image.width;
    final height = image.height;
    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    double redSum = 0;
    double greenSum = 0;
    double blueSum = 0;
    double brightnessSum = 0;
    double brightnessSquaredSum = 0;
    int redDominantCount = 0;
    int count = 0;

    for (int y = centerY - _sampleBoxRadius; y < centerY + _sampleBoxRadius; y++) {
      for (int x = centerX - _sampleBoxRadius; x < centerX + _sampleBoxRadius; x++) {
        if (x < 0 || y < 0 || x >= width || y >= height) continue;
        final dx = x - centerX;
        final dy = y - centerY;
        if (dx * dx + dy * dy > _sampleBoxRadius * _sampleBoxRadius) {
          continue;
        }

        final yPixelStride = yPlane.bytesPerPixel ?? 1;
        final uvPixelStride = uPlane.bytesPerPixel ?? 1;
        final yIndex = y * yPlane.bytesPerRow + x * yPixelStride;
        final uvX = x ~/ 2;
        final uvY = y ~/ 2;
        final uIndex = uvY * uPlane.bytesPerRow + uvX * uvPixelStride;
        final vIndex = uvY * vPlane.bytesPerRow + uvX * (vPlane.bytesPerPixel ?? 1);
        if (yIndex >= yPlane.bytes.length ||
            uIndex >= uPlane.bytes.length ||
            vIndex >= vPlane.bytes.length) {
          continue;
        }

        final yValue = yPlane.bytes[yIndex].toDouble();
        final uValue = uPlane.bytes[uIndex].toDouble();
        final vValue = vPlane.bytes[vIndex].toDouble();
        final red = (yValue + 1.402 * (vValue - 128)).clamp(0.0, 255.0);
        final green =
            (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128))
                .clamp(0.0, 255.0);
        final blue = (yValue + 1.772 * (uValue - 128)).clamp(0.0, 255.0);
        final brightness = (red + green + blue) / 3.0;
        redSum += red;
        greenSum += green;
        blueSum += blue;
        brightnessSum += brightness;
        brightnessSquaredSum += brightness * brightness;
        if (red > green * 1.05 && red > blue * 1.1) {
          redDominantCount++;
        }
        count++;
      }
    }

    if (count == 0) return null;
    return _FrameSample.fromSums(
      redSum: redSum,
      greenSum: greenSum,
      blueSum: blueSum,
      brightnessSum: brightnessSum,
      brightnessSquaredSum: brightnessSquaredSum,
      redDominantCount: redDominantCount,
      count: count,
    );
  }

  void _lockIn() {
    final result = _currentMedian;
    if (result > 0) {
      _autoLockTimer?.cancel();
      _autoLockTimer = null;
      Navigator.of(context).pop(result);
    }
  }

  void _maybeScheduleAutoLock() {
    if (!_canLock) {
      _autoLockTimer?.cancel();
      _autoLockTimer = null;
      return;
    }

    if (widget.grantCameraForTesting) {
      return;
    }

    if (_autoLockTimer != null) {
      return;
    }

    _autoLockTimer = Timer(_autoLockDelay, () {
      _autoLockTimer = null;
      if (!mounted) return;
      if (_canLock && _fingerDetected && _currentMedian > 0) {
        _lockIn();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: !widget.forced,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Colors.black87,
          elevation: 0,
          title: Text(
            widget.forced ? 'MATCH REPORT' : 'HEART RATE',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: widget.forced ? 1.2 : 1.0,
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

  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.black38, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Camera permission is required\nto measure heart rate.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 16),
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

  Widget _buildMeasurementUI() {
    if (widget.grantCameraForTesting) {
      return _buildLegacyMeasurementUI();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        return SafeArea(
          child: Column(
            children: [
              SizedBox(height: compact ? 12 : 24),
              Text(
                _statusText,
                style: TextStyle(
                  color: _fingerDetected ? _hiltTeal : Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: compact ? 18 : 28),
              _buildHeartPreview(size: compact ? 126 : 138),
              SizedBox(height: compact ? 18 : 28),
              Divider(color: Colors.black.withValues(alpha: 0.08), height: 1),
              SizedBox(height: compact ? 20 : 30),
              _buildBpmReadout(),
              SizedBox(height: compact ? 20 : 28),
              _buildInstructionCard(compact: compact),
              const Spacer(),
              _buildLockInButton(),
              SizedBox(height: compact ? 20 : 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegacyMeasurementUI() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 620;
        return SafeArea(
          child: Column(
            children: [
              SizedBox(height: compact ? 12 : 24),
              _buildLegacyInstructionLabel(),
              SizedBox(height: compact ? 24 : 40),
              _buildLegacyBpmRing(ringSize: compact ? 188 : 220),
              SizedBox(height: compact ? 24 : 40),
              _buildLegacyFingerCue(compact: compact),
              const Spacer(),
              _buildLockInButton(),
              SizedBox(height: compact ? 20 : 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegacyInstructionLabel() {
    String title;
    if (_state == _BpmState.waitingForFinger) {
      title = 'COVER THE LENS WITH YOUR FINGER';
    } else if (_state == _BpmState.ready) {
      title = 'READING LOCKED';
    } else {
      title = 'HOLD STILL…';
    }

    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color:
                _state == _BpmState.waitingForFinger ? Colors.white54 : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Press your fingertip firmly over the rear camera + flash',
          style: TextStyle(
            color: Colors.white30,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLegacyBpmRing({required double ringSize}) {
    const strokeWidth = 8.0;
    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: const CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1C1C1C)),
            ),
          ),
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
                    _canLock ? _hiltTeal : _hiltTeal.withValues(alpha: 0.75),
                  ),
                ),
              );
            },
          ),
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
              const Text(
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

  Widget _buildLegacyFingerCue({required bool compact}) {
    final hasStableFinger = _fingerDetected;
    final color = hasStableFinger ? _hiltTeal : const Color(0xFFFFB300);
    final cueSize = compact ? 62.0 : 74.0;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey(_fingerDetected),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 18,
          vertical: compact ? 12 : 16,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: cueSize,
              height: cueSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: hasStableFinger ? 0.2 : 0.1),
                border: Border.all(
                  color: color.withValues(alpha: hasStableFinger ? 0.8 : 0.45),
                  width: hasStableFinger ? 3 : 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    hasStableFinger ? Icons.fingerprint : Icons.pan_tool_alt_outlined,
                    color: color,
                    size: compact ? 28 : 34,
                  ),
                  if (hasStableFinger)
                    Positioned(
                      right: compact ? 9 : 14,
                      bottom: compact ? 9 : 14,
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(
              hasStableFinger ? 'FINGER DETECTED ✓' : 'NO FINGER DETECTED',
              style: TextStyle(
                color: color,
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeartPreview({required double size}) {
    final heartTint = !_fingerDetected
        ? Colors.black.withValues(alpha: 0.45)
        : _hasPulseSignal
            ? const Color(0xFFE04747).withValues(alpha: 0.2)
            : const Color(0xFFFF8A65).withValues(alpha: 0.16);
    if (widget.previewMode) {
      return ClipPath(
        clipper: _HeartClipper(),
        child: Container(
          width: size,
          height: size,
          color: _surfaceTint,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF6BC9E), Color(0xFF0A0A0A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Container(color: heartTint),
            ],
          ),
        ),
      );
    }
    final controller = _cameraController;
    final showPreview = controller != null && controller.value.isInitialized;

    return ClipPath(
      clipper: _HeartClipper(),
      child: Container(
        width: size,
        height: size,
        color: _surfaceTint,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showPreview) CameraPreview(controller),
            Container(color: heartTint),
          ],
        ),
      ),
    );
  }

  Widget _buildBpmReadout() {
    final displayedBpm = widget.previewMode ? (widget.previewBpm ?? 0) : _currentMedian;
    final bpmText = displayedBpm > 0
        ? displayedBpm.toString().padLeft(2, '0')
        : (widget.grantCameraForTesting ? '--' : '00');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          bpmText,
          style: const TextStyle(
            color: Color(0xFF00897B),
            fontSize: 64,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        const SizedBox(width: 6),
        Text(
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

  Widget _buildInstructionCard({required bool compact}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(18, compact ? 14 : 18, 18, compact ? 14 : 18),
        decoration: BoxDecoration(
          color: _cardTint,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Text(
              _fingerDetected
                  ? (_hasPulseSignal
                      ? 'Hold steady while we lock in your peak BPM.'
                      : 'Finger is in position. Hold still while we find your pulse.')
                  : 'Place one fingertip over the rear camera',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _hiltTeal,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: compact ? 14 : 18),
            _buildPhoneGuideGraphic(),
            if (widget.message != null) ...[
              const SizedBox(height: 14),
              Text(
                widget.message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _hiltTeal,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneGuideGraphic() {
    return Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _hiltTeal, width: 3),
        color: Colors.white,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.phone_android_rounded,
            size: 72,
            color: Colors.black87,
          ),
          Positioned(
            right: 22,
            bottom: 22,
            child: Transform.rotate(
              angle: -0.3,
              child: const Icon(
                Icons.touch_app_rounded,
                size: 42,
                color: Color(0xFFFFD2B4),
              ),
            ),
          ),
          Positioned(
            left: 31,
            top: 28,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: _fingerDetected ? _hiltTeal : Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockInButton() {
    if (!widget.grantCameraForTesting) {
      return const SizedBox.shrink();
    }
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

class _HeartClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, size.height * 0.9);
    path.cubicTo(
      size.width * 0.12,
      size.height * 0.68,
      0,
      size.height * 0.34,
      size.width * 0.24,
      size.height * 0.2,
    );
    path.cubicTo(
      size.width * 0.4,
      size.height * 0.08,
      size.width * 0.5,
      size.height * 0.16,
      size.width / 2,
      size.height * 0.26,
    );
    path.cubicTo(
      size.width * 0.5,
      size.height * 0.16,
      size.width * 0.6,
      size.height * 0.08,
      size.width * 0.76,
      size.height * 0.2,
    );
    path.cubicTo(
      size.width,
      size.height * 0.34,
      size.width * 0.88,
      size.height * 0.68,
      size.width / 2,
      size.height * 0.9,
    );
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _FrameSample {
  const _FrameSample({
    required this.redMean,
    required this.greenMean,
    required this.blueMean,
    required this.brightnessMean,
    required this.brightnessStdDev,
    required this.redCoverage,
  });

  factory _FrameSample.fromSums({
    required double redSum,
    required double greenSum,
    required double blueSum,
    required double brightnessSum,
    required double brightnessSquaredSum,
    required int redDominantCount,
    required int count,
  }) {
    final brightnessMean = brightnessSum / count;
    final variance =
        max(0.0, (brightnessSquaredSum / count) - brightnessMean * brightnessMean);
    return _FrameSample(
      redMean: redSum / count,
      greenMean: greenSum / count,
      blueMean: blueSum / count,
      brightnessMean: brightnessMean,
      brightnessStdDev: sqrt(variance),
      redCoverage: redDominantCount / count,
    );
  }

  final double redMean;
  final double greenMean;
  final double blueMean;
  final double brightnessMean;
  final double brightnessStdDev;
  final double redCoverage;

  bool looksLikeFingerCover({
    required double minRedMean,
    required double minBrightness,
    required double maxBrightness,
    required double minRedGreenRatio,
    required double minRedBlueRatio,
    required double minCoverage,
    required double maxBrightnessStdDev,
  }) {
    final redGreenRatio = redMean / max(1.0, greenMean);
    final redBlueRatio = redMean / max(1.0, blueMean);

    return redMean >= minRedMean &&
        brightnessMean >= minBrightness &&
        brightnessMean <= maxBrightness &&
        redGreenRatio >= minRedGreenRatio &&
        redBlueRatio >= minRedBlueRatio &&
        redCoverage >= minCoverage &&
        brightnessStdDev <= maxBrightnessStdDev;
  }
}

Map<String, double>? _estimateHeartRate(Map<String, dynamic> request) {
  final buffer = (request['buffer'] as List).cast<double>();
  final timestampsUs = (request['timestampsUs'] as List).cast<int>();

  if (buffer.length < _minBufferForEstimate || timestampsUs.length < 2) {
    return null;
  }

  final totalUs = timestampsUs.last - timestampsUs.first;
  if (totalUs <= 0) return null;

  final sampleRate =
      (timestampsUs.length - 1) / (totalUs / Duration.microsecondsPerSecond);
  if (sampleRate < 10) return null;

  final normalized = SignalProcessor.normalise(buffer);
  final filtered = SignalProcessor.bandpassFilter(normalized, sampleRate);
  final bpmFft = SignalProcessor.calculateBpmFromFft(filtered, sampleRate);
  final peaks = SignalProcessor.detectPeaks(filtered);
  final bpmPeaks = SignalProcessor.calculateBpmFromPeaks(peaks, sampleRate);

  if (bpmFft == null && bpmPeaks == null) return null;

  double bpm;
  double confidence;

  if (bpmFft != null && bpmPeaks != null) {
    final diff = (bpmFft - bpmPeaks).abs();
    if (diff < 5) {
      bpm = (bpmFft + bpmPeaks) / 2;
      confidence = 88 - diff * 3;
    } else {
      bpm = bpmFft * 0.7 + bpmPeaks * 0.3;
      confidence = 60 - diff;
    }
  } else {
    bpm = bpmFft ?? bpmPeaks!;
    confidence = 55;
  }

  final durationSeconds = buffer.length / sampleRate;
  final durationBonus = ((durationSeconds - 8) * 2).clamp(0, 15);
  final peakBonus = min(peaks.length.toDouble(), 8);
  confidence = (confidence + durationBonus + peakBonus).clamp(0, 99);

  if (bpm < 40 || bpm > 220) return null;
  return {'bpm': bpm, 'confidence': confidence};
}

const int _minBufferForEstimate = 90;

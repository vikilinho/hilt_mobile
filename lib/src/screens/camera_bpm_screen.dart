import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:heart_bpm/heart_bpm.dart' show SensorValue;
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/bpm_filter.dart';
import '../services/signal_processor.dart';

Map<String, dynamic>? _estimateHeartRateFromSamples(
  Map<String, dynamic> payload,
) {
  final buffer = (payload['buffer'] as List).cast<double>();
  final timestampsUs = (payload['timestampsUs'] as List).cast<int>();
  if (buffer.length < 32 || timestampsUs.length < 32) return null;

  final elapsedUs = timestampsUs.last - timestampsUs.first;
  if (elapsedUs <= 0) return null;

  final sampleRateHz = ((buffer.length - 1) * 1000000.0) / elapsedUs;
  if (sampleRateHz <= 0) return null;

  final normalized = SignalProcessor.normalise(buffer);
  final filtered = SignalProcessor.bandpassFilter(normalized, sampleRateHz);
  final bpmFft = SignalProcessor.calculateBpmFromFft(filtered, sampleRateHz);
  final peaks = SignalProcessor.detectPeaks(
    filtered,
    sampleRateHz: sampleRateHz,
  );
  final bpmPeaks = SignalProcessor.calculateBpmFromPeaks(peaks, sampleRateHz);
  final filteredMean =
      filtered.reduce((a, b) => a + b) / filtered.length;
  final filteredVariance = filtered
          .map((value) => math.pow(value - filteredMean, 2).toDouble())
          .reduce((a, b) => a + b) /
      filtered.length;
  final pulseStrength = math.sqrt(filteredVariance);

  double intervalConsistency = 0.0;
  if (peaks.length >= 4) {
    final intervals = <double>[];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add((peaks[i] - peaks[i - 1]) / sampleRateHz);
    }
    final meanInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    if (meanInterval > 0) {
      final variance = intervals
              .map((value) => math.pow(value - meanInterval, 2).toDouble())
              .reduce((a, b) => a + b) /
          intervals.length;
      final coefficientOfVariation = math.sqrt(variance) / meanInterval;
      intervalConsistency =
          (1.0 - (coefficientOfVariation / 0.18)).clamp(0.0, 1.0);
    }
  }

  double? bpm;
  double confidence = 0.0;

  if (bpmFft != null && bpmPeaks != null) {
    final delta = (bpmFft - bpmPeaks).abs();
    bpm = delta <= 8 ? (bpmFft + bpmPeaks) / 2.0 : bpmFft;
    confidence = (1.0 - (delta / 20.0)).clamp(0.0, 1.0);
  } else if (bpmFft != null) {
    bpm = bpmFft;
    confidence = 0.72;
  } else if (bpmPeaks != null) {
    bpm = bpmPeaks;
    confidence = 0.65;
  }

  if (bpm == null) return null;

  final peakDensity = (peaks.length / 12.0).clamp(0.0, 1.0);
  final sampleStrength = (buffer.length / 150.0).clamp(0.0, 1.0);
  confidence = ((confidence * 0.6) +
          (peakDensity * 0.2) +
          (sampleStrength * 0.2))
      .clamp(0.0, 1.0);

  return {
    'bpm': bpm,
    'confidence': confidence,
    'pulseStrength': pulseStrength,
    'intervalConsistency': intervalConsistency,
  };
}

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
  static const _scanRed = Color(0xFFFF5252);
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
  static const _displaySignalQualityThreshold = 0.55;
  static const _lockSignalQualityThreshold = 0.72;
  static const _minSignalSamples = 90;
  static const _maxSignalSamples = 180;
  static const _recentBpmWindow = 5;
  static const _recentBpmTolerance = 6;
  static const _recentBpmAcceptanceTolerance = 10;
  static const _finalLockWindow = 8;
  static const _finalLockTolerance = 6;
  static const _finalValidationTolerance = 5;
  static const _finalValidationConfidenceThreshold = 60;
  static const _timeoutValidationConfidenceThreshold = 55;
  static const _timeoutValidationSignalQualityThreshold = 0.78;
  static const _timeoutValidationMinElapsed = Duration(seconds: 30);
  static const _acquisitionTimeout = Duration(seconds: 30);
  static const _minimumReliableAcquisition = Duration(seconds: 12);
  static const bool _debugScannerLogs = true;

  bool _cameraPermissionGranted = false;
  final List<int> _readings = [];
  final List<double> _brightnessSamples = [];
  final List<double> _coverageSamples = [];
  final List<double> _signalSamples = [];
  final List<int> _signalTimestampsUs = [];
  int _currentMedian = 0;
  bool _fingerDetected = false;
  bool _lastLoggedFingerDetected = false;
  String _lastLoggedLockQuality = '';
  double _coverageScore = 0.0;
  double _averageBrightness = 0.0;
  int _warmupReadingsRemaining = BpmFilter.warmupReadings;
  int _signalConfidence = 0;
  double _pulseStrength = 0.0;
  double _intervalConsistency = 0.0;
  bool _isComputingSignal = false;
  final List<int> _recentComputedBpms = [];
  
  Stopwatch? _lockInCountdown;
  Stopwatch? _acquisitionStopwatch;
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
      _syncLockInCountdown();
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
    _acquisitionStopwatch?.stop();
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

  void _syncLockInCountdown() {
    if (_canLock && _currentMedian > 0) {
      _lockInCountdown ??= Stopwatch()..start();
    } else {
      _lockInCountdown?.stop();
      _lockInCountdown = null;
    }
  }

  void _debugLog(String message) {
    if (_debugScannerLogs) {
      debugPrint('[Scanner] $message');
    }
  }

  bool _isAcceptableComputedBpm(int bpm) {
    if (_recentComputedBpms.length >= 3) {
      final recentMedian = BpmFilter.medianOf(_recentComputedBpms);
      final withinRecentBand =
          (bpm - recentMedian).abs() <= _recentBpmAcceptanceTolerance;
      if (!withinRecentBand) {
        _debugLog(
          'Rejected bpm=$bpm outside recent band '
          '(median=$recentMedian tolerance=$_recentBpmAcceptanceTolerance)',
        );
        return false;
      }
    }

    if (!BpmFilter.isPlausibleReading(bpm, _readings)) {
      _debugLog('Rejected implausible bpm=$bpm against buffer=$_readings');
      return false;
    }

    return true;
  }

  void _onBPM(int bpm) {
    if (!widget.grantCameraForTesting) return;
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
      _syncLockInCountdown();
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
    final hadFingerDetected = _fingerDetected;
    setState(() {
      _coverageScore = normalizedScore;
      _averageBrightness = averageBrightness;
      _fingerDetected = nextFingerDetected;
      if (_fingerDetected && !hadFingerDetected) {
        _acquisitionStopwatch = Stopwatch()..start();
        _debugLog(
          'Finger detected. coverage=${(_coverageScore * 100).round()} brightness=${_averageBrightness.toStringAsFixed(1)}',
        );
      }
      if (!_fingerDetected) {
        if (hadFingerDetected) {
          _debugLog(
            'Finger lost. coverage=${(_coverageScore * 100).round()} brightness=${_averageBrightness.toStringAsFixed(1)}',
          );
        }
        _readings.clear();
        _recentComputedBpms.clear();
        _signalSamples.clear();
        _signalTimestampsUs.clear();
        _currentMedian = 0;
        _signalConfidence = 0;
        _pulseStrength = 0.0;
        _intervalConsistency = 0.0;
        _warmupReadingsRemaining = BpmFilter.warmupReadings;
        _lockInCountdown?.stop();
        _lockInCountdown = null;
        _acquisitionStopwatch?.stop();
        _acquisitionStopwatch = null;
      }
    });

    if (_fingerDetected != _lastLoggedFingerDetected) {
      _lastLoggedFingerDetected = _fingerDetected;
    }

    if (!widget.grantCameraForTesting && nextFingerDetected) {
      _captureSignalSample(brightness);
    }
  }

  void _captureSignalSample(double brightness) {
    _signalSamples.add(brightness);
    _signalTimestampsUs.add(DateTime.now().microsecondsSinceEpoch);

    if (_signalSamples.length > _maxSignalSamples) {
      _signalSamples.removeAt(0);
      _signalTimestampsUs.removeAt(0);
    }

    if (_warmupReadingsRemaining > 0) {
      _warmupReadingsRemaining--;
      return;
    }

    if (_signalSamples.length < _minSignalSamples) return;
    if (_isComputingSignal) return;
    if (_signalSamples.length % 8 != 0) return;

    _isComputingSignal = true;
    final payload = <String, dynamic>{
      'buffer': List<double>.from(_signalSamples),
      'timestampsUs': List<int>.from(_signalTimestampsUs),
    };

    compute(_estimateHeartRateFromSamples, payload).then((result) {
      if (!mounted || result == null) return;
      final bpm = (result['bpm'] as double).round();
      final confidence =
          ((result['confidence'] as double) * 100).round().clamp(0, 100);
      final pulseStrength =
          (result['pulseStrength'] as double?)?.clamp(0.0, 1.0) ?? 0.0;
      final intervalConsistency =
          (result['intervalConsistency'] as double?)?.clamp(0.0, 1.0) ?? 0.0;

      setState(() {
        _signalConfidence = confidence;
        _pulseStrength = pulseStrength;
        _intervalConsistency = intervalConsistency;
        _debugLog(
          'Processor bpm=$bpm confidence=$confidence pulse=${pulseStrength.toStringAsFixed(3)} consistency=${intervalConsistency.toStringAsFixed(2)} median=$_currentMedian',
        );

        if (!_isAcceptableComputedBpm(bpm)) {
          _lockInCountdown?.stop();
          _lockInCountdown = null;
          return;
        }

        _recentComputedBpms.add(bpm);
        while (_recentComputedBpms.length > _finalLockWindow) {
          _recentComputedBpms.removeAt(0);
        }

        if (_readings.length < BpmFilter.bufferTarget) {
          _readings.add(bpm);
        } else {
          _readings.removeAt(0);
          _readings.add(bpm);
        }

        _currentMedian = _latestStableMedian();
        _debugLog(
          'Accepted bpm=$bpm currentMedian=$_currentMedian recent=$_recentComputedBpms signalQuality=${_signalQuality.toStringAsFixed(2)}',
        );
        _syncLockInCountdown();
      });
    }).whenComplete(() {
      _isComputingSignal = false;
    });
  }

  Future<void> _lockIn() async {
    if (_isLockingIn || !mounted) return;
    _debugLog(
      'Locking bpm=$_currentMedian recent=$_recentComputedBpms '
      'signalQuality=${_signalQuality.toStringAsFixed(2)} '
      'confidence=$_signalConfidence pulse=${_pulseStrength.toStringAsFixed(3)}',
    );
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

  double get _signalQuality {
    if (!_fingerDetected) return 0.0;

    final coverageQuality = ((_coverageScore - _fingerReleaseCoverageThreshold) /
            (_displayCoverageThreshold - _fingerReleaseCoverageThreshold))
        .clamp(0.0, 1.0);
    final sampleQuality =
        (_recentComputedBpms.length / _recentBpmWindow).clamp(0.0, 1.0);
    final coverageStableQuality = _coverageStable ? 1.0 : 0.0;
    final confidenceQuality = (_signalConfidence / 100.0).clamp(0.0, 1.0);
    final strengthQuality = (_pulseStrength / 0.04).clamp(0.0, 1.0);
    final intervalQuality = _intervalConsistency.clamp(0.0, 1.0);

    return ((coverageQuality * 0.22) +
            (sampleQuality * 0.18) +
            (coverageStableQuality * 0.08) +
            (confidenceQuality * 0.30) +
            (strengthQuality * 0.18) +
            (intervalQuality * 0.04))
        .clamp(0.0, 1.0);
  }

  bool get _signalQualityReady => _signalQuality >= _lockSignalQualityThreshold;

  bool get _recentBpmClusterStable {
    if (_recentComputedBpms.length < _recentBpmWindow) return false;
    final median = BpmFilter.medianOf(_recentComputedBpms);
    return _recentComputedBpms.every(
      (bpm) => (bpm - median).abs() <= _recentBpmTolerance,
    );
  }

  int get _recentComputedMedian {
    if (_recentComputedBpms.length < _recentBpmWindow) return 0;
    return BpmFilter.medianOf(
      _recentComputedBpms.sublist(_recentComputedBpms.length - _recentBpmWindow),
    );
  }

  bool get _bpmStable =>
      _currentMedian > 0 &&
      _recentComputedBpms.length >= _recentBpmWindow &&
      _recentBpmClusterStable;

  bool get _finalLockClusterStable {
    if (_recentComputedBpms.length < _finalLockWindow) return false;
    final recent = _recentComputedBpms.sublist(
      _recentComputedBpms.length - _finalLockWindow,
    );
    final median = BpmFilter.medianOf(recent);
    return recent.every(
      (bpm) => (bpm - median).abs() <= _finalLockTolerance,
    );
  }

  bool get _pulseStrengthReady => _pulseStrength >= 0.02;

  bool get _baseRevealReady =>
      _acquisitionStopwatch != null &&
      _acquisitionStopwatch!.elapsed >= _minimumReliableAcquisition &&
      _coverageReady &&
      _coverageStable &&
      _signalQualityReady &&
      _pulseStrengthReady &&
      _bpmStable;

  bool get _finalValidationPassed {
    if (!_baseRevealReady) return false;
    if (_currentMedian <= 0 || _recentComputedMedian <= 0) return false;
    if (!_finalLockClusterStable) return false;
    final confidenceReady =
        _signalConfidence >= _finalValidationConfidenceThreshold ||
        _signalQuality >= 0.85;
    if (!confidenceReady) return false;
    return (_currentMedian - _recentComputedMedian).abs() <=
        _finalValidationTolerance;
  }

  bool get _timeoutValidationPassed {
    if (!_baseRevealReady) return false;
    if (_acquisitionStopwatch == null ||
        _acquisitionStopwatch!.elapsed < _timeoutValidationMinElapsed) {
      return false;
    }
    if (_currentMedian <= 0 || _recentComputedMedian <= 0) return false;
    if (!_finalLockClusterStable) return false;
    final confidenceReady =
        _signalConfidence >= _timeoutValidationConfidenceThreshold ||
        _signalQuality >= _timeoutValidationSignalQualityThreshold;
    if (!confidenceReady) return false;
    return (_currentMedian - _recentComputedMedian).abs() <=
        _finalValidationTolerance;
  }

  bool get _acquisitionTimedOut =>
      _acquisitionStopwatch != null &&
      _acquisitionStopwatch!.elapsed >= _acquisitionTimeout;

  bool get _readyToRevealBpm => _finalValidationPassed || _timeoutValidationPassed;

  bool get _canLock => _finalValidationPassed || _timeoutValidationPassed;

  bool get _hasMeaningfulProgress =>
      _fingerDetected &&
      _coverageReady &&
      _coverageStable &&
      _pulseStrengthReady &&
      _signalQuality >= _displaySignalQualityThreshold &&
      _recentComputedBpms.length >= 3 &&
      _currentMedian > 0;

  int get _acquisitionSecondsRemaining {
    if (_acquisitionStopwatch == null) return _acquisitionTimeout.inSeconds;
    final remaining = _acquisitionTimeout.inSeconds -
        _acquisitionStopwatch!.elapsed.inSeconds;
    return remaining.clamp(0, _acquisitionTimeout.inSeconds);
  }

  String get _lockQualityLabel {
    if (!_fingerDetected) return 'Waiting for finger';
    if (_coverageScore < _displayCoverageThreshold) {
      return 'Cover lens more fully';
    }
    if (!_coverageStable) return 'Hold finger steadier';
    if (!_pulseStrengthReady) return 'Strengthen pulse signal';
    if (!_signalQualityReady) {
      return 'Acquiring stable heart rate signal';
    }
    if (!_bpmStable) return 'Collecting pulse';
    if (_acquisitionTimedOut &&
        !_canLock &&
        !_hasMeaningfulProgress) {
      return 'Reposition finger';
    }
    if (!_canLock) return 'Verifying reading';
    return 'Ready to lock';
  }

  String get _signalQualityLabel {
    final quality = _signalQuality;
    if (quality >= _lockSignalQualityThreshold) return 'Excellent';
    if (quality >= _displaySignalQualityThreshold) return 'Good';
    if (quality >= 0.35) return 'Fair';
    return 'Low';
  }

  double get _progress {
    if (widget.previewMode) return 0.5;
    if (!_canLock || _lockInCountdown == null) return 0.0;
    return (_lockInCountdown!.elapsedMilliseconds /
            _lockInHoldDuration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final label = _lockQualityLabel;
    if (label != _lastLoggedLockQuality) {
      _lastLoggedLockQuality = label;
      _debugLog(
        'Lock quality="$label" coverage=${(_coverageScore * 100).round()} signalQuality=${(_signalQuality * 100).round()} pulse=${(_pulseStrength * 100).round()} consistency=${(_intervalConsistency * 100).round()} median=$_currentMedian',
      );
    }
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
    if (!widget.previewMode && !_readyToRevealBpm) {
      return _buildAcquiringWaveform();
    }

    final displayedBpm = widget.previewMode
        ? (widget.previewBpm ?? 0)
        : (_readyToRevealBpm ? _currentMedian : 0);
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

  Widget _buildAcquiringWaveform() {
    final waveformSamples = _signalSamples.length >= 24
        ? _signalSamples.sublist(_signalSamples.length - 24)
        : List<double>.from(_signalSamples);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 220,
          height: 72,
          child: CustomPaint(
            painter: _HeartWaveformPainter(
              samples: waveformSamples,
              active: _fingerDetected,
              color: _scanRed,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _fingerDetected ? 'Acquiring pulse...' : 'Waiting for finger...',
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
                  ? (_readyToRevealBpm
                      ? 'Heart rate ready'
                      : 'Keep finger still for up to 45 secs.')
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
            if (_fingerDetected && !_readyToRevealBpm) ...[
              const SizedBox(height: 10),
              Text(
                _acquisitionTimedOut
                    ? 'Still not stable enough. Reposition your finger and try again.'
                    : 'Time remaining: ${_acquisitionSecondsRemaining}s',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Signal quality: $_signalQualityLabel ${(100 * _signalQuality).round()}%',
                style: TextStyle(
                  color: _signalQualityReady ? _hiltTeal : Colors.black54,
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
                'Pulse ${(100 * _pulseStrength).round()}%  Consistency ${(100 * _intervalConsistency).round()}%',
                style: TextStyle(
                  color: _pulseStrengthReady
                      ? _hiltTeal
                      : Colors.black54,
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

class _HeartWaveformPainter extends CustomPainter {
  const _HeartWaveformPainter({
    required this.samples,
    required this.active,
    required this.color,
  });

  final List<double> samples;
  final bool active;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final baseline = size.height / 2;
    final guidePaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      guidePaint,
    );

    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();

    if (samples.length >= 2) {
      final minValue = samples.reduce(math.min);
      final maxValue = samples.reduce(math.max);
      final range = math.max(maxValue - minValue, 0.001);

      for (var i = 0; i < samples.length; i++) {
        final x = (i / (samples.length - 1)) * size.width;
        final normalized = (samples[i] - minValue) / range;
        final y = size.height -
            (normalized * (size.height * 0.7)) -
            (size.height * 0.15);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    } else {
      final pulseHeight = active ? size.height * 0.28 : size.height * 0.10;
      path.moveTo(0, baseline);
      path.lineTo(size.width * 0.18, baseline);
      path.lineTo(size.width * 0.28, baseline - pulseHeight);
      path.lineTo(size.width * 0.38, baseline + (pulseHeight * 0.4));
      path.lineTo(size.width * 0.52, baseline - (pulseHeight * 0.2));
      path.lineTo(size.width * 0.66, baseline);
      path.lineTo(size.width, baseline);
    }

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _HeartWaveformPainter oldDelegate) {
    return oldDelegate.active != active ||
        oldDelegate.color != color ||
        oldDelegate.samples.length != samples.length ||
        !_sameSamples(oldDelegate.samples, samples);
  }

  bool _sameSamples(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i] - b[i]).abs() > 0.01) return false;
    }
    return true;
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

class _HeartBpmCameraViewState extends State<_HeartBpmCameraView>
    with WidgetsBindingObserver {
  static const _windowLength = 50;
  static const _torchRetryCount = 10;
  static Future<void> _cameraDisposeBarrier = Future<void>.value();

  CameraController? _controller;
  bool _processing = false;
  bool _isCameraInitialized = false;
  int _currentValue = 0;
  Timer? _captureSettingsRetryTimer;
  int _captureSettingsRetryTicks = 0;
  final List<SensorValue> _measureWindow = List<SensorValue>.filled(
    _windowLength,
    SensorValue(time: DateTime.now(), value: 0),
    growable: true,
  );

  void _debugLog(String message) {
    if (_CameraBpmScreenState._debugScannerLogs) {
      debugPrint('[ScannerCamera] $message');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initController());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captureSettingsRetryTimer?.cancel();
    unawaited(_deinitController());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.resumed) {
      _debugLog('App resumed; reapplying capture settings');
      unawaited(_ensureCaptureSettings(controller));
      _startCaptureSettingsRetries(controller);
    }
  }

  Future<void> _deinitController() async {
    _debugLog('Deinitializing camera controller');
    _isCameraInitialized = false;
    _captureSettingsRetryTimer?.cancel();
    _captureSettingsRetryTimer = null;
    _captureSettingsRetryTicks = 0;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    _cameraDisposeBarrier = _cameraDisposeBarrier.catchError((_) {}).then((_) async {
      if (controller.value.isStreamingImages) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
      }
      await controller.dispose();
    });
    await _cameraDisposeBarrier;
  }

  Future<void> _ensureCaptureSettings(CameraController controller) async {
    if (!controller.value.isInitialized) return;

    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {}
    try {
      await controller.setFlashMode(FlashMode.torch);
      _debugLog('Torch requested: ON');
    } catch (_) {}
    try {
      await controller.setExposureMode(ExposureMode.locked);
      _debugLog('Exposure requested: LOCKED');
    } catch (_) {}
    try {
      await controller.setFocusMode(FocusMode.locked);
      _debugLog('Focus requested: LOCKED');
    } catch (_) {}
  }

  void _startCaptureSettingsRetries(CameraController controller) {
    _captureSettingsRetryTimer?.cancel();
    _captureSettingsRetryTicks = 0;
    _captureSettingsRetryTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (timer) {
        if (!mounted || _controller != controller || !controller.value.isInitialized) {
          timer.cancel();
          return;
        }
        _debugLog('Retrying capture settings (${_captureSettingsRetryTicks + 1}/$_torchRetryCount)');
        unawaited(_ensureCaptureSettings(controller));
        _captureSettingsRetryTicks++;
        if (_captureSettingsRetryTicks >= _torchRetryCount) {
          timer.cancel();
          _debugLog('Finished capture settings retries');
        }
      },
    );
  }

  Future<void> _initController() async {
    if (_controller != null) return;
    await _cameraDisposeBarrier;
    _debugLog('Initializing camera controller');

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
      _debugLog('Camera initialized: ${backCamera.name}');
      await _ensureCaptureSettings(controller);

      await controller.startImageStream((image) {
        if (_processing || !mounted) return;
        _processing = true;
        _scanImage(image);
      });
      _debugLog('Image stream started');
      await _ensureCaptureSettings(controller);
      _startCaptureSettingsRetries(controller);

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

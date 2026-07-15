import 'dart:math' as math;

import 'package:camera/camera.dart';

class CameraSignalSample {
  const CameraSignalSample({
    required this.coverageBrightness,
    required this.pulseValue,
    required this.redChannelShare,
    required this.sampleCount,
  });

  final double coverageBrightness;
  final double pulseValue;
  final double redChannelShare;
  final int sampleCount;
}

class CameraSignalExtractor {
  CameraSignalExtractor._();

  static CameraSignalSample extract(CameraImage image) {
    if (image.planes.isEmpty || image.width <= 0 || image.height <= 0) {
      return const CameraSignalSample(
        coverageBrightness: 0,
        pulseValue: 0,
        redChannelShare: 0,
        sampleCount: 0,
      );
    }

    if (image.format.group == ImageFormatGroup.bgra8888 &&
        image.planes.length == 1) {
      return _extractBgra(image);
    }

    if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.length >= 3) {
      return _extractYuv420(image);
    }

    return _extractFallback(image);
  }

  static CameraSignalSample _extractBgra(CameraImage image) {
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final rowStride = plane.bytesPerRow;
    final pixelStride = plane.bytesPerPixel ?? 4;
    final region = _centerRegion(image.width, image.height);

    double coverageTotal = 0;
    double pulseTotal = 0;
    double redShareTotal = 0;
    int samples = 0;

    for (int y = region.top; y < region.bottom; y += region.step) {
      final rowOffset = y * rowStride;
      for (int x = region.left; x < region.right; x += region.step) {
        final offset = rowOffset + (x * pixelStride);
        if (offset + 2 >= bytes.length) continue;

        final b = bytes[offset].toDouble();
        final g = bytes[offset + 1].toDouble();
        final r = bytes[offset + 2].toDouble();

        coverageTotal += (0.114 * b) + (0.587 * g) + (0.299 * r);
        pulseTotal += r;
        redShareTotal += r / math.max(1.0, r + g + b);
        samples++;
      }
    }

    return _buildSample(coverageTotal, pulseTotal, redShareTotal, samples);
  }

  static CameraSignalSample _extractYuv420(CameraImage image) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;
    final region = _centerRegion(image.width, image.height);

    double coverageTotal = 0;
    double pulseTotal = 0;
    double redShareTotal = 0;
    int samples = 0;

    for (int y = region.top; y < region.bottom; y += region.step) {
      final yRowOffset = y * yPlane.bytesPerRow;
      final uvRowOffset = (y ~/ 2) * uPlane.bytesPerRow;
      final vvRowOffset = (y ~/ 2) * vPlane.bytesPerRow;

      for (int x = region.left; x < region.right; x += region.step) {
        final yOffset = yRowOffset + (x * yPixelStride);
        final uvOffset = uvRowOffset + ((x ~/ 2) * uPixelStride);
        final vOffset = vvRowOffset + ((x ~/ 2) * vPixelStride);
        if (yOffset >= yBytes.length ||
            uvOffset >= uBytes.length ||
            vOffset >= vBytes.length) {
          continue;
        }

        final yValue = yBytes[yOffset].toDouble();
        final uValue = uBytes[uvOffset].toDouble();
        final vValue = vBytes[vOffset].toDouble();
        final red = (yValue + 1.402 * (vValue - 128.0)).clamp(0.0, 255.0);
        final green =
            (yValue -
                    (0.344136 * (uValue - 128.0)) -
                    (0.714136 * (vValue - 128.0)))
                .clamp(0.0, 255.0);
        final blue = (yValue + 1.772 * (uValue - 128.0)).clamp(0.0, 255.0);

        coverageTotal += yValue;
        pulseTotal += red;
        redShareTotal += red / math.max(1.0, red + green + blue);
        samples++;
      }
    }

    return _buildSample(coverageTotal, pulseTotal, redShareTotal, samples);
  }

  static CameraSignalSample _extractFallback(CameraImage image) {
    final bytes = image.planes.first.bytes;
    if (bytes.isEmpty) {
      return const CameraSignalSample(
        coverageBrightness: 0,
        pulseValue: 0,
        redChannelShare: 0,
        sampleCount: 0,
      );
    }

    double total = 0;
    for (final byte in bytes) {
      total += byte;
    }
    final average = total / bytes.length;
    return CameraSignalSample(
      coverageBrightness: average,
      pulseValue: average,
      redChannelShare: 0,
      sampleCount: bytes.length,
    );
  }

  static CameraSignalSample _buildSample(
    double coverageTotal,
    double pulseTotal,
    double redShareTotal,
    int samples,
  ) {
    if (samples == 0) {
      return const CameraSignalSample(
        coverageBrightness: 0,
        pulseValue: 0,
        redChannelShare: 0,
        sampleCount: 0,
      );
    }

    return CameraSignalSample(
      coverageBrightness: coverageTotal / samples,
      pulseValue: pulseTotal / samples,
      redChannelShare: redShareTotal / samples,
      sampleCount: samples,
    );
  }

  static _SampleRegion _centerRegion(int width, int height) {
    final size = math.min(width, height);
    final step = math.max(2, size ~/ 48);
    final left = (width * 0.25).floor();
    final right = (width * 0.75).floor().clamp(left + 1, width);
    final top = (height * 0.25).floor();
    final bottom = (height * 0.75).floor().clamp(top + 1, height);
    return _SampleRegion(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      step: step,
    );
  }
}

class _SampleRegion {
  const _SampleRegion({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.step,
  });

  final int left;
  final int right;
  final int top;
  final int bottom;
  final int step;
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenpose/models/landmark.dart';
import 'package:zenpose/painters/skeleton_overlay_painter.dart';

void main() {
  group('SkeletonOverlayColorBands', () {
    test('computes dynamic band starts for threshold 60', () {
      final bands = SkeletonOverlayColorBands.fromThreshold(60.0);

      expect(bands.orangeStart, closeTo(34.2, 0.0001));
      expect(bands.yellowStart, closeTo(51.6, 0.0001));
      expect(bands.greenStart, closeTo(60.0, 0.0001));
    });

    test('maps boundary scores for threshold 60', () {
      final bands = SkeletonOverlayColorBands.fromThreshold(60.0);

      expect(
        bands.colorForScore(bands.orangeStart - 0.1),
        SkeletonOverlayColorBands.red,
      );
      expect(
        bands.colorForScore(bands.orangeStart),
        SkeletonOverlayColorBands.orange,
      );
      expect(
        bands.colorForScore(bands.orangeStart + 0.1),
        SkeletonOverlayColorBands.orange,
      );

      expect(
        bands.colorForScore(bands.yellowStart - 0.1),
        SkeletonOverlayColorBands.orange,
      );
      expect(
        bands.colorForScore(bands.yellowStart),
        SkeletonOverlayColorBands.yellow,
      );
      expect(
        bands.colorForScore(bands.yellowStart + 0.1),
        SkeletonOverlayColorBands.yellow,
      );

      expect(
        bands.colorForScore(bands.greenStart - 0.1),
        SkeletonOverlayColorBands.yellow,
      );
      expect(
        bands.colorForScore(bands.greenStart),
        SkeletonOverlayColorBands.green,
      );
      expect(
        bands.colorForScore(bands.greenStart + 0.1),
        SkeletonOverlayColorBands.green,
      );
    });

    test('maps boundary scores for threshold 70', () {
      final bands = SkeletonOverlayColorBands.fromThreshold(70.0);

      expect(bands.orangeStart, closeTo(39.9, 0.0001));
      expect(bands.yellowStart, closeTo(60.2, 0.0001));
      expect(bands.greenStart, closeTo(70.0, 0.0001));

      expect(
        bands.colorForScore(bands.orangeStart - 0.1),
        SkeletonOverlayColorBands.red,
      );
      expect(
        bands.colorForScore(bands.orangeStart),
        SkeletonOverlayColorBands.orange,
      );
      expect(
        bands.colorForScore(bands.orangeStart + 0.1),
        SkeletonOverlayColorBands.orange,
      );

      expect(
        bands.colorForScore(bands.yellowStart - 0.1),
        SkeletonOverlayColorBands.orange,
      );
      expect(
        bands.colorForScore(bands.yellowStart),
        SkeletonOverlayColorBands.yellow,
      );
      expect(
        bands.colorForScore(bands.yellowStart + 0.1),
        SkeletonOverlayColorBands.yellow,
      );

      expect(
        bands.colorForScore(bands.greenStart - 0.1),
        SkeletonOverlayColorBands.yellow,
      );
      expect(
        bands.colorForScore(bands.greenStart),
        SkeletonOverlayColorBands.green,
      );
      expect(
        bands.colorForScore(bands.greenStart + 0.1),
        SkeletonOverlayColorBands.green,
      );
    });

    test('treats unavailable score as lowest confidence', () {
      final bands = SkeletonOverlayColorBands.fromThreshold(60.0);
      expect(bands.colorForScore(null), SkeletonOverlayColorBands.red);
    });
  });

  group('SkeletonOverlayPainter', () {
    test('uses one resolved color source for bones and joints', () async {
      final painter = SkeletonOverlayPainter(
        landmarks: _sampleLandmarks(),
        similarityScore: 82.0,
        scoreThreshold: 70.0,
      );
      const imageSize = Size(100, 100);
      final image = await _paintToImage(painter, imageSize);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      expect(byteData, isNotNull);

      final linePixel = _pixelColor(byteData!, 100, 30, 20);
      final jointPixel = _pixelColor(byteData, 100, 20, 20);
      const expected = SkeletonOverlayColorBands.green;

      _expectColorClose(linePixel, expected);
      _expectColorClose(jointPixel, expected);
      _expectColorClose(linePixel, jointPixel);
    });
  });
}

Future<ui.Image> _paintToImage(SkeletonOverlayPainter painter, Size size) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  return picture.toImage(size.width.toInt(), size.height.toInt());
}

List<Landmark> _sampleLandmarks() {
  final landmarks = List<Landmark>.generate(
    29,
    (_) => Landmark.invalid,
    growable: false,
  );
  landmarks[11] = const Landmark(x: 0.20, y: 0.20); // left shoulder
  landmarks[13] = const Landmark(x: 0.40, y: 0.20); // left elbow
  return landmarks;
}

Color _pixelColor(ByteData bytes, int width, int x, int y) {
  final pixelOffset = (y * width + x) * 4;
  final r = bytes.getUint8(pixelOffset);
  final g = bytes.getUint8(pixelOffset + 1);
  final b = bytes.getUint8(pixelOffset + 2);
  final a = bytes.getUint8(pixelOffset + 3);
  return Color.fromARGB(a, r, g, b);
}

void _expectColorClose(Color actual, Color expected, {int tolerance = 2}) {
  expect(
    (_channelByte(actual.a) - _channelByte(expected.a)).abs(),
    lessThanOrEqualTo(tolerance),
  );
  expect(
    (_channelByte(actual.r) - _channelByte(expected.r)).abs(),
    lessThanOrEqualTo(tolerance),
  );
  expect(
    (_channelByte(actual.g) - _channelByte(expected.g)).abs(),
    lessThanOrEqualTo(tolerance),
  );
  expect(
    (_channelByte(actual.b) - _channelByte(expected.b)).abs(),
    lessThanOrEqualTo(tolerance),
  );
}

int _channelByte(double channel) => (channel * 255.0).round().clamp(0, 255);

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerGenerator {
  final jMarkerSize;
  double _circleStrokeWidth = 0;
  double _circleOffset = 0;
  double _outlineCircleWidth = 0;
  double _fillCircleWidth = 0;
  double _iconSize = 0;
  double _iconOffset = 0;

  MarkerGenerator({required this.jMarkerSize}) {
    // calculate marker dimensions
    _circleStrokeWidth = jMarkerSize / 10.0;
    _circleOffset = jMarkerSize / 2;
    _outlineCircleWidth = _circleOffset - (_circleStrokeWidth / 2);
    _fillCircleWidth = jMarkerSize / 2;
    final outlineCircleInnerWidth = jMarkerSize - (2 * _circleStrokeWidth);
    _iconSize = sqrt(pow(outlineCircleInnerWidth, 2) / 2);
    final rectDiagonal = sqrt(2 * pow(jMarkerSize, 2));
    final circleDistanceToCorners =
        (rectDiagonal - outlineCircleInnerWidth) / 2;
    _iconOffset = sqrt(pow(circleDistanceToCorners, 2) / 2);
  }

  /// Creates a BitmapDescriptor from an IconData
  Future<BitmapDescriptor> createBitmapDescriptorFromIconData(IconData iconData,
      Color iconColor, Color circleColor, Color backgroundColor) async {
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);

    _paintCircleFill(canvas, backgroundColor);
    _paintCircleStroke(canvas, circleColor);
    _paintIcon(canvas, iconColor, iconData);

    final picture = await pictureRecorder.endRecording();
    final image =
        await picture.toImage(jMarkerSize.round(), jMarkerSize.round());
    final bytes = await image.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Paints the icon background
  void _paintCircleFill(Canvas canvas, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawCircle(
        Offset(_circleOffset, _circleOffset), _fillCircleWidth, paint);
  }

  /// Paints a circle around the icon
  void _paintCircleStroke(Canvas canvas, Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = _circleStrokeWidth;
    canvas.drawCircle(
        Offset(_circleOffset, _circleOffset), _outlineCircleWidth, paint);
  }

  /// Paints the icon
  void _paintIcon(Canvas canvas, Color color, IconData iconData) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          letterSpacing: 0.0,
          fontSize: _iconSize,
          fontFamily: iconData.fontFamily,
          color: color,
        ));
    textPainter.layout();
    textPainter.paint(canvas, Offset(_iconOffset, _iconOffset));
  }
}

// =====================================================
// 🎯 AR ARROW PAINTER COMPLETO Y MEJORADO
// =====================================================
// 🔴 Flecha Roja: Apunta al destino con opacidad dinámica
// 🟡 Flecha Amarilla: Siempre visible al inicio, ayuda a girar si estás desviado
// 🧭 Muestra aviso de calibración si la brújula está desajustada
// ✅ Mensaje de llegada cuando estás muy cerca del destino
// =====================================================

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ArArrowPainter extends CustomPainter {
  final double compassHeading;
  final double pitch;
  final double roll;
  final double currentLat;
  final double currentLon;
  final double targetLat;
  final double targetLon;
  final double distanceToTarget;
  final double bearingToTarget;
  final double relativeAngle;
  final double pulseScale;
  final double rotationAngle;
  final Color arrowColor;
  final bool isCalibrated;

  ArArrowPainter({
    required this.compassHeading,
    required this.pitch,
    required this.roll,
    required this.currentLat,
    required this.currentLon,
    required this.targetLat,
    required this.targetLon,
    required this.distanceToTarget,
    required this.bearingToTarget,
    required this.relativeAngle,
    required this.pulseScale,
    required this.rotationAngle,
    required this.arrowColor,
    required this.isCalibrated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isCalibrated) {
      _drawCalibrationWarning(canvas, size);
      return;
    }

    final absRel = rotationAngle.abs();
    final arrowPosition = _calculateArrowPosition(size);

    double redOpacity = 1.0;
    if (absRel > 10 && absRel <= 30) redOpacity = 0.85;
    else if (absRel > 30) redOpacity = 0.6;

    _draw3DArrow(canvas, arrowPosition, size, opacity: redOpacity);
    _drawDistanceLabel(canvas, arrowPosition);

    if (absRel > 10 || distanceToTarget < 5) {
      final yellowOpacity = (absRel > 30 || distanceToTarget < 5) ? 1.0 : 0.5;
      _drawSmallGuideArrow(canvas, size, opacity: yellowOpacity);
    }

    if (distanceToTarget < 5) {
      _drawArrivalText(canvas, size);
    }
  }

  Offset _calculateArrowPosition(Size size) {
    final horizontalOffset = size.width / 2;
    double verticalBase = size.height * 0.55;
    final perspectiveOffset = (100 / (distanceToTarget + 10)).clamp(0.0, 50.0);
    final pitchAdjustment = pitch * 3;
    final verticalOffset = verticalBase + perspectiveOffset - pitchAdjustment;
    return Offset(horizontalOffset, verticalOffset);
  }

  void _draw3DArrow(Canvas canvas, Offset position, Size size, {double opacity = 1.0}) {
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(_toRadians(relativeAngle));
    canvas.scale(pulseScale);
    canvas.scale(_calculateDistanceScale());

    final arrowSize = 80.0;
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.6 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    final shadowOffset = const Offset(6, 6);
    _drawArrowShape(canvas, arrowSize, shadowPaint, shadowOffset);

    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(-arrowSize / 4, 0),
        Offset(arrowSize / 4, 0),
        [
          arrowColor.withOpacity(0.8 * opacity),
          arrowColor.withOpacity(opacity),
          arrowColor.withOpacity(0.8 * opacity),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;
    _drawArrowShape(canvas, arrowSize, bodyPaint, Offset.zero);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    _drawArrowShape(canvas, arrowSize, borderPaint, Offset.zero);

    final highlightPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, -arrowSize * 0.8),
        Offset(0, -arrowSize * 0.4),
        [Colors.white.withOpacity(0.6 * opacity), Colors.transparent],
      );
    final highlightPath = Path()
      ..moveTo(0, -arrowSize * 0.9)
      ..lineTo(-arrowSize * 0.15, -arrowSize * 0.5)
      ..lineTo(arrowSize * 0.15, -arrowSize * 0.5)
      ..close();
    canvas.drawPath(highlightPath, highlightPaint);

    canvas.restore();
  }

  void _drawArrowShape(Canvas canvas, double size, Paint paint, Offset offset) {
    final path = Path()
      ..moveTo(0 + offset.dx, -size + offset.dy)
      ..lineTo(-size * 0.5 + offset.dx, -size * 0.5 + offset.dy)
      ..lineTo(-size * 0.2 + offset.dx, -size * 0.5 + offset.dy)
      ..lineTo(-size * 0.2 + offset.dx, size * 0.3 + offset.dy)
      ..lineTo(size * 0.2 + offset.dx, size * 0.3 + offset.dy)
      ..lineTo(size * 0.2 + offset.dx, -size * 0.5 + offset.dy)
      ..lineTo(size * 0.5 + offset.dx, -size * 0.5 + offset.dy)
      ..close();

    if (paint.style == PaintingStyle.fill) {
      final leftShadePaint = Paint()
        ..color = arrowColor.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      final leftShadePath = Path()
        ..moveTo(-size * 0.2 + offset.dx, -size * 0.5 + offset.dy)
        ..lineTo(-size * 0.5 + offset.dx, -size * 0.5 + offset.dy)
        ..lineTo(0 + offset.dx, -size + offset.dy)
        ..close();
      canvas.drawPath(leftShadePath, leftShadePaint);
    }

    canvas.drawPath(path, paint);
  }

  void _drawSmallGuideArrow(Canvas canvas, Size size, {double opacity = 1.0}) {
    final isLeft = relativeAngle < 0;
    final edgeX = isLeft ? 60.0 : size.width - 60;
    final edgeY = size.height / 2;

    canvas.save();
    canvas.translate(edgeX, edgeY);
    canvas.rotate(_toRadians(isLeft ? -90 : 90));

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final shadowPath = Path()
      ..moveTo(0, -30)
      ..lineTo(-22, 18)
      ..lineTo(22, 18)
      ..close();
    canvas.drawPath(shadowPath.shift(const Offset(3, 3)), shadowPaint);

    final indicatorPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, -30),
        const Offset(0, 18),
        [
          Colors.yellow.withOpacity(opacity),
          Colors.orange.withOpacity(opacity),
        ],
      );
    final indicatorPath = Path()
      ..moveTo(0, -30)
      ..lineTo(-22, 18)
      ..lineTo(22, 18)
      ..close();
    canvas.drawPath(indicatorPath, indicatorPaint);

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(indicatorPath, borderPaint);

    canvas.restore();

    if (opacity > 0.7) {
      final textSpan = TextSpan(
        text: '📱 Gira aquí',
        style: TextStyle(
          color: Colors.white.withOpacity(opacity),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 8)],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(edgeX - textPainter.width / 2, edgeY + 60),
      );
    }
  }

  void _drawDistanceLabel(Canvas canvas, Offset position) {
    final distanceText = distanceToTarget < 1000
        ? '${distanceToTarget.toStringAsFixed(0)} m'
        : '${(distanceToTarget / 1000).toStringAsFixed(1)} km';

    final textSpan = TextSpan(
      text: distanceText,
      style: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 8)],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(position.dx - textPainter.width / 2, position.dy + 60),
    );
  }

  void _drawCalibrationWarning(Canvas canvas, Size size) {
    final warningPaint = Paint()
      ..color = Colors.orange.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.8,
        height: 120,
      ),
      const Radius.circular(16),
    );

    canvas.drawRRect(rect, warningPaint);

    final textSpan = TextSpan(
      text: '⚠️ Calibración necesaria\nMueve el dispositivo en forma de 8',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        height: 1.5,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(maxWidth: size.width * 0.7);
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height / 2 - textPainter.height / 2,
      ),
    );
  }

  void _drawArrivalText(Canvas canvas, Size size) {
    final textSpan = TextSpan(
      text: '🎯 ¡Llegaste a tu destino!',
      style: const TextStyle(
        color: Colors.greenAccent,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Colors.black, blurRadius: 10)],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        size.height * 0.1,
      ),
    );
  }

  double _calculateDistanceScale() {
    if (distanceToTarget < 10) return 1.3;
    if (distanceToTarget < 30) return 1.1;
    if (distanceToTarget < 50) return 1.0;
    if (distanceToTarget < 100) return 0.9;
    return 0.8;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(ArArrowPainter old) {
    return compassHeading != old.compassHeading ||
        pitch != old.pitch ||
        relativeAngle != old.relativeAngle ||
        distanceToTarget != old.distanceToTarget ||
        pulseScale != old.pulseScale;
  }
}

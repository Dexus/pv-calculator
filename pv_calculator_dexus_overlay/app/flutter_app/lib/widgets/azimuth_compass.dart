import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Translucent compass dial overlay for tap-to-pick azimuth.
///
/// The user drags or taps anywhere inside the dial; the widget converts
/// the touch point into a 0–360° azimuth (0 = north, 90 = east, 180 =
/// south, 270 = west — engine convention) and forwards it to
/// [onChanged]. Designed to be parked inside a `Positioned` corner of
/// the map; sized via [size].
class AzimuthCompass extends StatelessWidget {
  const AzimuthCompass({
    super.key,
    required this.azimuthDeg,
    required this.onChanged,
    this.size = 240,
  });

  /// Current azimuth (engine convention). Drives the needle position.
  final double azimuthDeg;

  /// Fired on every drag update / tap. Caller decides whether to
  /// commit to the draft immediately or debounce.
  final ValueChanged<double> onChanged;

  /// Outer diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Semantics: expose as an adjustable value so screen readers and
    // switch-access users can increment/decrement by 5° steps. The
    // gesture-only API has no keyboard path without this wrapper.
    return Semantics(
      label: 'Azimuth compass',
      value: '${azimuthDeg.toStringAsFixed(0)}°',
      increasedValue: '${((azimuthDeg + 5) % 360).toStringAsFixed(0)}°',
      decreasedValue: '${((azimuthDeg - 5 + 360) % 360).toStringAsFixed(0)}°',
      onIncrease: () => onChanged((azimuthDeg + 5) % 360),
      onDecrease: () => onChanged((azimuthDeg - 5 + 360) % 360),
      child: SizedBox(
        width: size,
        height: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _emit(details.localPosition),
          onPanUpdate: (details) => _emit(details.localPosition),
          child: CustomPaint(
            painter: _CompassPainter(
              azimuthDeg: azimuthDeg,
              tickColor: scheme.onSurface,
              needleColor: scheme.primary,
              background: scheme.surface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  void _emit(Offset local) {
    final dx = local.dx - size / 2;
    final dy = local.dy - size / 2;
    if (dx == 0 && dy == 0) return;
    // atan2 returns angle from +x (east), measured CCW. Convert to
    // engine convention (0 = north, clockwise positive).
    final radFromEast = math.atan2(dy, dx);
    var deg = (radFromEast * 180.0 / math.pi) + 90.0;
    deg = (deg + 360.0) % 360.0;
    onChanged(deg);
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.azimuthDeg,
    required this.tickColor,
    required this.needleColor,
    required this.background,
  });

  final double azimuthDeg;
  final Color tickColor;
  final Color needleColor;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;

    // Translucent backdrop so the underlying map stays visible.
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = background,
    );

    // Outer ring.
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = tickColor.withValues(alpha: 0.35),
    );

    // 72 ticks every 5° — long every 30°, medium every 15°, short else.
    final tickPaintMajor = Paint()
      ..color = tickColor.withValues(alpha: 0.8)
      ..strokeWidth = 2;
    final tickPaintMinor = Paint()
      ..color = tickColor.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    for (var i = 0; i < 72; i++) {
      final angleDeg = i * 5.0;
      final isMajor = angleDeg % 30 == 0;
      final isMid = !isMajor && angleDeg % 15 == 0;
      final tickLen = isMajor ? 14.0 : (isMid ? 9.0 : 5.0);
      final paint = isMajor || isMid ? tickPaintMajor : tickPaintMinor;
      final rad = (angleDeg - 90) * math.pi / 180.0;
      final outer = Offset(
        center.dx + (radius - 4) * math.cos(rad),
        center.dy + (radius - 4) * math.sin(rad),
      );
      final inner = Offset(
        center.dx + (radius - 4 - tickLen) * math.cos(rad),
        center.dy + (radius - 4 - tickLen) * math.sin(rad),
      );
      canvas.drawLine(inner, outer, paint);
    }

    // Cardinal labels (N/E/S/W) at the engine-convention positions.
    final labelStyle = TextStyle(
      color: tickColor,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    void label(String text, double angleDeg, {double radial = 0.78}) {
      final rad = (angleDeg - 90) * math.pi / 180.0;
      final centerLabel = Offset(
        center.dx + radius * radial * math.cos(rad),
        center.dy + radius * radial * math.sin(rad),
      );
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        centerLabel - Offset(tp.width / 2, tp.height / 2),
      );
    }

    label('N', 0);
    label('E', 90);
    label('S', 180);
    label('W', 270);

    // Needle pointing at the current azimuth.
    final needleRad = (azimuthDeg - 90) * math.pi / 180.0;
    final tip = Offset(
      center.dx + (radius - 24) * math.cos(needleRad),
      center.dy + (radius - 24) * math.sin(needleRad),
    );
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = needleColor
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      center,
      6,
      Paint()..color = needleColor,
    );

    // Numeric readout right under the centre.
    final readout = TextPainter(
      text: TextSpan(
        text: '${azimuthDeg.toStringAsFixed(0)}°',
        style: labelStyle.copyWith(fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    readout.paint(
      canvas,
      Offset(center.dx - readout.width / 2, center.dy + 12),
    );
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      old.azimuthDeg != azimuthDeg ||
      old.tickColor != tickColor ||
      old.needleColor != needleColor ||
      old.background != background;
}

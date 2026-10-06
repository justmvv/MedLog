import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Палитра calorie_cam: травяные зелёные, переходящие в насыщенный синий.
class C {
  static const canvas = Color(0xFFF5F9F0);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF13262A);
  static const inkSoft = Color(0xFF5B6D66);

  /// Основной акцент — глубокий травяной.
  static const accent = Color(0xFF3E7F2C);

  /// Внимание (просрочено) — насыщенный синий.
  static const alert = Color(0xFF2F6BEA);

  /// Полностью выполненный день на тепловой карте.
  static const deep = Color(0xFF0B2A86);
  static const soft = Color(0xFFB2DE84);
  static const tint = Color(0xFFE4F2D5);
  static const line = Color(0xFFCFE0C2);
  static const lineSoft = Color(0xFFE3EDDA);

  static const _heat = [
    Color(0xFFB2DE84), // herbLight
    Color(0xFF5E9E3A), // herb
    Color(0xFF2F6BEA), // blue
    Color(0xFF0B2A86), // blueDeep
  ];

  /// Шкала тепловой карты: светлая трава → зелень → насыщенный синий.
  static Color ramp(double t) {
    final x = t.clamp(0.0, 1.0) * (_heat.length - 1);
    final i = x.floor().clamp(0, _heat.length - 2);
    return Color.lerp(_heat[i], _heat[i + 1], x - i)!;
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF5E9E3A),
    primary: C.accent,
    secondary: C.alert,
    tertiary: C.alert,
    surface: C.canvas,
    onSurface: C.ink,
  );
  const stroke = BorderSide(color: C.line, width: 1.4);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(6),
    side: stroke,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.canvas,
    fontFamilyFallback: const ['Roboto', 'Helvetica Neue', 'Arial'],
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w300,
        color: C.ink,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(fontWeight: FontWeight.w400, color: C.ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w500, color: C.ink),
      bodyMedium: TextStyle(color: C.ink),
      bodySmall: TextStyle(color: C.inkSoft),
      labelSmall: TextStyle(color: C.inkSoft, letterSpacing: 1.2),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: C.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: C.ink,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: C.paper,
      elevation: 0,
      shape: shape,
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: C.lineSoft, thickness: 1),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.accent,
        side: const BorderSide(color: C.accent, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: C.paper,
      foregroundColor: C.accent,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: C.accent, width: 1.6),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: C.line, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: const BorderSide(color: C.accent, width: 1.4),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.canvas,
      surfaceTintColor: Colors.transparent,
      indicatorColor: C.tint,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: C.soft, width: 1.2),
      ),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, color: C.ink),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? C.accent : C.inkSoft,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: C.canvas,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.canvas,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
  );
}

// ── Штриховка ────────────────────────────────────────────────

/// Диагональная штриховка. [density] 0..1 — от редких линий к плотным.
class HatchPainter extends CustomPainter {
  HatchPainter({
    required this.color,
    this.density = 0.5,
    this.strokeWidth = 1.1,
    this.angle = -math.pi / 4,
    this.radius = 0,
  });

  final Color color;
  final double density;
  final double strokeWidth;
  final double angle;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (density <= 0) return;
    final gap = 14 - 10 * density.clamp(0.0, 1.0); // 14px … 4px
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final p = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final diag = size.width + size.height;
    final dx = math.cos(angle), dy = math.sin(angle);
    canvas.translate(size.width / 2, size.height / 2);
    for (double o = -diag; o <= diag; o += gap) {
      // линия, перпендикулярно сдвинутая на o
      final cx = -dy * o, cy = dx * o;
      canvas.drawLine(
        Offset(cx - dx * diag, cy - dy * diag),
        Offset(cx + dx * diag, cy + dy * diag),
        p,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HatchPainter old) =>
      old.color != color ||
      old.density != density ||
      old.strokeWidth != strokeWidth ||
      old.angle != angle;
}

/// Пунктирная рамка (для будущих/пустых ячеек).
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, this.radius = 4, this.dash = 3});

  final Color color;
  final double radius;
  final double dash;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(0.6),
          Radius.circular(radius),
        ),
      );
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += dash * 2) {
        canvas.drawPath(m.extractPath(d, d + dash), p);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) => old.color != color;
}

/// Штрихованный прогресс-бар.
class HatchProgress extends StatelessWidget {
  const HatchProgress({super.key, required this.value, this.height = 10});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: C.line, width: 1.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                width: c.maxWidth * value.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  border: Border.all(color: C.accent, width: 1.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: CustomPaint(
                  painter: HatchPainter(color: C.accent, density: 0.75),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Чек-бокс «от руки»: контур квадрата, при отметке — штриховка и галка.
class StrokeCheck extends StatelessWidget {
  const StrokeCheck({super.key, required this.checked, this.size = 30});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: checked ? 1 : 0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) =>
          CustomPaint(size: Size.square(size), painter: _CheckPainter(t)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Color.lerp(C.line, C.accent, t)!,
    );
    if (t <= 0) return;
    HatchPainter(
      color: C.soft.withValues(alpha: t),
      density: 0.55,
      radius: 4,
    ).paint(canvas, size);
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.2, w * 0.52)
      ..lineTo(w * 0.42, w * 0.74)
      ..lineTo(w * 0.86, w * 0.18);
    final m = path.computeMetrics().first;
    canvas.drawPath(
      m.extractPath(0, m.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = C.accent,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

/// Логотип — гранёный крест (assets/logo.png, генерирует tool/make_icons.py).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 34});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/logo.png',
    width: size,
    height: size,
    filterQuality: FilterQuality.medium,
  );
}

/// Заголовок секции: мелкие капители + тонкая линия.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 8),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Пустое состояние со штриховкой.
class HatchEmpty extends StatelessWidget {
  const HatchEmpty({super.key, required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: C.lineSoft, width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: CustomPaint(
        painter: HatchPainter(color: C.lineSoft, density: 0.2, radius: 6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          child: Column(
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (action != null) ...[const SizedBox(height: 10), action!],
            ],
          ),
        ),
      ),
    );
  }
}

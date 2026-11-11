import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

abstract final class Wellness {
  static const cream = Color(0xFFFFF8EF);
  static const paper = Color(0xFFFFFCF7);
  static const forest = Color(0xFF103D2B);
  static const leaf = Color(0xFF46753A);
  static const sage = Color(0xFFDFEACF);
  static const muted = Color(0xFF536457);
  static const title = TextStyle(
    fontSize: 19,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: forest,
  );
  static const body = TextStyle(fontSize: 16, height: 1.45, color: muted);

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return base.copyWith(
      scaffoldBackgroundColor: cream,
      colorScheme: base.colorScheme.copyWith(primary: forest, surface: paper),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: forest,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.disabled,
          disabledForegroundColor: muted,
          shape: shape,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: forest,
          side: const BorderSide(color: forest, width: 1.2),
          shape: shape,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: paper,
        hintStyle: body,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: forest),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: forest, width: 2),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class WellnessHeader extends StatelessWidget implements PreferredSizeWidget {
  const WellnessHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.demo = false,
  });
  final String title;
  final VoidCallback? onBack;
  final bool demo;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 64,
    backgroundColor: Wellness.cream,
    foregroundColor: Wellness.forest,
    leading: IconButton(
      tooltip: 'Quay lại',
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back_rounded, size: 28),
    ),
    titleSpacing: 4,
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Wellness.forest,
      ),
    ),
    actions: [
      if (demo)
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Wellness.sage,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Text(
              'Minh họa',
              style: TextStyle(
                color: Wellness.forest,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
    ],
  );
}

class WellnessCard extends StatelessWidget {
  const WellnessCard({super.key, required this.child, this.botanical = false});
  final Widget child;
  final bool botanical;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Wellness.paper,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFF0E9DC)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x172F2618),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          if (botanical)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 36,
              child: IgnorePointer(
                child: CustomPaint(painter: BotanicalPainter(compact: true)),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, botanical ? 27 : 14),
            child: child,
          ),
        ],
      ),
    ),
  );
}

class WellnessSectionTitle extends StatelessWidget {
  const WellnessSectionTitle(this.text, this.icon, {super.key, this.trailing});
  final String text;
  final IconData icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 25, color: Wellness.leaf),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: Wellness.title)),
      if (trailing != null) ...[const SizedBox(width: 5), trailing!],
    ],
  );
}

class LeafBrand extends StatelessWidget {
  const LeafBrand({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      SizedBox(
        width: 32,
        height: 32,
        child: CustomPaint(painter: _BrandLeaves()),
      ),
      SizedBox(width: 10),
      Flexible(
        child: Text(
          'Longevity Plate',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Wellness.forest,
          ),
        ),
      ),
    ],
  );
}

class _BrandLeaves extends CustomPainter {
  const _BrandLeaves();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 40, size.height / 40);
    canvas.drawPath(
      Path()
        ..moveTo(19, 34)
        ..quadraticBezierTo(1, 34, 2, 18)
        ..quadraticBezierTo(19, 17, 19, 34),
      Paint()..color = Wellness.leaf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(22, 31)
        ..quadraticBezierTo(16, 4, 39, 3)
        ..quadraticBezierTo(39, 25, 22, 31),
      Paint()..color = const Color(0xFF73924B),
    );
    canvas.drawLine(
      const Offset(23, 29),
      const Offset(32, 12),
      Paint()
        ..color = Wellness.paper
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small code-drawn botanical decoration, never a screenshot of UI.
class BotanicalPainter extends CustomPainter {
  const BotanicalPainter({this.compact = false});
  final bool compact;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final wave = Path()
      ..moveTo(0, h * .42)
      ..cubicTo(w * .26, -h * .05, w * .34, h * 1.03, w * .59, h * .65)
      ..cubicTo(w * .77, h * .23, w * .82, h * .18, w, h * .5)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFDDE4C3), Color(0x00E9EBD6)],
        ).createShader(Offset.zero & size),
    );
    final wave2 = Path()
      ..moveTo(w * .3, h * .67)
      ..cubicTo(w * .58, h * 1.01, w * .78, h * .22, w, h * .38)
      ..lineTo(w, h)
      ..lineTo(w * .3, h)
      ..close();
    canvas.drawPath(wave2, Paint()..color = const Color(0x44DFE4BD));
    canvas.save();
    final leafHeight = compact ? h * 1.0 : h * .85;
    canvas.translate(w - leafHeight * .92 - 8, h - leafHeight);
    canvas.scale(leafHeight / 100);
    final stem = Paint()
      ..color = const Color(0xFFA8BA7F)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(53, 100)
        ..quadraticBezierTo(40, 61, 65, 23),
      stem,
    );
    final leaf = Paint()..color = const Color(0xFFB6C590);
    canvas.drawPath(
      Path()
        ..moveTo(60, 47)
        ..quadraticBezierTo(52, 12, 90, 0)
        ..quadraticBezierTo(87, 32, 60, 47),
      leaf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(48, 63)
        ..quadraticBezierTo(22, 63, 20, 28)
        ..quadraticBezierTo(48, 33, 48, 63),
      leaf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(48, 83)
        ..quadraticBezierTo(20, 84, 0, 69)
        ..quadraticBezierTo(29, 55, 48, 83),
      leaf,
    );
    canvas.drawPath(
      Path()
        ..moveTo(53, 91)
        ..quadraticBezierTo(53, 57, 89, 48)
        ..quadraticBezierTo(82, 80, 53, 91),
      leaf,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BotanicalPainter oldDelegate) =>
      compact != oldDelegate.compact;
}

class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key});
  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      width: 26,
      height: 26,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    ),
  );
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.4;
    for (final part in [
      (const Color(0xFF4285F4), -40.0, 85.0),
      (const Color(0xFF34A853), 45.0, 95.0),
      (const Color(0xFFFBBC05), 140.0, 65.0),
      (const Color(0xFFEA4335), 205.0, 105.0),
    ]) {
      canvas.drawArc(
        rect,
        part.$2 * math.pi / 180,
        part.$3 * math.pi / 180,
        false,
        paint..color = part.$1,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(size.width * .52, size.height * .43, size.width * .43, 5.1),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedPhotoBorder extends CustomPainter {
  const DashedPhotoBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(16),
        ),
      );
    final paint = Paint()
      ..color = const Color(0xFF9DB489)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (var start = 0.0; start < metric.length; start += 10) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 6, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

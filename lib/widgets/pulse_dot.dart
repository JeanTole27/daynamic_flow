import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Small breathing dot — ported from the `tpulse` keyframe animation next
/// to "Empieza en 42 minutos" on the employee home screen.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = AppColors.onPrimary, this.size = 7});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Opacity(
          opacity: 0.35 + t * 0.65,
          child: Transform.scale(
            scale: 0.9 + t * 0.25,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

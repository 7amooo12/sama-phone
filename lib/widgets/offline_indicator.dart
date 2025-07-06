import 'package:flutter/material.dart';


class OfflineIndicator extends StatelessWidget {

  const OfflineIndicator({
    super.key,
    required this.child,
  });
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white),
            const SizedBox(width: 8),
            const Text(
              'لا يوجد اتصال بالإنترنت',
              style: TextStyle(color: Colors.white),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// رسم الفازة المكسورة
class BrokenVasePainter extends CustomPainter {

  BrokenVasePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // الجزء العلوي من الفازة (الجزء المكسور)
    path.moveTo(size.width * 0.3, 0);
    path.lineTo(size.width * 0.7, 0);
    path.lineTo(size.width * 0.65, size.height * 0.3);
    path.lineTo(size.width * 0.55, size.height * 0.35);
    // خط الكسر
    path.lineTo(size.width * 0.45, size.height * 0.28);
    path.lineTo(size.width * 0.35, size.height * 0.3);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// رسم الشقوق في الفازة
class CrackPainter extends CustomPainter {

  CrackPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // رسم الشقوق
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.3, size.height * 0.3);
    path.lineTo(size.width * 0.2, size.height * 0.5);

    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width * 0.7, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height * 0.6);

    path.moveTo(size.width * 0.5, size.height * 0.2);
    path.lineTo(size.width * 0.5, size.height * 0.7);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
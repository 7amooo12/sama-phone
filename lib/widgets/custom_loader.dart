import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class CustomLoader extends StatelessWidget {
  const CustomLoader({
    super.key,
    this.size = 50.0,
    this.color,
    this.message,
  });
  
  final double size;
  final Color? color;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpinKitFadingCircle(
            size: size,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color ?? Theme.of(context).colorScheme.primary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

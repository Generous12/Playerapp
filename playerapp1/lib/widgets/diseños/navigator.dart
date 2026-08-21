import 'package:flutter/material.dart';

class SwipeLeftNavigator extends StatelessWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;

  const SwipeLeftNavigator({
    super.key,
    required this.child,
    required this.onSwipeLeft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Velocidad negativa = swipe hacia la izquierda
        if (details.primaryVelocity != null &&
            details.primaryVelocity! < -300) {
          onSwipeLeft();
        }
      },
      child: child,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';

class SongMarqueeTitle extends StatelessWidget {
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  const SongMarqueeTitle({
    super.key,
    required this.text,
    required this.color,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );

    return SizedBox(
      height: fontSize + 6,
      child: text.length > 25
          ? Marquee(
              key: ValueKey(text),
              text: text,
              style: style,
              velocity: 30,
              blankSpace: 40,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 0,
              accelerationDuration: const Duration(milliseconds: 500),
              decelerationDuration: const Duration(milliseconds: 500),
              fadingEdgeStartFraction: 0.1,
              fadingEdgeEndFraction: 0.1,
            )
          : Text(
              text,
              style: style,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
    );
  }
}
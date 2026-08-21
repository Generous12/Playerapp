import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final bool italic;
  final bool underline;
  final double height;

  // 🔥 NUEVAS PROPIEDADES AGREGADAS
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool softWrap;

  const CustomText({
    super.key,
    required this.text,
    this.fontSize = 14,
    this.color = Colors.white,
    this.fontWeight = FontWeight.normal,
    this.italic = false,
    this.underline = false,
    this.height = 1.0,

    // 🔥 NUEVO DEFAULT SAFE
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap = true,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
        height: height,
      ),
    );
  }
}
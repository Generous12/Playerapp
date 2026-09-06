import 'package:flutter/material.dart';

class CustomText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final bool italic;
  final bool underline;
  final double height;

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

/// 📝 WIDGET UNIFICADO DE ENTRADA DE TEXTO (CustomTextField)
class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double fontSize;
  final bool isSmallDevice;
  final TextInputAction? textInputAction;

  const CustomTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.fontSize = 14,
    this.isSmallDevice = false,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveFillColor = isDark
        ? const Color(0xFF1F2234)
        : const Color.fromARGB(255, 255, 255, 255);

    return TextField(
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      textInputAction: textInputAction ?? TextInputAction.search,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onChanged: onChanged,
      onSubmitted: (val) {
        FocusScope.of(context).unfocus();
        onSubmitted?.call(val);
      },
      style: TextStyle(
        fontSize: isSmallDevice ? fontSize - 1 : fontSize,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          fontSize: isSmallDevice ? 12 : 13,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        hintText: hintText,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          fontSize: isSmallDevice ? 12 : 13,
        ),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: effectiveFillColor,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: isSmallDevice ? 10 : 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: theme.colorScheme.onSurface.withValues(
              alpha: isDark ? 0.08 : 0.05,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

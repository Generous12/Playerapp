import 'package:flutter/material.dart';
import 'package:playerapp1/colores/appcolors.dart';

class CustomDialog {
  const CustomDialog._();

  static Future<bool?> show({
    required BuildContext context,

    /// TÍTULO
    String title = "Confirmación",
    Color? titleColor,
    double titleSize = 18,
    FontWeight titleWeight = FontWeight.bold,

    /// MENSAJE
    String? message,
    Widget? content,
    Color? messageColor,
    double messageSize = 14,

    /// ICONO
    Widget? icon,

    /// APARIENCIA
    Color? backgroundColor,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(24)),
    bool barrierDismissible = true,

    /// BOTÓN CANCELAR
    bool showCancelButton = true,
    String cancelText = "Cancelar",
    Color? cancelTextColor,

    /// BOTÓN ACEPTAR
    String confirmText = "Aceptar",
    Color? confirmTextColor,
    Color? confirmButtonColor,

    /// ACCIONES
    Future<void> Function()? onConfirm,
    Future<void> Function()? onCancel,
  }) {
    final effectiveConfirmButtonColor = confirmButtonColor ?? AppColors.primary;
    final effectiveConfirmTextColor = confirmTextColor ?? AppColors.white;
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        final dialogBackground = backgroundColor ??
            (isDark ? const Color(0xFF11131B) : Colors.white);

        final titleTextColor =
            titleColor ?? (isDark ? Colors.white : Colors.black87);

        final messageTextColor = messageColor ??
            (isDark ? Colors.white70 : Colors.black54);

        final cancelColor = cancelTextColor ??
            (isDark ? Colors.white70 : Colors.black54);

        return Dialog(
          backgroundColor: dialogBackground,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: theme.colorScheme.onSurface.withValues(
                alpha: isDark ? 0.08 : 0.05,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// ICONO
                if (icon != null) ...[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: icon),
                  ),
                  const SizedBox(height: 16),
                ],

                /// TÍTULO
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: titleTextColor,
                    fontSize: titleSize,
                    fontWeight: titleWeight,
                    letterSpacing: -0.2,
                  ),
                ),

                const SizedBox(height: 10),

                /// CONTENIDO
                content ??
                    Text(
                      message ?? "",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: messageTextColor,
                        fontSize: messageSize,
                        height: 1.4,
                      ),
                    ),

                const SizedBox(height: 24),

                /// BOTONES EN PÍLDORA
                Row(
                  children: [
                    if (showCancelButton) ...[
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: cancelColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: isDark ? 0.1 : 0.15,
                                ),
                              ),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.pop(context, false);
                            if (onCancel != null) {
                              await onCancel();
                            }
                          },
                          child: Text(
                            cancelText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cancelColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: effectiveConfirmButtonColor,
                          foregroundColor: effectiveConfirmTextColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context, true);
                          if (onConfirm != null) {
                            await onConfirm();
                          }
                        },
                        child: Text(
                          confirmText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: effectiveConfirmTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

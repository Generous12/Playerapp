import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class CustomDialog {
  const CustomDialog._();

  /// 💬 DIÁLOGO GENÉRICO LIMPIO Y MINIMALISTA
  static Future<bool?> show({
    required BuildContext context,

    /// TÍTULO
    String title = "Confirmación",
    Color? titleColor,
    double titleSize = 17,
    FontWeight titleWeight = FontWeight.bold,

    /// MENSAJE
    String? message,
    Widget? content,
    Color? messageColor,
    double messageSize = 13.5,

    /// ICONO
    Widget? icon,

    /// APARIENCIA
    Color? backgroundColor,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(22)),
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
    final effectiveConfirmTextColor = confirmTextColor ?? Colors.white;

    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        final dialogBackground = backgroundColor ??
            (isDark ? const Color(0xFF141624) : Colors.white);

        final titleTextColor =
            titleColor ?? (isDark ? Colors.white : const Color(0xFF11131B));

        final messageTextColor = messageColor ??
            (isDark ? Colors.white70 : Colors.black54);

        final cancelColor = cancelTextColor ??
            (isDark ? Colors.white70 : Colors.black54);

        return Dialog(
          backgroundColor: dialogBackground,
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: theme.colorScheme.onSurface.withValues(
                alpha: isDark ? 0.08 : 0.06,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                /// ICONO ELEGANTE
                if (icon != null) ...[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: effectiveConfirmButtonColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: icon),
                  ),
                  const SizedBox(height: 14),
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

                const SizedBox(height: 8),

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

                const SizedBox(height: 22),

                /// BOTONES EN PÍLDORA MODERNOS
                Row(
                  children: [
                    if (showCancelButton) ...[
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: cancelColor,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: isDark ? 0.12 : 0.15,
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
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: cancelColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: effectiveConfirmButtonColor,
                          foregroundColor: effectiveConfirmTextColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                            fontSize: 13.5,
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

  /// 🗑️ DIÁLOGO LIMPIO Y CONSCIENTE DE CARPETAS PARA ELIMINACIÓN
  static Future<DeleteOption?> showDeleteSongDialog({
    required BuildContext context,
    required String songTitle,
    bool isFromFolder = false,
  }) async {
    bool borrarArchivoStorage = false;

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<DeleteOption>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF141624) : Colors.white,
              elevation: 16,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: isDark ? 0.08 : 0.06,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.trash2,
                            color: AppColors.danger,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Eliminar canción",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                songTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// TARJETA DE OPCIÓN FÍSICA LIMPIA
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1B1E2D)
                            : const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: borrarArchivoStorage,
                            activeColor: AppColors.danger,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                borrarArchivoStorage = val ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setModalState(() {
                                  borrarArchivoStorage = !borrarArchivoStorage;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Eliminar archivo del dispositivo",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      borrarArchivoStorage
                                          ? "Se borrará permanentemente de la memoria del teléfono (desaparecerá de todas las listas y carpetas)."
                                          : (isFromFolder
                                              ? "Se quitará de General, pero seguirá disponible dentro de su Carpeta."
                                              : "Solo se quitará de la lista del reproductor."),
                                      style: TextStyle(
                                        fontSize: 11,
                                        height: 1.3,
                                        color: borrarArchivoStorage
                                            ? AppColors.danger
                                            : (isDark
                                                ? Colors.white54
                                                : Colors.black45),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: isDark ? 0.12 : 0.15,
                                  ),
                                ),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context, DeleteOption.cancel),
                            child: Text(
                              "Cancelar",
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(
                                context,
                                borrarArchivoStorage
                                    ? DeleteOption.libraryAndStorage
                                    : DeleteOption.libraryOnly,
                              );
                            },
                            child: const Text(
                              "Eliminar",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: Colors.white,
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
      },
    );
  }

  /// ✏️ MODAL LIMPIO PARA RENOMBRAR CANCIÓN
  static Future<RenameSongResult?> showRenameSongDialog({
    required BuildContext context,
    required String currentTitle,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final controller = TextEditingController(text: currentTitle);
    bool renamePhysicalFile = false;

    return showModalBottomSheet<RenameSongResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141624) : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(
                      alpha: isDark ? 0.08 : 0.05,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            LucideIcons.pencil,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomText(
                            text: "Renombrar canción",
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: controller,
                      autofocus: true,
                      labelText: "Nombre de la canción",
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          renamePhysicalFile = !renamePhysicalFile;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: renamePhysicalFile,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  renamePhysicalFile = val ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Text(
                                "Renombrar también el archivo en el teléfono",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: isDark ? 0.12 : 0.15,
                                ),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, null),
                            child: CustomText(
                              text: "Cancelar",
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              final text = controller.text.trim();
                              if (text.isEmpty) return;
                              Navigator.pop(
                                ctx,
                                RenameSongResult(
                                  newTitle: text,
                                  renamePhysicalFile: renamePhysicalFile,
                                ),
                              );
                            },
                            child: const Text(
                              "Guardar",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: Colors.white,
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
      },
    );
  }
}

enum DeleteOption {
  cancel,
  libraryOnly,
  libraryAndStorage,
}

class RenameSongResult {
  final String newTitle;
  final bool renamePhysicalFile;

  RenameSongResult({
    required this.newTitle,
    required this.renamePhysicalFile,
  });
}

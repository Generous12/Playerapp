import 'package:family_bottom_sheet/family_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/clases/album.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class CreateAlbumModal {
  static void show({
    required BuildContext context,
    required Future<void> Function(Album album) onCreate,
    String title = "Nueva Carpeta",
    String hintText = "Nombre de la carpeta",
    required Color buttonColor,
  }) {
    final TextEditingController controller = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    FamilyModalSheet.show<void>(
      context: context,
      contentBackgroundColor: isDark ? const Color(0xFF11131B) : Colors.white,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            String? errorText;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// ➖ HANDLE BAR
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 18),

                  /// 📁 TÍTULO CON ÍCONO
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: buttonColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          LucideIcons.folderPlus,
                          color: buttonColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CustomText(
                        text: title,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  /// ✍️ CAMPO DE TEXTO MINIMALISTA
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (value) {
                      setState(() {
                        if (value.trim().isNotEmpty) {
                          errorText = null;
                        }
                      });
                    },
                    style: TextStyle(
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1E2132)
                          : const Color(0xFFF1F3F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: buttonColor, width: 1.5),
                      ),
                    ),
                  ),

                  if (errorText != null) ...[
                    const SizedBox(height: 6),
                    CustomText(
                      text: errorText!,
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ],

                  const SizedBox(height: 22),

                  /// 🔘 BOTONES EN PÍLDORA
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: isDark ? 0.1 : 0.12,
                                ),
                              ),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(
                            "Cancelar",
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: controller.text.trim().isEmpty
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.12,
                                  )
                                : buttonColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: controller.text.trim().isEmpty
                              ? null
                              : () async {
                                  final text = controller.text.trim();

                                  if (text.isEmpty) {
                                    setState(() {
                                      errorText =
                                          "Debe ingresar un nombre para la carpeta";
                                    });
                                    return;
                                  }

                                  final album = Album(
                                    titulo: text,
                                    year: DateTime.now().year,
                                  );

                                  await onCreate(album);

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                },
                          child: CustomText(
                            text: "Crear",
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: controller.text.trim().isEmpty
                                ? (isDark ? Colors.white30 : Colors.black26)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

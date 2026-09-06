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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isSmallDevice = MediaQuery.of(ctx).size.width < 360;

        return StatefulBuilder(
          builder: (context, setState) {
            String? errorText;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
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
                      alpha: isDark ? 0.1 : 0.05,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// ➖ HANDLE BAR
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

                    /// 📁 TÍTULO CON ÍCONO
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: buttonColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            LucideIcons.folderPlus,
                            color: buttonColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        CustomText(
                          text: title,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    /// ✍️ CAMPO DE TEXTO UNIFICADO
                    CustomTextField(
                      controller: controller,
                      autofocus: true,
                      labelText: hintText,
                      isSmallDevice: isSmallDevice,
                      onChanged: (value) {
                        setState(() {
                          if (value.trim().isNotEmpty) {
                            errorText = null;
                          }
                        });
                      },
                    ),

                    if (errorText != null) ...[
                      const SizedBox(height: 6),
                      CustomText(
                        text: errorText!,
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ],

                    const SizedBox(height: 20),

                    /// 🔘 BOTONES ADHERIDOS AL TECLADO
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: CustomText(
                              text: "Cancelar",
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () async {
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
                            child: Text(
                              "Crear",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: buttonColor.computeLuminance() > 0.5
                                    ? const Color(0xFF08090D)
                                    : Colors.white,
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

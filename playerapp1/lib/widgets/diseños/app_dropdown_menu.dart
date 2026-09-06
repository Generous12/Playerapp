import 'package:flutter/material.dart';
import 'package:playerapp1/colores/appcolors.dart';

class AppDropdownItem<T> {
  final T value;
  final String text;
  final IconData icon;
  final Color? iconColor;
  final Color? textColor;
  final bool isDestructive;
  final bool isDividerBefore;

  const AppDropdownItem({
    required this.value,
    required this.text,
    required this.icon,
    this.iconColor,
    this.textColor,
    this.isDestructive = false,
    this.isDividerBefore = false,
  });
}

class AppDropdownMenu<T> extends StatelessWidget {
  final Widget? icon;
  final IconData? defaultIcon;
  final double iconSize;
  final Color? iconColor;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final EdgeInsetsGeometry padding;

  const AppDropdownMenu({
    super.key,
    this.icon,
    this.defaultIcon,
    this.iconSize = 18,
    this.iconColor,
    required this.items,
    required this.onSelected,
    this.tooltip = "Opciones",
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF161828) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.08);

    return Theme(
      data: theme.copyWith(
        hoverColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04),
        splashColor: AppColors.primary.withValues(alpha: 0.12),
      ),
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        padding: padding,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1),
        ),
        position: PopupMenuPosition.under,
        onOpened: () => FocusScope.of(context).unfocus(),
        onSelected: (val) {
          FocusScope.of(context).unfocus();
          onSelected(val);
        },
        icon: icon ??
            Icon(
              defaultIcon ?? Icons.more_vert_rounded,
              size: iconSize,
              color: iconColor ?? (isDark ? Colors.white54 : Colors.black45),
            ),
        itemBuilder: (ctx) {
          final entries = <PopupMenuEntry<T>>[];

          for (int i = 0; i < items.length; i++) {
            final item = items[i];

            if (item.isDividerBefore) {
              entries.add(
                const PopupMenuDivider(
                  height: 10,
                ),
              );
            }

            final effectiveColor = item.isDestructive
                ? AppColors.danger
                : (item.textColor ?? (isDark ? Colors.white : const Color(0xFF1E293B)));

            final effectiveIconColor = item.isDestructive
                ? AppColors.danger
                : (item.iconColor ?? (isDark ? Colors.white70 : Colors.black87));

            entries.add(
              PopupMenuItem<T>(
                value: item.value,
                height: 42,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: effectiveIconColor.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        size: 16,
                        color: effectiveIconColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: effectiveColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return entries;
        },
      ),
    );
  }
}

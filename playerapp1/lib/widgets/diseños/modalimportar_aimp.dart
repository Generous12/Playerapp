import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:playerapp1/colores/appcolors.dart';
import 'package:playerapp1/widgets/diseños/text.dart';

class ImportItem {
  final String path;
  String title;
  final int size;
  bool isSelected;

  ImportItem({
    required this.path,
    required this.title,
    required this.size,
    this.isSelected = true,
  });
}

class ImportPreviewResult {
  final String folderName;
  final List<ImportItem> selectedItems;

  ImportPreviewResult({
    required this.folderName,
    required this.selectedItems,
  });
}

class ImportPreviewModal extends StatefulWidget {
  final String initialFolderName;
  final List<ImportItem> items;

  const ImportPreviewModal({
    super.key,
    required this.initialFolderName,
    required this.items,
  });

  static Future<ImportPreviewResult?> show({
    required BuildContext context,
    required String initialFolderName,
    required List<ImportItem> items,
  }) {
    return showModalBottomSheet<ImportPreviewResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImportPreviewModal(
        initialFolderName: initialFolderName,
        items: items,
      ),
    );
  }

  @override
  State<ImportPreviewModal> createState() => _ImportPreviewModalState();
}

class _ImportPreviewModalState extends State<ImportPreviewModal> {
  late TextEditingController _folderNameController;
  late List<ImportItem> _items;

  @override
  void initState() {
    super.initState();
    _folderNameController = TextEditingController(text: "");
    _items = widget.items;
  }

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  bool get _allSelected => _items.isNotEmpty && _items.every((i) => i.isSelected);
  int get _selectedCount => _items.where((i) => i.isSelected).length;

  int get _selectedTotalBytes => _items
      .where((i) => i.isSelected)
      .fold(0, (sum, item) => sum + item.size);

  void _toggleSelectAll() {
    final targetState = !_allSelected;
    setState(() {
      for (var item in _items) {
        item.isSelected = targetState;
      }
    });
  }

  void _editarNombreItem(ImportItem item) async {
    final controller = TextEditingController(text: item.title);
    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF141624) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const CustomText(
            text: "Editar nombre",
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          content: CustomTextField(
            controller: controller,
            autofocus: true,
            hintText: "Nombre de la canción",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const CustomText(text: "Cancelar", color: Colors.grey),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const CustomText(text: "Guardar", color: Colors.white),
            ),
          ],
        );
      },
    );

    if (nuevoNombre != null && nuevoNombre.isNotEmpty) {
      setState(() {
        item.title = nuevoNombre;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF11131B) : const Color(0xFFFFFFFF);
    final totalMB = (_selectedTotalBytes / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔘 Handle bar
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 📂 Encabezado estilo AIMP
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.folderInput,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText(
                          text: "Vista Previa de Importación",
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(height: 2),
                        CustomText(
                          text: "$_selectedCount de ${_items.length} canciones ($totalMB MB)",
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ✏️ Nombre de la Carpeta / Álbum (opcional - por defecto va a la lista General)
              CustomText(
                text: "Nombre de carpeta (Opcional - dejar vacío para lista General)",
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                controller: _folderNameController,
                hintText: "Sin carpeta (Va directo a la Biblioteca General)",
                onChanged: (_) => setState(() {}),
                prefixIcon: Icon(
                  LucideIcons.folder,
                  color: AppColors.primary,
                  size: 18,
                ),
                suffixIcon: _folderNameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16),
                        onPressed: () {
                          setState(() {
                            _folderNameController.clear();
                          });
                        },
                      )
                    : null,
              ),

              const SizedBox(height: 14),

              // 🔘 Controles de Selección Global
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText(
                    text: "Archivos encontrados:",
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  InkWell(
                    onTap: _toggleSelectAll,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            _allSelected
                                ? LucideIcons.checkSquare
                                : LucideIcons.square,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          CustomText(
                            text: _allSelected ? "Desmarcar todas" : "Marcar todas",
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 🎵 Lista de Canciones con Checkbox
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final sizeMB = (item.size / (1024 * 1024)).toStringAsFixed(1);

                    return Container(
                      decoration: BoxDecoration(
                        color: item.isSelected
                            ? (isDark
                                ? const Color(0xFF181B26)
                                : const Color(0xFFF3F5FA))
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.black.withValues(alpha: 0.02)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.isSelected
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: Checkbox(
                          value: item.isSelected,
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              item.isSelected = val ?? false;
                            });
                          },
                        ),
                        title: CustomText(
                          text: item.title,
                          fontSize: 13,
                          fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: item.isSelected
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                        subtitle: CustomText(
                          text: "$sizeMB MB • ${item.path.split('.').last.toUpperCase()}",
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            LucideIcons.pencil,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          onPressed: () => _editarNombreItem(item),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 14),

              // 🚀 Botones de Acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, null),
                      child: CustomText(
                        text: "Cancelar",
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(LucideIcons.check, size: 18),
                      label: CustomText(
                        text: "Importar ($_selectedCount)",
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      onPressed: _selectedCount == 0
                          ? null
                          : () {
                              final result = ImportPreviewResult(
                                folderName: _folderNameController.text.trim(),
                                selectedItems: _items.where((i) => i.isSelected).toList(),
                              );
                              Navigator.pop(context, result);
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

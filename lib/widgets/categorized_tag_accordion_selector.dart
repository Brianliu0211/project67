import 'package:flutter/material.dart';
import '../services/tag_manager_service.dart';
import '../services/tag_categorizer.dart';
import '../screens/tag_manager_screen.dart';
import '../widgets/color_palette_picker.dart';

class CategorizedTagAccordionSelector extends StatefulWidget {
  final TextEditingController tagsController;
  final bool isDark;
  final Color primaryColor;
  final Future<void> Function()? onOpenQuickAdd;
  final Future<void> Function()? onOpenTagManager;

  const CategorizedTagAccordionSelector({
    super.key,
    required this.tagsController,
    required this.isDark,
    required this.primaryColor,
    this.onOpenQuickAdd,
    this.onOpenTagManager,
  });

  @override
  State<CategorizedTagAccordionSelector> createState() => _CategorizedTagAccordionSelectorState();
}

class _CategorizedTagAccordionSelectorState extends State<CategorizedTagAccordionSelector> {
  String? _expandedCategoryId;
  bool _isLoading = true;
  List<TagCategoryModel> _categories = [];
  List<TagItemModel> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndTags();
  }

  Future<void> _loadCategoriesAndTags() async {
    final categories = await TagManagerService.getCategories();
    final tags = await TagManagerService.getTags();
    if (mounted) {
      setState(() {
        _categories = categories;
        _tags = tags;
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String? hexString, Color fallback) {
    if (hexString == null || hexString.isEmpty) return fallback;
    try {
      final hex = hexString.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('FF$hex', radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  Future<void> _handleOpenQuickAdd() async {
    if (widget.onOpenQuickAdd != null) {
      await widget.onOpenQuickAdd!();
    } else {
      await _defaultOpenQuickAddTagDialog();
    }
    await _loadCategoriesAndTags();
  }

  Future<void> _handleOpenTagManager() async {
    if (widget.onOpenTagManager != null) {
      await widget.onOpenTagManager!();
    } else {
      await TagManagerScreen.showAsDialog(context);
    }
    await _loadCategoriesAndTags();
  }

  Future<void> _defaultOpenQuickAddTagDialog() async {
    final nameController = TextEditingController();
    final categories = await TagManagerService.getCategories();
    String selectedCatId = categories.isNotEmpty ? categories.first.id : 'cat_identity';
    String? selectedColorHex;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.local_offer, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('➕ 新增標籤與自訂顏色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: '標籤名稱 (例: 企業戶, 高意願)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCatId,
                      decoration: InputDecoration(
                        labelText: '歸屬大分類資料夾',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text('📁 ${c.name}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedCatId = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    ColorPalettePicker(
                      initialColorHex: selectedColorHex,
                      onColorSelected: (hex) => selectedColorHex = hex,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final tagText = nameController.text.trim();
                    if (tagText.isNotEmpty) {
                      await TagManagerService.addTag(
                        name: tagText,
                        categoryId: selectedCatId,
                        colorHex: selectedColorHex,
                      );

                      final currentTags = widget.tagsController.text.trim();
                      if (currentTags.isEmpty) {
                        widget.tagsController.text = tagText;
                      } else if (!currentTags.split(RegExp(r'[,，]')).map((s) => s.trim()).contains(tagText)) {
                        widget.tagsController.text = '$currentTags, $tagText';
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                  child: const Text('確定建立並套用'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department, size: 16, color: widget.primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    '常用標籤 (點擊大分類展開)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: _handleOpenQuickAdd,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 2),
                          Text('自訂色', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: _handleOpenTagManager,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: widget.primaryColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.settings, size: 12, color: widget.primaryColor),
                          const SizedBox(width: 2),
                          Text('管理大分類', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: widget.primaryColor)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Interactive Selected Tags Chips Area
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.tagsController,
            builder: (context, value, child) {
              final rawText = value.text.trim();
              final selectedTagsList = rawText.isEmpty
                  ? <String>[]
                  : rawText.split(RegExp(r'[,，]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sell_outlined, size: 14, color: widget.primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        '已選取標籤 (${selectedTagsList.length})：',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  selectedTagsList.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '尚未選取任何標籤 (點擊下方大分類直接加入標籤)',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
                          ),
                        )
                      : Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedTagsList.map((tag) {
                              final style = TagCategorizer.getStyle(tag, widget.isDark);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: style.backgroundColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: style.textColor.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: style.textColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () {
                                        final updatedList = List<String>.from(selectedTagsList)..remove(tag);
                                        widget.tagsController.text = updatedList.join(', ');
                                      },
                                      child: Icon(Icons.close, size: 14, color: style.textColor),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ],
              );
            },
          ),
          const Divider(height: 1),
          const SizedBox(height: 10),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()))
          else ...[
            // Compact Category Pills Row (1-Tap to Expand)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final String catId = cat.id;
                final String title = cat.name;
                final Color color = _parseColor(cat.colorHex, const Color(0xFF0369A1));
                final subTags = _tags.where((t) => t.categoryId == catId).toList();
                final bool isExpanded = _expandedCategoryId == catId;

                return InkWell(
                  onTap: () async {
                    await _loadCategoriesAndTags();
                    setState(() {
                      _expandedCategoryId = isExpanded ? null : catId;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isExpanded ? color : (widget.isDark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color, width: isExpanded ? 2 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_outlined, size: 14, color: isExpanded ? Colors.white : color),
                        const SizedBox(width: 4),
                        Text(
                          '$title (${subTags.length})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isExpanded ? Colors.white : (widget.isDark ? Colors.white70 : color),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 16,
                          color: isExpanded ? Colors.white : color,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // Expanded Sub-tags Area (Smooth Animation)
            if (_expandedCategoryId != null) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final cat = _categories.firstWhere(
                    (c) => c.id == _expandedCategoryId,
                    orElse: () => TagCategoryModel(id: '', name: '未分類'),
                  );
                  final color = _parseColor(cat.colorHex, const Color(0xFF0369A1));
                  final subTags = _tags.where((t) => t.categoryId == cat.id).toList();

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder_open_outlined, size: 16, color: color),
                            const SizedBox(width: 6),
                            Text(
                              '${cat.name} 標籤庫 (點擊直接加入/解除)：',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        subTags.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Text('此分類尚未建立子標籤，可點擊「管理大分類」新增子標籤',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              )
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: subTags.map((tagModel) {
                                  final currentTags = widget.tagsController.text
                                      .split(RegExp(r'[,，]'))
                                      .map((s) => s.trim())
                                      .where((s) => s.isNotEmpty)
                                      .toList();
                                  final isSelected = currentTags.contains(tagModel.name);
                                  final tagColor = tagModel.colorHex != null
                                      ? _parseColor(tagModel.colorHex, color)
                                      : color;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          currentTags.remove(tagModel.name);
                                        } else {
                                          currentTags.add(tagModel.name);
                                        }
                                        widget.tagsController.text = currentTags.join(', ');
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? tagColor : (widget.isDark ? tagColor.withValues(alpha: 0.15) : tagColor.withValues(alpha: 0.1)),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: tagColor, width: isSelected ? 2 : 1),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected ? Icons.check_circle : Icons.add_circle_outline,
                                            size: 14,
                                            color: isSelected ? Colors.white : tagColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            tagModel.name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? Colors.white : tagColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}

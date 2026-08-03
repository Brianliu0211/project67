import 'package:flutter/material.dart';
import '../services/tag_manager_service.dart';
import '../services/app_settings.dart';

class TagManagerScreen extends StatefulWidget {
  final bool isDialogMode;
  const TagManagerScreen({super.key, this.isDialogMode = false});

  static void showAsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750, maxHeight: 620),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: const TagManagerScreen(isDialogMode: true),
            ),
          ),
        );
      },
    );
  }

  @override
  State<TagManagerScreen> createState() => _TagManagerScreenState();
}

class _TagManagerScreenState extends State<TagManagerScreen> {
  bool _isLoading = true;
  List<TagCategoryModel> _categories = [];
  List<TagItemModel> _tags = [];
  String _selectedCategoryId = 'cat_identity';
  final Set<String> _selectedTagIdsForMerge = {};
  bool _isMergeMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final categories = await TagManagerService.getCategories();
    final tags = await TagManagerService.getTags();

    setState(() {
      _categories = categories;
      _tags = tags;
      if (_categories.isNotEmpty && !_categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = _categories.first.id;
      }
      _isLoading = false;
    });
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

  Color _getCategoryThemeColor(String categoryId) {
    final cat = _categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => TagCategoryModel(id: '', name: '', colorHex: '#0369A1'),
    );
    return _parseColor(cat.colorHex, const Color(0xFF0369A1));
  }

  void _showToast(String message, {String type = 'green'}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg = const Color(0xFF10B981);
    Color text = Colors.white;
    IconData icon = Icons.check_circle_outline;

    if (type == 'yellow') {
      bg = const Color(0xFFF59E0B);
      text = Colors.black87;
      icon = Icons.warning_amber_rounded;
    } else if (type == 'red') {
      bg = const Color(0xFFEF4444);
      text = Colors.white;
      icon = Icons.error_outline_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: text, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: text, fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: bg,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _openAddTagDialog() {
    final nameController = TextEditingController();
    String? selectedCustomColor;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('新增子標籤', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '標籤名稱 (例：社團、吃素)',
                  hintText: '請輸入標籤名稱',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('預設顏色：繼承該資料夾主題色', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _getCategoryThemeColor(_selectedCategoryId),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final result = await TagManagerService.addTag(
                  categoryId: _selectedCategoryId,
                  name: name,
                  colorHex: selectedCustomColor,
                );

                if (!mounted) return;
                Navigator.pop(ctx);
                if (result == null) {
                  _showToast('標籤「$name」已存在於資料庫中，不可重複建立！', type: 'yellow');
                } else {
                  _showToast('成功建立標籤「$name」！', type: 'green');
                  _loadData();
                }
              },
              child: const Text('確定建立'),
            ),
          ],
        );
      },
    );
  }

  void _openEditTagDialog(TagItemModel tag) {
    final nameController = TextEditingController(text: tag.name);
    String selectedCatId = tag.categoryId;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('編輯標籤', style: TextStyle(fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setStateModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '標籤名稱',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCatId,
                    decoration: InputDecoration(
                      labelText: '隸屬資料夾 (大分類)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => selectedCatId = val);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                final ok = await TagManagerService.editTag(
                  tag.id,
                  newName: newName,
                  newCategoryId: selectedCatId,
                );
                if (!mounted) return;
                Navigator.pop(ctx);
                if (ok) {
                  _showToast('已成功更新標籤！全站歷史客戶卡片已同步。', type: 'green');
                  _loadData();
                } else {
                  _showToast('已有同名標籤存在，無法儲存。', type: 'yellow');
                }
              },
              child: const Text('儲存修改'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTag(TagItemModel tag) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('確認刪除標籤？'),
            ],
          ),
          content: Text('您確定要刪除「${tag.name}」標籤嗎？所有已套用此標籤的客戶卡片將一併移除此標籤。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await TagManagerService.deleteTag(tag.id);
                _showToast('標籤「${tag.name}」已成功刪除！', type: 'red');
                _loadData();
              },
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );
  }

  void _openMergeDialog() {
    if (_selectedTagIdsForMerge.length < 2) {
      _showToast('請至少勾選 2 個標籤進行合併！', type: 'yellow');
      return;
    }

    final selectedTags = _tags.where((t) => _selectedTagIdsForMerge.contains(t.id)).toList();
    String targetTagName = selectedTags.first.name;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('一鍵合併標籤 (Merge Tags)', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('被選中的同義標籤將全數合併至【目標標準標籤】，所有已貼標籤的客戶卡片會自動更換為標準標籤。'),
                  const SizedBox(height: 16),
                  const Text('請選擇主要保留的目標標籤：', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: targetTagName,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: selectedTags.map((t) {
                      return DropdownMenuItem(value: t.name, child: Text(t.name));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setStateModal(() => targetTagName = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('將被合併銷毀的標籤：${selectedTags.where((t) => t.name != targetTagName).map((t) => t.name).join('、')}'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                  onPressed: () async {
                    final sourceNames = selectedTags.where((t) => t.name != targetTagName).map((t) => t.name).toList();
                    Navigator.pop(ctx);

                    final ok = await TagManagerService.mergeTags(
                      targetTagName: targetTagName,
                      sourceTagNames: sourceNames,
                    );

                    if (ok) {
                      _showToast('成功將 ${sourceNames.join('、')} 合併至「$targetTagName」！全站客戶卡片已更新。', type: 'green');
                      setState(() {
                        _selectedTagIdsForMerge.clear();
                        _isMergeMode = false;
                      });
                      _loadData();
                    }
                  },
                  child: const Text('確認合併'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCategory = _categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => TagCategoryModel(id: 'cat_identity', name: '客戶身分', colorHex: '#0369A1'),
    );
    final themeColor = _getCategoryThemeColor(_selectedCategoryId);
    final categoryTags = _tags.where((t) => t.categoryId == _selectedCategoryId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏷️ 標籤與資料夾管理器', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: widget.isDialogMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                tooltip: '關閉管理器',
              )
            : null,
        actions: [
          IconButton(
            tooltip: _isMergeMode ? '退出合併模式' : '開啟多標籤合併模式',
            icon: Icon(_isMergeMode ? Icons.close : Icons.merge_type, color: _isMergeMode ? Colors.orange : null),
            onPressed: () {
              setState(() {
                _isMergeMode = !_isMergeMode;
                _selectedTagIdsForMerge.clear();
              });
            },
          ),
          IconButton(
            tooltip: '重新整理',
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Category Folders Segmented / Tabs
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    border: Border(bottom: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!)),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSelected = cat.id == _selectedCategoryId;
                        final color = _parseColor(cat.colorHex, const Color(0xFF0369A1));

                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Row(
                              children: [
                                Icon(Icons.folder_outlined, size: 16, color: isSelected ? Colors.white : color),
                                const SizedBox(width: 6),
                                Text(cat.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              ],
                            ),
                            selected: isSelected,
                            selectedColor: color,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87)),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategoryId = cat.id;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Selected Category Info Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${activeCategory.name} (共 ${categoryTags.length} 個標籤)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (_isMergeMode)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                          onPressed: _openMergeDialog,
                          icon: const Icon(Icons.call_merge, size: 18),
                          label: Text('一鍵合併 (${_selectedTagIdsForMerge.length})'),
                        ),
                    ],
                  ),
                ),

                // Tags Grid/List
                Expanded(
                  child: categoryTags.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.style_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text('該資料夾下尚無標籤，點擊下方「+」按鈕即可新增！', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: categoryTags.map((tag) {
                              final tagColor = tag.colorHex != null ? _parseColor(tag.colorHex, themeColor) : themeColor;
                              final isChecked = _selectedTagIdsForMerge.contains(tag.id);

                              return InkWell(
                                onTap: () {
                                  if (_isMergeMode) {
                                    setState(() {
                                      if (isChecked) {
                                        _selectedTagIdsForMerge.remove(tag.id);
                                      } else {
                                        _selectedTagIdsForMerge.add(tag.id);
                                      }
                                    });
                                  } else {
                                    _openEditTagDialog(tag);
                                  }
                                },
                                onLongPress: () => _confirmDeleteTag(tag),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isChecked
                                        ? Colors.orange.withOpacity(0.2)
                                        : (isDark ? tagColor.withOpacity(0.25) : tagColor.withOpacity(0.12)),
                                    border: Border.all(
                                      color: isChecked ? Colors.orange : tagColor,
                                      width: isChecked ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isMergeMode) ...[
                                        Icon(isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
                                            size: 16, color: isChecked ? Colors.orange : tagColor),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        tag.name,
                                        style: TextStyle(
                                          color: isDark ? tagColor.withOpacity(0.9) : tagColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _confirmDeleteTag(tag),
                                        child: Icon(Icons.close, size: 14, color: isDark ? Colors.white54 : Colors.black45),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTagDialog,
        backgroundColor: themeColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('新增子標籤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ColorPalettePicker extends StatefulWidget {
  final String? initialColorHex;
  final ValueChanged<String> onColorSelected;

  const ColorPalettePicker({
    super.key,
    this.initialColorHex,
    required this.onColorSelected,
  });

  // 16 Preset Curated Color Codes
  static const List<String> presetColors = [
    '#0369A1', // Sky Blue / 客戶身分
    '#15803D', // Emerald Green / 已購險種
    '#B45309', // Amber Gold / 生活興趣
    '#BE123C', // Rose Red / 健康體況
    '#6B21A8', // Purple / 跟進狀態
    '#4338CA', // Indigo
    '#0D9488', // Teal
    '#DB2777', // Pink
    '#0891B2', // Cyan
    '#EA580C', // Dark Orange
    '#166534', // Forest Green
    '#1E40AF', // Royal Blue
    '#854D0E', // Dark Yellow
    '#9F1239', // Dark Crimson
    '#5B21B6', // Deep Violet
    '#475569', // Slate Gray
  ];

  @override
  State<ColorPalettePicker> createState() => _ColorPalettePickerState();
}

class _ColorPalettePickerState extends State<ColorPalettePicker> {
  late String _selectedHex;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _selectedHex = _normalizeHex(widget.initialColorHex) ?? ColorPalettePicker.presetColors.first;
    _hexController = TextEditingController(text: _selectedHex);
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String? _normalizeHex(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    var trimmed = hex.trim().replaceAll('#', '').toUpperCase();
    if (trimmed.length == 6) {
      return '#$trimmed';
    }
    return null;
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFF0369A1);
  }

  void _onSelectHex(String hex) {
    setState(() {
      _selectedHex = hex;
      _hexController.text = hex;
    });
    widget.onColorSelected(hex);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = _parseColor(_selectedHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '選擇專屬顏色 (點擊色塊或輸入色碼)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            // Selected Color Preview Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: selectedColor.withOpacity(0.2),
                border: Border.all(color: selectedColor, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _selectedHex,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selectedColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Color Block Tiles Grid (一格一格的色塊選擇器)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: ColorPalettePicker.presetColors.length,
          itemBuilder: (context, index) {
            final hex = ColorPalettePicker.presetColors[index];
            final color = _parseColor(hex);
            final isSelected = hex.toLowerCase() == _selectedHex.toLowerCase();

            return InkWell(
              onTap: () => _onSelectHex(hex),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? (isDark ? Colors.white : Colors.black) : Colors.transparent,
                    width: isSelected ? 3.0 : 0.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(Icons.check, size: 16, color: Colors.white),
                      )
                    : null,
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Hex Code Custom Input Box
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _hexController,
                decoration: InputDecoration(
                  labelText: 'HEX 自訂色碼',
                  hintText: '#0369A1',
                  prefixIcon: const Icon(Icons.color_lens_outlined, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (val) {
                  final normalized = _normalizeHex(val);
                  if (normalized != null) {
                    setState(() {
                      _selectedHex = normalized;
                    });
                    widget.onColorSelected(normalized);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

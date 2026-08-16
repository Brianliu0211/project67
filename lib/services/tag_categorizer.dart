import 'package:flutter/material.dart';

class TagStyle {
  final Color backgroundColor;
  final Color textColor;
  final String categoryName;

  const TagStyle({
    required this.backgroundColor,
    required this.textColor,
    required this.categoryName,
  });
}

class TagCategorizer {
  /// 全域自訂標籤色碼快取 (Tag Name -> Custom HEX)
  static final Map<String, String> customTagColors = {};

  /// 註冊或更新自訂標籤色碼
  static void registerCustomColor(String tagName, String hex) {
    if (tagName.trim().isNotEmpty && hex.trim().isNotEmpty) {
      customTagColors[tagName.trim().toLowerCase()] = hex.trim();
    }
  }

  /// Classifies a tag name and returns the background and text color based on the current theme brightness.
  static TagStyle getStyle(String tagName, bool isDark, {String? customHex}) {
    final name = tagName.trim().toLowerCase();

    // 1. 優先檢查自訂色碼 (Custom HEX from caller or registry)
    final hex = customHex ?? customTagColors[name];
    if (hex != null && hex.isNotEmpty) {
      try {
        final clean = hex.replaceAll('#', '');
        if (clean.length == 6) {
          final colorInt = int.parse('FF$clean', radix: 16);
          final baseColor = Color(colorInt);
          return TagStyle(
            backgroundColor: isDark
                ? baseColor.withValues(alpha: 0.28)
                : baseColor.withValues(alpha: 0.14),
            textColor: isDark
                ? Color.lerp(baseColor, Colors.white, 0.45) ?? baseColor
                : baseColor,
            categoryName: '自訂標籤',
          );
        }
      } catch (_) {}
    }

    // 2. 已購險種 (Policies Purchased) - Soft Green/Emerald
    if (name.contains('險') || 
        name.contains('保單') || 
        name.contains('規劃') || 
        name.contains('儲蓄') ||
        name.contains('投保') ||
        name.contains('簽單') && !name.contains('意願')) {
      return TagStyle(
        backgroundColor: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
        textColor: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
        categoryName: '已購險種',
      );
    } 
    
    // 3. 保障缺口 (Coverage Gap) - Bright Amber/Red
    if (name.contains('缺') || name.contains('未保') || name.contains('不足') || name.contains('缺口')) {
      return TagStyle(
        backgroundColor: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2),
        textColor: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
        categoryName: '保障缺口',
      );
    }

    // 4. 跟進狀態 (Follow-up Status) - Soft Purple/Indigo
    if (name.contains('意願') || 
        name.contains('跟進') || 
        name.contains('聯絡') || 
        name.contains('預計') ||
        name.contains('拜訪') ||
        name == '已簽單' || 
        name == '待跟進' ||
        name == '高意願' ||
        name == '跟進中') {
      return TagStyle(
        backgroundColor: isDark ? const Color(0xFF581C87) : const Color(0xFFF3E8FF),
        textColor: isDark ? const Color(0xFFC084FC) : const Color(0xFF6B21A8),
        categoryName: '跟進狀態',
      );
    } 
    
    // 5. 健康與體況 (Health Status) - Soft Red/Rose
    if (name.contains('體況') || 
        name.contains('病') || 
        name.contains('血壓') || 
        name.contains('手術') || 
        name.contains('健康') || 
        name.endsWith('史') ||
        name.contains('住院')) {
      return TagStyle(
        backgroundColor: isDark ? const Color(0xFF881337) : const Color(0xFFFFE4E6),
        textColor: isDark ? const Color(0xFFFB7185) : const Color(0xFFBE123C),
        categoryName: '健康與體況',
      );
    } 
    
    // 6. 生活興趣 (Interests/Lifestyle) - Soft Orange/Amber
    if (name.contains('愛') || 
        name.contains('喜') ||
        name.contains('興趣') ||
        name.contains('運動') || 
        name.contains('茶') || 
        name.contains('玩') || 
        name.contains('露營') || 
        name.contains('爬山') || 
        name.contains('旅遊') ||
        name.contains('高爾夫') ||
        name.contains('健身')) {
      return TagStyle(
        backgroundColor: isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7),
        textColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
        categoryName: '生活興趣',
      );
    } 

    // 7. 客戶身分 (Client Status) - Soft Blue (Default category for unclassified tags)
    return TagStyle(
      backgroundColor: isDark ? const Color(0xFF0C4A6E) : const Color(0xFFE0F2FE),
      textColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1),
      categoryName: '客戶身分',
    );
  }
}

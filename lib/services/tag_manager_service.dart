import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TagCategoryModel {
  final String id;
  final String name;
  final String? colorHex;
  final int sortOrder;

  TagCategoryModel({
    required this.id,
    required this.name,
    this.colorHex,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorHex': colorHex,
        'sortOrder': sortOrder,
      };

  factory TagCategoryModel.fromJson(Map<String, dynamic> json) => TagCategoryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        colorHex: json['colorHex'] as String?,
        sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      );
}

class TagItemModel {
  final String id;
  final String categoryId;
  final String name;
  final String? colorHex;
  final int usageCount;

  TagItemModel({
    required this.id,
    required this.categoryId,
    required this.name,
    this.colorHex,
    this.usageCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'name': name,
        'colorHex': colorHex,
        'usageCount': usageCount,
      };

  factory TagItemModel.fromJson(Map<String, dynamic> json) => TagItemModel(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String? ?? 'cat_identity',
        name: json['name'] as String,
        colorHex: json['colorHex'] as String?,
        usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      );

  TagItemModel copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? colorHex,
    int? usageCount,
  }) {
    return TagItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

class TagManagerService {
  static const String _prefCategoriesKey = 'tag_categories_custom';
  static const String _prefTagsKey = 'tags_custom';

  // 5 Default Categories
  static final List<TagCategoryModel> defaultCategories = [
    TagCategoryModel(id: 'cat_identity', name: '客戶身分', colorHex: '#0369A1', sortOrder: 1),
    TagCategoryModel(id: 'cat_insurance', name: '已購險種', colorHex: '#15803D', sortOrder: 2),
    TagCategoryModel(id: 'cat_interests', name: '生活興趣', colorHex: '#B45309', sortOrder: 3),
    TagCategoryModel(id: 'cat_health', name: '健康與體況', colorHex: '#BE123C', sortOrder: 4),
    TagCategoryModel(id: 'cat_followup', name: '跟進狀態', colorHex: '#6B21A8', sortOrder: 5),
  ];

  // Default initial sub-tags
  static final List<TagItemModel> defaultTags = [
    TagItemModel(id: 't_1', categoryId: 'cat_identity', name: '青年(18-35)'),
    TagItemModel(id: 't_2', categoryId: 'cat_identity', name: '中年(36-60)'),
    TagItemModel(id: 't_3', categoryId: 'cat_identity', name: '高資產'),
    TagItemModel(id: 't_4', categoryId: 'cat_identity', name: '單身'),
    TagItemModel(id: 't_5', categoryId: 'cat_insurance', name: '醫療險'),
    TagItemModel(id: 't_6', categoryId: 'cat_insurance', name: '意外險'),
    TagItemModel(id: 't_7', categoryId: 'cat_insurance', name: '防癌險'),
    TagItemModel(id: 't_8', categoryId: 'cat_insurance', name: '儲蓄險'),
    TagItemModel(id: 't_9', categoryId: 'cat_insurance', name: '車險'),
    TagItemModel(id: 't_10', categoryId: 'cat_interests', name: '露營'),
    TagItemModel(id: 't_11', categoryId: 'cat_interests', name: '高爾夫'),
    TagItemModel(id: 't_12', categoryId: 'cat_interests', name: '爬山'),
    TagItemModel(id: 't_13', categoryId: 'cat_health', name: '健康'),
    TagItemModel(id: 't_14', categoryId: 'cat_health', name: '高血壓'),
    TagItemModel(id: 't_15', categoryId: 'cat_followup', name: '高意願'),
    TagItemModel(id: 't_16', categoryId: 'cat_followup', name: '定期聯繫'),
    TagItemModel(id: 't_17', categoryId: 'cat_followup', name: '觀望中'),
  ];

  /// Fetches all active categories (local cache + default)
  static Future<List<TagCategoryModel>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString(_prefCategoriesKey);
    if (cached == null || cached.isEmpty) {
      await saveCategories(defaultCategories);
      return defaultCategories;
    }
    try {
      final List<dynamic> list = jsonDecode(cached);
      return list.map((e) => TagCategoryModel.fromJson(e)).toList();
    } catch (_) {
      return defaultCategories;
    }
  }

  /// Saves categories to SharedPreferences
  static Future<void> saveCategories(List<TagCategoryModel> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(categories.map((e) => e.toJson()).toList());
    await prefs.setString(_prefCategoriesKey, encoded);
  }

  /// Fetches all tags
  static Future<List<TagItemModel>> getTags() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cached = prefs.getString(_prefTagsKey);
    if (cached == null || cached.isEmpty) {
      await saveTags(defaultTags);
      return defaultTags;
    }
    try {
      final List<dynamic> list = jsonDecode(cached);
      return list.map((e) => TagItemModel.fromJson(e)).toList();
    } catch (_) {
      return defaultTags;
    }
  }

  /// Saves tags to SharedPreferences
  static Future<void> saveTags(List<TagItemModel> tags) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tags.map((e) => e.toJson()).toList());
    await prefs.setString(_prefTagsKey, encoded);
  }

  /// Checks if tag name exists (case-insensitive)
  static Future<bool> isTagNameExists(String name) async {
    final tags = await getTags();
    final target = name.trim().toLowerCase();
    return tags.any((t) => t.name.trim().toLowerCase() == target);
  }

  /// Adds a new category
  static Future<TagCategoryModel?> addCategory(String name, {String? colorHex}) async {
    final categories = await getCategories();
    final newCat = TagCategoryModel(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      colorHex: colorHex,
      sortOrder: categories.length + 1,
    );
    categories.add(newCat);
    await saveCategories(categories);
    return newCat;
  }

  /// Adds a new tag
  static Future<TagItemModel?> addTag({
    required String categoryId,
    required String name,
    String? colorHex,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (await isTagNameExists(trimmed)) {
      return null; // Duplicate
    }

    final tags = await getTags();
    final newTag = TagItemModel(
      id: 'tag_${DateTime.now().millisecondsSinceEpoch}',
      categoryId: categoryId,
      name: trimmed,
      colorHex: colorHex,
    );
    tags.add(newTag);
    await saveTags(tags);
    return newTag;
  }

  /// Edits an existing tag
  static Future<bool> editTag(String tagId, {String? newName, String? colorHex, String? newCategoryId}) async {
    final tags = await getTags();
    final index = tags.indexWhere((t) => t.id == tagId);
    if (index == -1) return false;

    final oldTag = tags[index];
    final updatedName = newName != null ? newName.trim() : oldTag.name;

    // Check duplicate name if renamed
    if (newName != null && newName.trim().toLowerCase() != oldTag.name.toLowerCase()) {
      if (tags.any((t) => t.id != tagId && t.name.toLowerCase() == newName.trim().toLowerCase())) {
        return false; // Duplicate name
      }
    }

    tags[index] = oldTag.copyWith(
      name: updatedName,
      colorHex: colorHex ?? oldTag.colorHex,
      categoryId: newCategoryId ?? oldTag.categoryId,
    );
    await saveTags(tags);

    // Sync renaming in Supabase customers table
    if (newName != null && newName.trim() != oldTag.name) {
      await _syncTagRenameInSupabase(oldTag.name, newName.trim());
    }

    return true;
  }

  /// Deletes a tag
  static Future<bool> deleteTag(String tagId) async {
    final tags = await getTags();
    final tag = tags.firstWhere((t) => t.id == tagId, orElse: () => TagItemModel(id: '', categoryId: '', name: ''));
    if (tag.id.isEmpty) return false;

    tags.removeWhere((t) => t.id == tagId);
    await saveTags(tags);

    // Also remove tag from customer records in Supabase
    await _removeTagFromSupabaseCustomers(tag.name);
    return true;
  }

  /// Merges multiple source tags into a target tag
  static Future<bool> mergeTags({
    required String targetTagName,
    required List<String> sourceTagNames,
  }) async {
    if (sourceTagNames.isEmpty) return false;

    final tags = await getTags();
    // Remove source tags from tags list
    tags.removeWhere((t) => sourceTagNames.contains(t.name));
    await saveTags(tags);

    // Sync in Supabase customers table
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final customersResponse = await supabase
            .from('customers')
            .select('id, tags')
            .eq('user_id', user.id);

        for (final row in customersResponse) {
          final String custId = row['id'];
          final List<dynamic> currentTags = row['tags'] != null ? List.from(row['tags']) : [];
          bool modified = false;

          for (final src in sourceTagNames) {
            if (currentTags.contains(src)) {
              currentTags.remove(src);
              if (!currentTags.contains(targetTagName)) {
                currentTags.add(targetTagName);
              }
              modified = true;
            }
          }

          if (modified) {
            await supabase
                .from('customers')
                .update({'tags': currentTags})
                .eq('id', custId);
          }
        }
      }
    } catch (_) {
      // Offline fallback
    }

    return true;
  }

  /// Syncs renaming a tag across Supabase customer records
  static Future<void> _syncTagRenameInSupabase(String oldName, String newName) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('customers')
          .select('id, tags')
          .eq('user_id', user.id);

      for (final row in response) {
        final String custId = row['id'];
        final List<dynamic> currentTags = row['tags'] != null ? List.from(row['tags']) : [];
        if (currentTags.contains(oldName)) {
          final index = currentTags.indexOf(oldName);
          currentTags[index] = newName;
          await supabase.from('customers').update({'tags': currentTags}).eq('id', custId);
        }
      }
    } catch (_) {}
  }

  /// Removes a tag from all Supabase customer records
  static Future<void> _removeTagFromSupabaseCustomers(String tagName) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('customers')
          .select('id, tags')
          .eq('user_id', user.id);

      for (final row in response) {
        final String custId = row['id'];
        final List<dynamic> currentTags = row['tags'] != null ? List.from(row['tags']) : [];
        if (currentTags.contains(tagName)) {
          currentTags.remove(tagName);
          await supabase.from('customers').update({'tags': currentTags}).eq('id', custId);
        }
      }
    } catch (_) {}
  }
}

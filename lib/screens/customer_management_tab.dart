import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/tag_categorizer.dart';
import '../services/app_localizations.dart';
import '../widgets/animations.dart';

class CustomerManagementTab extends StatefulWidget {
  final ValueChanged<String>? onMenuChanged;
  const CustomerManagementTab({super.key, this.onMenuChanged});

  @override
  State<CustomerManagementTab> createState() => _CustomerManagementTabState();
}

class _CustomerManagementTabState extends State<CustomerManagementTab> {
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  final _searchController = TextEditingController();
  bool _isLoading = false;

  // Initial Mock Data for Offline Mode
  final List<Map<String, dynamic>> _mockCustomers = [
    {
      'id': 'mock-1',
      'name': '林君雅',
      'nickname': '君雅',
      'avatar_url': 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=120',
      'phone': '0912-345678',
      'email': 'chunya.lin@gmail.com',
      'tags': ['高意願', '醫療險', '定期壽險'],
      'notes': '對家庭防護極有興趣，育有二子。預計下月發薪後再行拜訪談細節。',
      'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
    },
    {
      'id': 'mock-2',
      'name': '王小明',
      'nickname': '小明',
      'avatar_url': '',
      'phone': '0923-456789',
      'email': 'xiaoming.wang@gmail.com',
      'tags': ['已簽單', '汽車責任險'],
      'notes': '新購進口休旅車，已完成汽車責任險與甲式車體險簽單，保單寄送中。',
      'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    },
    {
      'id': 'mock-3',
      'name': '陳美玲',
      'nickname': '美玲姐',
      'avatar_url': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=120',
      'phone': '0934-567890',
      'email': 'meiling.chen@yahoo.com',
      'tags': ['年金險', '理財規劃', '待跟進'],
      'notes': '即將於三年後退休，著重尋找穩定配息的年金險，目前對儲蓄型保單仍在評估中。',
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCustomers);
    _fetchCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch customers (Handles both offline mock and online Supabase)
  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate 500ms network delay to make the shimmer skeleton clearly visible during debug preview
    await Future.delayed(const Duration(milliseconds: 500));

    if (isOfflineMode) {
      // Offline fallback: load from shared OfflineDataStore or initial mock list
      if (OfflineDataStore.customers.isEmpty) {
        OfflineDataStore.customers = List<Map<String, dynamic>>.from(_mockCustomers);
      }
      _allCustomers = OfflineDataStore.customers;
      _filterCustomers();
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('customers')
          .select()
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      setState(() {
        _allCustomers = List<Map<String, dynamic>>.from(response.map((data) {
          return {
            'id': data['id'],
            'name': data['name'],
            'nickname': data['nickname'] ?? '',
            'avatar_url': data['avatar_url'] ?? '',
            'phone': data['phone'],
            'email': data['email'],
            // Convert postgres array text[] to List<String> safely
            'tags': List<String>.from(data['tags'] ?? []),
            'notes': data['notes'],
            'created_at': data['created_at'],
            'deleted_at': data['deleted_at'],
          };
        }));
      });
      _filterCustomers();
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context,
          '讀取資料庫失敗: $e\n自動啟用離線列表。',
          ToastType.warning,
        );
      }
      // Fail-safe to mock data
      if (_allCustomers.isEmpty) {
        _allCustomers = List.from(_mockCustomers);
      }
      _filterCustomers();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Filter customers locally by search controller text
  void _filterCustomers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      final activeCustomers = _allCustomers.where((c) => c['deleted_at'] == null).toList();
      
      if (query.isEmpty) {
        _filteredCustomers = List.from(activeCustomers);
      } else {
        _filteredCustomers = activeCustomers.where((customer) {
          final name = (customer['name'] ?? '').toString().toLowerCase();
          final notes = (customer['notes'] ?? '').toString().toLowerCase();
          final List tags = customer['tags'] ?? [];
          
          final matchesName = name.contains(query);
          final matchesNotes = notes.contains(query);
          final matchesTags = tags.any((tag) => tag.toString().toLowerCase().contains(query));

          return matchesName || matchesNotes || matchesTags;
        }).toList();
      }
    });
  }

  // Add / Create Customer logic
  Future<void> _createCustomer({
    required String name,
    required String nickname,
    required String avatarUrl,
    required String phone,
    required String email,
    required List<String> tags,
    required String notes,
    Uint8List? imageBytes,
    String? imageName,
    required bool isImageCleared,
  }) async {
    setState(() {
      _isLoading = true;
    });

    String finalAvatarUrl = avatarUrl;
    if (isImageCleared) {
      finalAvatarUrl = '';
    } else if (imageBytes != null && imageName != null) {
      if (isOfflineMode) {
        finalAvatarUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      } else {
        try {
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;
          if (user == null) throw Exception('使用者未登入');

          final extension = imageName != null && imageName.contains('.') 
              ? imageName.split('.').last 
              : 'jpg';
          final cleanExtension = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(extension) ? extension : 'jpg';
          final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$cleanExtension';

          await supabase.storage.from('customer-photos').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
          finalAvatarUrl = supabase.storage.from('customer-photos').getPublicUrl(fileName);
        } catch (e) {
          if (mounted) {
            CustomToast.show(context, '頭像上傳失敗: $e', ToastType.error);
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    }

    if (isOfflineMode) {
      final newCustomer = {
        'id': 'mock-${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'nickname': nickname,
        'avatar_url': finalAvatarUrl,
        'phone': phone,
        'email': email,
        'tags': tags,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      };
      setState(() {
        _allCustomers.insert(0, newCustomer);
        _isLoading = false;
      });
      _filterCustomers();
      if (mounted) {
        CustomToast.show(context, '成功新增客戶 $name 檔案 (離線暫存)', ToastType.success);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('使用者未登入');

      await supabase.from('customers').insert({
        'profile_id': user.id,
        'name': name,
        'nickname': nickname,
        'avatar_url': finalAvatarUrl,
        'phone': phone,
        'email': email,
        'tags': tags,
        'notes': notes,
      });

      await _fetchCustomers();
      if (mounted) {
        CustomToast.show(context, '成功新增客戶 $name 檔案', ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '新增失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Edit / Update Customer logic
  Future<void> _updateCustomer({
    required String id,
    required String name,
    required String nickname,
    required String avatarUrl,
    required String phone,
    required String email,
    required List<String> tags,
    required String notes,
    Uint8List? imageBytes,
    String? imageName,
    required bool isImageCleared,
  }) async {
    setState(() {
      _isLoading = true;
    });

    String finalAvatarUrl = avatarUrl;
    if (isImageCleared) {
      finalAvatarUrl = '';
    } else if (imageBytes != null && imageName != null) {
      if (isOfflineMode) {
        finalAvatarUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      } else {
        try {
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;
          if (user == null) throw Exception('使用者未登入');

          final extension = imageName != null && imageName.contains('.') 
              ? imageName.split('.').last 
              : 'jpg';
          final cleanExtension = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(extension) ? extension : 'jpg';
          final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$cleanExtension';

          await supabase.storage.from('customer-photos').uploadBinary(
            fileName,
            imageBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
          finalAvatarUrl = supabase.storage.from('customer-photos').getPublicUrl(fileName);
        } catch (e) {
          if (mounted) {
            CustomToast.show(context, '頭像上傳失敗: $e', ToastType.error);
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    }

    if (isOfflineMode) {
      setState(() {
        final index = _allCustomers.indexWhere((c) => c['id'] == id);
        if (index != -1) {
          _allCustomers[index] = {
            ..._allCustomers[index],
            'name': name,
            'nickname': nickname,
            'avatar_url': finalAvatarUrl,
            'phone': phone,
            'email': email,
            'tags': tags,
            'notes': notes,
            'updated_at': DateTime.now().toIso8601String(),
          };
        }
        _isLoading = false;
      });
      _filterCustomers();
      if (mounted) {
        CustomToast.show(context, '成功修改客戶 $name 檔案 (離線暫存)', ToastType.success);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('customers').update({
        'name': name,
        'nickname': nickname,
        'avatar_url': finalAvatarUrl,
        'phone': phone,
        'email': email,
        'tags': tags,
        'notes': notes,
      }).eq('id', id);

      await _fetchCustomers();
      if (mounted) {
        CustomToast.show(context, '成功修改客戶 $name 檔案', ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '修改失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Delete Customer logic (Soft Delete)
  Future<void> _deleteCustomer(String id) async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      setState(() {
        final index = _allCustomers.indexWhere((c) => c['id'] == id);
        if (index != -1) {
          _allCustomers[index] = {
            ..._allCustomers[index],
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
          };
        }
        _isLoading = false;
      });
      _filterCustomers();
      if (mounted) {
        CustomToast.show(
          context,
          '${context.l10n('trash_bin_soft_delete_success')} (離線暫存)',
          ToastType.success,
          actionLabel: context.l10n('trash_bin_goto'),
          onActionPressed: () {
            if (widget.onMenuChanged != null) {
              widget.onMenuChanged!('垃圾桶');
            }
          },
        );
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('customers').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      await _fetchCustomers();
      if (mounted) {
        CustomToast.show(
          context,
          context.l10n('trash_bin_soft_delete_success'),
          ToastType.success,
          actionLabel: context.l10n('trash_bin_goto'),
          onActionPressed: () {
            if (widget.onMenuChanged != null) {
              widget.onMenuChanged!('垃圾桶');
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '刪除失敗: $e', ToastType.error);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show Project Creation Dialog
  void _showCreateProjectDialog() {
    if (_filteredCustomers.isEmpty) {
      CustomToast.show(context, '目前無篩選客戶，請先搜尋或篩選出目標客群', ToastType.warning);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    final titleController = TextEditingController();
    final purposeController = TextEditingController();

    InputDecoration buildInputDecoration(String labelText, IconData iconData, {String? hintText}) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: subTextColor),
        hintText: hintText,
        hintStyle: TextStyle(color: subTextColor),
        prefixIcon: Icon(iconData, color: subTextColor),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submitProject() async {
              final title = titleController.text.trim();
              final purpose = purposeController.text.trim();

              if (title.isEmpty || purpose.isEmpty) {
                CustomToast.show(context, '專案標題與建立目的為必填欄位', ToastType.warning);
                return;
              }

              setDialogState(() {
                isSubmitting = true;
              });

              if (isOfflineMode) {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final String projectId = 'mock-proj-${DateTime.now().millisecondsSinceEpoch}';

                  // 1. Save new project metadata
                  final projectJson = {
                    'id': projectId,
                    'title': title,
                    'purpose': purpose,
                    'is_completed': false,
                    'created_at': DateTime.now().toIso8601String(),
                  };

                  List<dynamic> localProjects = [];
                  final storedProjects = prefs.getString('offline_visit_projects');
                  if (storedProjects != null) {
                    localProjects = jsonDecode(storedProjects);
                  }
                  localProjects.insert(0, projectJson);
                  await prefs.setString('offline_visit_projects', jsonEncode(localProjects));

                  // 2. Save project checklist customers
                  final List<Map<String, dynamic>> projectCustomers = [];
                  for (var i = 0; i < _filteredCustomers.length; i++) {
                    final customer = _filteredCustomers[i];
                    projectCustomers.add({
                      'id': 'mock-vpc-${projectId}-$i',
                      'visit_project_id': projectId,
                      'customer_id': customer['id'],
                      'is_visited': false,
                      'created_at': DateTime.now().toIso8601String(),
                      'customer': {
                        'id': customer['id'],
                        'name': customer['name'],
                        'nickname': customer['nickname'],
                        'phone': customer['phone'],
                        'email': customer['email'],
                        'tags': customer['tags'],
                        'avatar_url': customer['avatar_url'],
                        'notes': customer['notes'],
                      }
                    });
                  }

                  List<dynamic> localProjCustomers = [];
                  final storedProjCustomers = prefs.getString('offline_visit_project_customers');
                  if (storedProjCustomers != null) {
                    localProjCustomers = jsonDecode(storedProjCustomers);
                  }
                  localProjCustomers.addAll(projectCustomers);
                  await prefs.setString('offline_visit_project_customers', jsonEncode(localProjCustomers));

                  if (mounted) {
                    CustomToast.show(context, '已成功建立「$title」拜訪專案 (離線暫存)', ToastType.success);
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    CustomToast.show(context, '建立失敗: $e', ToastType.error);
                  }
                } finally {
                  setDialogState(() {
                    isSubmitting = false;
                  });
                }
                return;
              }

              // Online Supabase Mode
              try {
                final supabase = Supabase.instance.client;
                final user = supabase.auth.currentUser;
                if (user == null) throw Exception('使用者未登入');

                // 1. Insert into visit_projects
                final projectResult = await supabase.from('visit_projects').insert({
                  'profile_id': user.id,
                  'title': title,
                  'purpose': purpose,
                }).select().single();

                final String projectId = projectResult['id'];

                // 2. Insert into visit_project_customers
                final List<Map<String, dynamic>> projectCustomers = _filteredCustomers.map((customer) {
                  return {
                    'visit_project_id': projectId,
                    'customer_id': customer['id'],
                    'is_visited': false,
                  };
                }).toList();

                await supabase.from('visit_project_customers').insert(projectCustomers);

                if (mounted) {
                  CustomToast.show(context, '已成功建立「$title」拜訪專案', ToastType.success);
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  CustomToast.show(context, '建立專案失敗: $e', ToastType.error);
                }
              } finally {
                setDialogState(() {
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(
                '建立拜訪專案',
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people_outline, color: primaryColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '已篩選客戶數：${_filteredCustomers.length} 位\n(專案將以此名單作為拜訪 Checklist)',
                                style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: titleController,
                        style: TextStyle(color: textColor),
                        textInputAction: TextInputAction.next,
                        decoration: buildInputDecoration('專案名稱 (必填)', Icons.assignment_outlined, hintText: '如: 2026長照政策關懷專案'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: purposeController,
                        style: TextStyle(color: textColor),
                        maxLines: 3,
                        decoration: buildInputDecoration('建立目的 / 拜訪 Why (必填)', Icons.ads_click_outlined, hintText: '如: 說明最新長照法規影響並關照防護缺口'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: Text('取消', style: TextStyle(color: subTextColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting ? null : submitProject,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('確認建立'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Display Add/Edit Dialog Form
  void _showCustomerForm({Map<String, dynamic>? customer}) {
    final isEdit = customer != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;

    final nameController = TextEditingController(text: isEdit ? customer['name'] : '');
    final nicknameController = TextEditingController(text: isEdit ? customer['nickname'] : '');
    final phoneController = TextEditingController(text: isEdit ? customer['phone'] : '');
    final emailController = TextEditingController(text: isEdit ? customer['email'] : '');
    final tagsController = TextEditingController(
        text: isEdit ? (customer['tags'] as List).join(', ') : '');
    final notesController = TextEditingController(text: isEdit ? customer['notes'] : '');

    InputDecoration buildInputDecoration(String labelText, IconData iconData, {String? hintText}) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: subTextColor),
        hintText: hintText,
        hintStyle: TextStyle(color: subTextColor),
        prefixIcon: Icon(iconData, color: subTextColor),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade400),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
      );
    }
    showDialog(
      context: context,
      builder: (context) {
        XFile? selectedImageFile;
        Uint8List? selectedImageBytes;
        bool isImageCleared = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void submitForm() {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                CustomToast.show(context, '客戶姓名為必填項目', ToastType.warning);
                return;
              }

              final tagsList = tagsController.text
                  .split(RegExp(r'[,，]'))
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();

              if (isEdit) {
                _updateCustomer(
                  id: customer['id'],
                  name: name,
                  nickname: nicknameController.text.trim(),
                  avatarUrl: customer['avatar_url'] ?? '',
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  tags: tagsList,
                  notes: notesController.text.trim(),
                  imageBytes: selectedImageBytes,
                  imageName: selectedImageFile?.name,
                  isImageCleared: isImageCleared,
                );
              } else {
                _createCustomer(
                  name: name,
                  nickname: nicknameController.text.trim(),
                  avatarUrl: '',
                  phone: phoneController.text.trim(),
                  email: emailController.text.trim(),
                  tags: tagsList,
                  notes: notesController.text.trim(),
                  imageBytes: selectedImageBytes,
                  imageName: selectedImageFile?.name,
                  isImageCleared: isImageCleared,
                );
              }
              Navigator.pop(context);
            }

            return AlertDialog(
              backgroundColor: dialogBg,
              title: Text(
                isEdit ? context.l10n('customer_edit_title') : context.l10n('customer_add_title'),
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(40),
                          onTap: () async {
                            try {
                              final picker = ImagePicker();
                              final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                              if (image != null) {
                                final bytes = await image.readAsBytes();
                                setDialogState(() {
                                  selectedImageFile = image;
                                  selectedImageBytes = bytes;
                                  isImageCleared = false;
                                });
                              }
                            } catch (e) {
                              CustomToast.show(context, '選擇照片失敗: $e', ToastType.error);
                            }
                          },
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: primaryColor.withOpacity(0.12),
                                backgroundImage: selectedImageBytes != null
                                    ? MemoryImage(selectedImageBytes!)
                                    : (!isImageCleared && isEdit && customer['avatar_url'] != null && customer['avatar_url'].isNotEmpty)
                                        ? _getAvatarProvider(customer['avatar_url'])
                                        : null,
                                child: (selectedImageBytes == null && (isImageCleared || !isEdit || customer['avatar_url'] == null || customer['avatar_url'].isEmpty))
                                    ? Icon(Icons.person, size: 40, color: primaryColor)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: primaryColor,
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (selectedImageBytes != null || (!isImageCleared && isEdit && customer?['avatar_url'] != null && customer!['avatar_url'].isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                            label: Text(context.l10n('customer_clear_photo'), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                            onPressed: () {
                              setDialogState(() {
                                selectedImageFile = null;
                                selectedImageBytes = null;
                                isImageCleared = true;
                              });
                            },
                          ),
                        ),
                      ],
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: textColor),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => submitForm(),
                        decoration: buildInputDecoration(context.l10n('customer_name_label'), Icons.person_outline),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nicknameController,
                        style: TextStyle(color: textColor),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => submitForm(),
                        decoration: buildInputDecoration(context.l10n('customer_nickname_label'), Icons.person_pin_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        style: TextStyle(color: textColor),
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => submitForm(),
                        decoration: buildInputDecoration(context.l10n('customer_phone_label'), Icons.phone_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        style: TextStyle(color: textColor),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => submitForm(),
                        decoration: buildInputDecoration(context.l10n('customer_email_label'), Icons.email_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: tagsController,
                        style: TextStyle(color: textColor),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submitForm(),
                        decoration: buildInputDecoration(context.l10n('customer_tags_label'), Icons.local_offer_outlined, hintText: context.l10n('customer_tags_eg')),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        style: TextStyle(color: textColor),
                        maxLines: 3,
                        decoration: buildInputDecoration(context.l10n('customer_notes_label'), Icons.note_alt_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n('cancel'), style: TextStyle(color: subTextColor)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: submitForm,
                  child: Text(context.l10n('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirm(String id, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text(context.l10n('customer_delete_title'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          content: Text(context.l10n('customer_delete_confirm_p1') + name + context.l10n('customer_delete_confirm_p2'), style: TextStyle(color: textColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n('cancel'), style: TextStyle(color: subTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                _deleteCustomer(id);
                Navigator.pop(context);
              },
              child: Text(context.l10n('delete')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    final Color searchBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color searchBorder = isDark ? const Color(0xFF30363D) : Colors.grey.shade300;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color iconColor = isDark ? Colors.white54 : Colors.black45;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search & Action Toolbar Row
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: context.l10n('customer_search_hint'),
                      hintStyle: TextStyle(color: iconColor),
                      prefixIcon: Icon(Icons.search, color: iconColor),
                      fillColor: searchBg,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: searchBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: searchBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // View Mode Toggle Button
              SizedBox(
                width: 48,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    color: searchBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: searchBorder),
                  ),
                  child: IconButton(
                    onPressed: () {
                      final newMode = AppSettings.instance.defaultCustomerViewMode == 'list' ? 'card' : 'list';
                      AppSettings.instance.setDefaultCustomerViewMode(newMode);
                    },
                    icon: Icon(
                      AppSettings.instance.defaultCustomerViewMode == 'list'
                          ? Icons.grid_view_outlined
                          : Icons.view_list_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                    tooltip: AppSettings.instance.defaultCustomerViewMode == 'list'
                        ? context.l10n('view_3d_card')
                        : context.l10n('view_list_view'),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showCreateProjectDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.assignment_outlined, size: 20),
                label: const Text('建立專案', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _showCustomerForm(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(context.l10n('customer_add_btn'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Customer Grid/List Area
          Expanded(
            child: _isLoading
                ? (AppSettings.instance.defaultCustomerViewMode == 'list'
                    ? _buildShimmerList(isWideScreen, screenWidth)
                    : _buildShimmerGrid(isWideScreen, screenWidth))
                : _filteredCustomers.isEmpty
                    ? _buildEmptyState(isDark, primaryColor)
                    : (AppSettings.instance.defaultCustomerViewMode == 'list'
                        ? _buildCustomerList(isWideScreen, screenWidth)
                        : _buildCustomerGrid(isWideScreen, screenWidth)),
          ),
        ],
      ),
    );
  }

  // Grid/List Layout
  Widget _buildCustomerGrid(bool isWideScreen, double screenWidth) {
    int crossAxisCount = 1;
    double childAspectRatio = 2.0;

    if (isWideScreen) {
      if (screenWidth > 1200) {
        crossAxisCount = 3;
        childAspectRatio = 1.6;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 1.5;
      }
    } else {
      childAspectRatio = 1.8;
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = _filteredCustomers[index];
        return StaggeredFadeIn(
          index: index,
          child: HoverAnimatedCard(
            child: FlippingCustomerCard(
              customer: customer,
              onEdit: () => _showCustomerForm(customer: customer),
              onDelete: () => _showDeleteConfirm(customer['id'], customer['name'] ?? ''),
              onZoom: () => _showCustomerZoomDetails(customer),
            ),
          ),
        );
      },
    );
  }

  // Shimmer Skeleton Loader Grid Layout
  Widget _buildShimmerGrid(bool isWideScreen, double screenWidth) {
    int crossAxisCount = 1;
    double childAspectRatio = 2.0;

    if (isWideScreen) {
      if (screenWidth > 1200) {
        crossAxisCount = 3;
        childAspectRatio = 1.6;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 1.5;
      }
    } else {
      childAspectRatio = 1.8;
    }

    return GridView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const CustomerCardShimmer();
      },
    );
  }

  // Empty State Widget
  Widget _buildEmptyState(bool isDark, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: primaryColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n('customer_empty_title'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n('customer_empty_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white30 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // List Layout
  Widget _buildCustomerList(bool isWideScreen, double screenWidth) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = _filteredCustomers[index];
        return StaggeredFadeIn(
          index: index,
          child: _buildCustomerListRow(customer, isWideScreen, screenWidth),
        );
      },
    );
  }

  // Shimmer Skeleton Loader List Layout
  Widget _buildShimmerList(bool isWideScreen, double screenWidth) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24, left: 8, right: 8),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const CustomerListShimmer();
      },
    );
  }

  // List Row UI
  Widget _buildCustomerListRow(Map<String, dynamic> customer, bool isWideScreen, double screenWidth) {
    final String name = customer['name'] ?? '';
    final String nickname = customer['nickname'] ?? '';
    final String phone = customer['phone'] ?? '未填寫';
    final String email = customer['email'] ?? '未填寫';
    final List tags = customer['tags'] ?? [];
    final String notes = customer['notes'] ?? '';
    final String avatarUrl = customer['avatar_url'] ?? '';

    final String displayName = nickname.isNotEmpty ? '$name ($nickname)' : name;
    final String nameInitial = name.isNotEmpty ? name.substring(0, 1) : '?';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final Color nameColor = isDark ? Colors.white : Colors.black87;
    final Color infoColor = isDark ? Colors.white54 : Colors.black54;
    final Color iconColor = isDark ? Colors.white30 : Colors.black38;

    Widget child;

    if (isWideScreen) {
      // Wide layout (Desktop/Tablet)
      child = Row(
        children: [
          // 1. Avatar & Display Name
          SizedBox(
            width: 180,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.12),
                  radius: 20,
                  backgroundImage: _getAvatarProvider(avatarUrl),
                  child: avatarUrl.isEmpty
                      ? Text(
                          nameInitial,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 2. Contact Info (Phone & Email)
          SizedBox(
            width: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        phone,
                        style: TextStyle(color: infoColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email, size: 12, color: iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(color: infoColor, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 3. Tags Column (Wrap with dynamic flex)
          Expanded(
            flex: 2,
            child: tags.isNotEmpty
                ? Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: tags.take(4).map((tag) {
                      final style = TagCategorizer.getStyle(tag.toString(), isDark);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: style.backgroundColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag.toString(),
                          style: TextStyle(
                            color: style.textColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : Text(
                    '無標籤',
                    style: TextStyle(color: infoColor, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
          ),
          const SizedBox(width: 12),

          // 4. Notes preview
          Expanded(
            flex: 3,
            child: Text(
              notes.isNotEmpty ? notes : '無備註資料',
              style: TextStyle(
                color: notes.isNotEmpty ? infoColor : (isDark ? Colors.white24 : Colors.black38),
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),

          // 5. Actions row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.fullscreen_rounded, color: primaryColor, size: 20),
                tooltip: context.l10n('customer_card_zoom_tooltip'),
                onPressed: () => _showCustomerZoomDetails(customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: infoColor, size: 18),
                onPressed: () => _showCustomerForm(customer: customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                onPressed: () => _showDeleteConfirm(customer['id'], customer['name'] ?? ''),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(6),
              ),
            ],
          ),
        ],
      );
    } else {
      // Narrow layout (Mobile/Compact)
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.12),
                radius: 18,
                backgroundImage: _getAvatarProvider(avatarUrl),
                child: avatarUrl.isEmpty
                    ? Text(
                        nameInitial,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: nameColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: TextStyle(color: infoColor, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.fullscreen_rounded, color: primaryColor, size: 18),
                onPressed: () => _showCustomerZoomDetails(customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: Icon(Icons.edit_outlined, color: infoColor, size: 16),
                onPressed: () => _showCustomerForm(customer: customer),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                onPressed: () => _showDeleteConfirm(customer['id'], customer['name'] ?? ''),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: tags.take(3).map((tag) {
                final style = TagCategorizer.getStyle(tag.toString(), isDark);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: style.backgroundColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag.toString(),
                    style: TextStyle(
                      color: style.textColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              notes,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black45,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: HoverAnimatedCard(
        child: Card(
          margin: EdgeInsets.zero,
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cardBorder, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: child,
          ),
        ),
      ),
    );
  }

  // Zoom Dialog
  void _showCustomerZoomDetails(Map<String, dynamic> customer) {
    final String name = customer['name'] ?? '';
    final String nickname = customer['nickname'] ?? '';
    final String phone = customer['phone'] ?? context.l10n('customer_card_not_filled');
    final String email = customer['email'] ?? context.l10n('customer_card_not_filled');
    final List tags = customer['tags'] ?? [];
    final String notes = customer['notes'] ?? '';
    final String avatarUrl = customer['avatar_url'] ?? '';

    final String displayName = nickname.isNotEmpty ? '$name ($nickname)' : name;
    final String nameInitial = name.isNotEmpty ? name.substring(0, 1) : '?';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 1.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 500),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWide = constraints.maxWidth > 500;
                
                final Widget profileSection = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Large Avatar
                    CircleAvatar(
                      backgroundColor: primaryColor.withOpacity(0.12),
                      radius: 48,
                      backgroundImage: _getAvatarProvider(avatarUrl),
                      child: avatarUrl.isEmpty
                          ? Text(
                              nameInitial,
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 36,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (nickname.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${context.l10n('customer_real_name')}：$name',
                        style: TextStyle(color: subTextColor, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // Action Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(
                          icon: Icons.phone,
                          label: context.l10n('customer_action_call'),
                          color: primaryColor,
                          onPressed: () {
                            if (phone != context.l10n('customer_card_not_filled')) {
                              Clipboard.setData(ClipboardData(text: phone));
                              CustomToast.show(context, '${context.l10n('customer_phone_copied')}: $phone', ToastType.success);
                            } else {
                              CustomToast.show(context, context.l10n('customer_phone_empty'), ToastType.warning);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.email,
                          label: context.l10n('customer_action_email'),
                          color: primaryColor,
                          onPressed: () {
                            if (email != context.l10n('customer_card_not_filled')) {
                              Clipboard.setData(ClipboardData(text: email));
                              CustomToast.show(context, '${context.l10n('customer_email_copied')}: $email', ToastType.success);
                            } else {
                              CustomToast.show(context, context.l10n('customer_email_empty'), ToastType.warning);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                );

                final Widget detailsSection = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildInfoRow(Icons.phone_iphone_rounded, context.l10n('customer_phone_title'), phone),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.mail_outline_rounded, 'Email', email),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n('customer_tags_classification'),
                      style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          final style = TagCategorizer.getStyle(tag.toString(), isDark);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: style.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag.toString(),
                              style: TextStyle(
                                color: style.textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                      )
                    else
                      Text(context.l10n('customer_card_no_tags'), style: TextStyle(color: subTextColor, fontSize: 12)),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n('customer_card_notes_detail_title'),
                      style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0D1117) : Colors.grey.shade100,
                          border: Border.all(color: borderColor, width: 1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            notes.isNotEmpty ? notes : context.l10n('customer_card_no_notes'),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '客戶詳細資訊',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: subTextColor, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isWide)
                        Flexible(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 220,
                                child: profileSection,
                              ),
                              VerticalDivider(color: borderColor, width: 32),
                              Expanded(
                                child: detailsSection,
                              ),
                            ],
                          ),
                        )
                      else
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                profileSection,
                                const SizedBox(height: 24),
                                detailsSection,
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: Colors.white),
      label: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15),
        foregroundColor: color,
        shadowColor: Colors.transparent,
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color iconColor = isDark ? Colors.white30 : Colors.black45;
    final Color valueColor = value == '未填寫' 
        ? (isDark ? Colors.white30 : Colors.black38) 
        : primaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: iconColor, fontSize: 11),
              ),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () {
                  if (value != '未填寫') {
                    Clipboard.setData(ClipboardData(text: value));
                    CustomToast.show(context, '已複製 $title: $value', ToastType.success);
                  }
                },
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 13,
                    decoration: value == '未填寫' ? null : TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3D Flipping Customer Card Widget
// ==========================================
class FlippingCustomerCard extends StatefulWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onZoom;

  const FlippingCustomerCard({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    required this.onZoom,
  });

  @override
  State<FlippingCustomerCard> createState() => _FlippingCustomerCardState();
}

class _FlippingCustomerCardState extends State<FlippingCustomerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }




  @override
  Widget build(BuildContext context) {
    final String name = widget.customer['name'] ?? '';
    final String nickname = widget.customer['nickname'] ?? '';
    final String phone = widget.customer['phone'] ?? '未填寫';
    final String email = widget.customer['email'] ?? '未填寫';
    final List tags = widget.customer['tags'] ?? [];
    final String notes = widget.customer['notes'] ?? '';
    final String avatarUrl = widget.customer['avatar_url'] ?? '';

    final String displayName = nickname.isNotEmpty ? '$name ($nickname)' : name;
    final String nameInitial = name.isNotEmpty ? name.substring(0, 1) : '?';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double transformVal = _controller.value * 3.1415926535;
        final bool showFrontSide = transformVal < (3.1415926535 / 2);

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(transformVal),
          alignment: Alignment.center,
          child: showFrontSide
              ? _buildFront(name, nickname, displayName, phone, email, tags, avatarUrl, nameInitial)
              : Transform(
                  // Counter rotate back side
                  transform: Matrix4.identity()..rotateY(3.1415926535),
                  alignment: Alignment.center,
                  child: _buildBack(name, notes),
                ),
        );
      },
    );
  }

  Widget _buildFront(
    String name,
    String nickname,
    String displayName,
    String phone,
    String email,
    List tags,
    String avatarUrl,
    String nameInitial,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;
    final Color nameColor = isDark ? Colors.white : Colors.black87;
    final Color infoColor = isDark ? Colors.white54 : Colors.black54;
    final Color iconColor = isDark ? Colors.white30 : Colors.black38;

    return Card(
      margin: EdgeInsets.zero,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      child: InkWell(
        onTap: _flip,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section (Avatar & Info & Flip icon)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with Photo support
                  CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.12),
                    radius: 24,
                    backgroundImage: _getAvatarProvider(avatarUrl),
                    child: avatarUrl.isEmpty
                        ? Text(
                            nameInitial,
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Name & Info Columns
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            color: nameColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.phone, size: 12, color: iconColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                phone,
                                style: TextStyle(color: infoColor, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.email, size: 12, color: iconColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                style: TextStyle(color: infoColor, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action icons on the right (Zoom & Flip)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: Icon(Icons.fullscreen_rounded, color: iconColor, size: 20),
                        tooltip: context.l10n('customer_card_zoom_tooltip'),
                        onPressed: widget.onZoom,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.flip_camera_android_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Tags Row
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags.take(3).map((tag) {
                    final style = TagCategorizer.getStyle(tag.toString(), isDark);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: style.backgroundColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag.toString(),
                        style: TextStyle(
                          color: style.textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBack(String name, String notes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Card(
      margin: EdgeInsets.zero,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor, width: 1.5),
      ),
      child: InkWell(
        onTap: _flip,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${context.l10n('customer_card_notes_title')} ($name)',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.fullscreen_rounded, color: primaryColor, size: 16),
                        tooltip: context.l10n('customer_card_zoom_tooltip'),
                        onPressed: widget.onZoom,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: subTextColor, size: 16),
                        onPressed: widget.onEdit,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                        onPressed: widget.onDelete,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.flip_camera_android_rounded,
                        color: primaryColor,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
              Divider(color: isDark ? const Color(0xFF21262D) : Colors.grey.shade300, height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    notes.isNotEmpty ? notes : context.l10n('customer_card_no_notes'),
                    style: TextStyle(
                      color: notes.isNotEmpty 
                          ? (isDark ? Colors.white : Colors.black87) 
                          : (isDark ? Colors.white38 : Colors.black45),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// Custom Toast Notification System
// ==========================================
enum ToastType { success, warning, error }

class CustomToast extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const CustomToast({
    key,
    required this.message,
    required this.type,
    required this.onDismiss,
    this.actionLabel,
    this.onActionPressed,
  }) : super(key: key);

  static void show(
    BuildContext context, 
    String message, 
    ToastType type, {
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 24,
        right: MediaQuery.of(context).size.width >= 768 ? 24 : null,
        left: MediaQuery.of(context).size.width >= 768 ? null : 24,
        width: MediaQuery.of(context).size.width >= 768 ? 360 : MediaQuery.of(context).size.width - 48,
        child: CustomToast(
          message: message,
          type: type,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed,
          onDismiss: () {
            overlayEntry.remove();
          },
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
  }

  @override
  State<CustomToast> createState() => _CustomToastState();
}

class _CustomToastState extends State<CustomToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color glowColor;
    IconData icon;
    Color iconColor;

    switch (widget.type) {
      case ToastType.success:
        borderColor = const Color(0xFF00ADB5);
        glowColor = const Color(0xFF00ADB5).withOpacity(0.2);
        icon = Icons.check_circle_outline;
        iconColor = const Color(0xFF00F5FF);
        break;
      case ToastType.warning:
        borderColor = Colors.amber;
        glowColor = Colors.amber.withOpacity(0.2);
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.amber;
        break;
      case ToastType.error:
        borderColor = Colors.redAccent;
        glowColor = Colors.redAccent.withOpacity(0.2);
        icon = Icons.error_outline_rounded;
        iconColor = Colors.redAccent;
        break;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.actionLabel != null && widget.onActionPressed != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      widget.onActionPressed!();
                      _controller.reverse().then((_) {
                        widget.onDismiss();
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00F5FF),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      widget.actionLabel!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white30, size: 16),
                  onPressed: () {
                    _controller.reverse().then((_) {
                      widget.onDismiss();
                    });
                  },
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper to get image provider from URL or Base64 data URI
ImageProvider? _getAvatarProvider(String avatarUrl) {
  if (avatarUrl.isEmpty) return null;
  if (avatarUrl.startsWith('data:image/') || avatarUrl.startsWith('data:application/')) {
    try {
      final base64String = avatarUrl.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      return null;
    }
  }
  return NetworkImage(avatarUrl);
}

// Shimmer card widget for list loading states
class CustomerCardShimmer extends StatelessWidget {
  const CustomerCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;

    return Card(
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar Shimmer
                const ShimmerLoader(width: 40, height: 40, borderRadius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      // Name Shimmer
                      ShimmerLoader(width: 120, height: 16, borderRadius: 4),
                      SizedBox(height: 6),
                      // Details Shimmer
                      ShimmerLoader(width: 80, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Tags Shimmer
            Row(
              children: const [
                ShimmerLoader(width: 50, height: 18, borderRadius: 4),
                SizedBox(width: 8),
                ShimmerLoader(width: 60, height: 18, borderRadius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Shimmer list card widget for list loading states
class CustomerListShimmer extends StatelessWidget {
  const CustomerListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color cardBorder = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardBg,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cardBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            // Avatar
            const ShimmerLoader(width: 40, height: 40, borderRadius: 20),
            const SizedBox(width: 16),
            // Name
            const ShimmerLoader(width: 100, height: 16, borderRadius: 4),
            const SizedBox(width: 24),
            // Contact info (Wide screen simulation or general spacing)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  ShimmerLoader(width: 120, height: 10, borderRadius: 4),
                  SizedBox(height: 6),
                  ShimmerLoader(width: 140, height: 10, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Tags shimmer
            Expanded(
              flex: 2,
              child: Row(
                children: const [
                  ShimmerLoader(width: 60, height: 18, borderRadius: 4),
                  SizedBox(width: 8),
                  ShimmerLoader(width: 50, height: 18, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Actions
            const ShimmerLoader(width: 80, height: 24, borderRadius: 12),
          ],
        ),
      ),
    );
  }
}

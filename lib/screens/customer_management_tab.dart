import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/app_settings.dart';

class CustomerManagementTab extends StatefulWidget {
  const CustomerManagementTab({super.key});

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

    if (isOfflineMode) {
      // Offline fallback: load from state or initial mock list
      if (_allCustomers.isEmpty) {
        _allCustomers = List.from(_mockCustomers);
      }
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
      if (query.isEmpty) {
        _filteredCustomers = List.from(_allCustomers);
      } else {
        _filteredCustomers = _allCustomers.where((customer) {
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
  }) async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      final newCustomer = {
        'id': 'mock-${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'nickname': nickname,
        'avatar_url': avatarUrl,
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
        'avatar_url': avatarUrl,
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
  }) async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      setState(() {
        final index = _allCustomers.indexWhere((c) => c['id'] == id);
        if (index != -1) {
          _allCustomers[index] = {
            ..._allCustomers[index],
            'name': name,
            'nickname': nickname,
            'avatar_url': avatarUrl,
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
        'avatar_url': avatarUrl,
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

  // Delete Customer logic
  Future<void> _deleteCustomer(String id) async {
    setState(() {
      _isLoading = true;
    });

    if (isOfflineMode) {
      setState(() {
        _allCustomers.removeWhere((c) => c['id'] == id);
        _isLoading = false;
      });
      _filterCustomers();
      if (mounted) {
        CustomToast.show(context, '成功刪除客戶檔案 (離線暫存)', ToastType.success);
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('customers').delete().eq('id', id);
      await _fetchCustomers();
      if (mounted) {
        CustomToast.show(context, '成功刪除客戶檔案', ToastType.success);
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
    final avatarUrlController = TextEditingController(text: isEdit ? customer['avatar_url'] : '');
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
        return AlertDialog(
          backgroundColor: dialogBg,
          title: Text(
            isEdit ? '編輯客戶檔案' : '新增客戶檔案',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: textColor),
                    decoration: buildInputDecoration('客戶姓名 (必填)', Icons.person_outline),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nicknameController,
                    style: TextStyle(color: textColor),
                    decoration: buildInputDecoration('客戶綽號', Icons.person_pin_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: avatarUrlController,
                    style: TextStyle(color: textColor),
                    decoration: buildInputDecoration('照片網址 (URL)', Icons.image_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    style: TextStyle(color: textColor),
                    keyboardType: TextInputType.phone,
                    decoration: buildInputDecoration('電話號碼', Icons.phone_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    style: TextStyle(color: textColor),
                    keyboardType: TextInputType.emailAddress,
                    decoration: buildInputDecoration('Email 信箱', Icons.email_outlined),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagsController,
                    style: TextStyle(color: textColor),
                    decoration: buildInputDecoration('標籤 (逗號區隔)', Icons.local_offer_outlined, hintText: '例如: 高意願, 醫療險, 車險'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    style: TextStyle(color: textColor),
                    maxLines: 3,
                    decoration: buildInputDecoration('備註紀錄', Icons.note_alt_outlined),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: subTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
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
                    avatarUrl: avatarUrlController.text.trim(),
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    tags: tagsList,
                    notes: notesController.text.trim(),
                  );
                } else {
                  _createCustomer(
                    name: name,
                    nickname: nicknameController.text.trim(),
                    avatarUrl: avatarUrlController.text.trim(),
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    tags: tagsList,
                    notes: notesController.text.trim(),
                  );
                }

                Navigator.pop(context);
              },
              child: const Text('儲存'),
            ),
          ],
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
          title: Text('確認刪除', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
          content: Text('確定要刪除客戶「$name」的完整檔案嗎？此操作無法還原。', style: TextStyle(color: textColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: subTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () {
                _deleteCustomer(id);
                Navigator.pop(context);
              },
              child: const Text('刪除'),
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
                      hintText: '搜尋客戶姓名或標籤...',
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
              const SizedBox(width: 16),
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
                label: const Text('新增客戶', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Customer Grid/List Area
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : _filteredCustomers.isEmpty
                    ? _buildEmptyState(isDark, primaryColor)
                    : _buildCustomerGrid(isWideScreen, screenWidth),
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
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: _filteredCustomers.length,
      itemBuilder: (context, index) {
        final customer = _filteredCustomers[index];
        return FlippingCustomerCard(
          customer: customer,
          onEdit: () => _showCustomerForm(customer: customer),
          onDelete: () => _showDeleteConfirm(customer['id'], customer['name'] ?? ''),
        );
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
            '尚未建立客戶或查無此人',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '點選右上角的「新增客戶」按鈕開始建立客戶資料。\n您也可以輸入其他關鍵字搜尋。',
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
}

// ==========================================
// 3D Flipping Customer Card Widget
// ==========================================
class FlippingCustomerCard extends StatefulWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FlippingCustomerCard({
    super.key,
    required this.customer,
    required this.onEdit,
    required this.onDelete,
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

  void _showZoomDetails(BuildContext context) {
    final String name = widget.customer['name'] ?? '';
    final String nickname = widget.customer['nickname'] ?? '';
    final String phone = widget.customer['phone'] ?? '未填寫';
    final String email = widget.customer['email'] ?? '未填寫';
    final List tags = widget.customer['tags'] ?? [];
    final String notes = widget.customer['notes'] ?? '';
    final String avatarUrl = widget.customer['avatar_url'] ?? '';

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
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
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
                        '本名：$name',
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
                          label: '撥打',
                          color: primaryColor,
                          onPressed: () {
                            if (phone != '未填寫') {
                              Clipboard.setData(ClipboardData(text: phone));
                              CustomToast.show(context, '已複製電話號碼至剪貼簿: $phone', ToastType.success);
                            } else {
                              CustomToast.show(context, '電話未填寫', ToastType.warning);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.email,
                          label: '郵件',
                          color: primaryColor,
                          onPressed: () {
                            if (email != '未填寫') {
                              Clipboard.setData(ClipboardData(text: email));
                              CustomToast.show(context, '已複製電子信信箱至剪貼簿: $email', ToastType.success);
                            } else {
                              CustomToast.show(context, '信箱未填寫', ToastType.warning);
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
                    _buildInfoRow(Icons.phone_iphone_rounded, '電話', phone, context),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.mail_outline_rounded, 'Email', email, context),
                    const SizedBox(height: 16),
                    Text(
                      '標籤分類',
                      style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag.toString(),
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )).toList(),
                      )
                    else
                      Text('暫無標籤', style: TextStyle(color: subTextColor, fontSize: 12)),
                    const SizedBox(height: 16),
                    Text(
                      '備註說明',
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
                            notes.isNotEmpty ? notes : '無備註資訊。',
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

  Widget _buildInfoRow(IconData icon, String title, String value, BuildContext context) {
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
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
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
                        tooltip: '放大詳情',
                        onPressed: () => _showZoomDetails(context),
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
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag.toString(),
                        style: TextStyle(
                          color: primaryColor,
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
                      '備註 ($name)',
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
                        tooltip: '放大詳情',
                        onPressed: () => _showZoomDetails(context),
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
                    notes.isNotEmpty ? notes : '無備註資訊。',
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

  const CustomToast({
    key,
    required this.message,
    required this.type,
    required this.onDismiss,
  }) : super(key: key);

  static void show(BuildContext context, String message, ToastType type) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 24,
        right: MediaQuery.of(context).size.width >= 768 ? 24 : null,
        left: MediaQuery.of(context).size.width >= 768 ? null : 24,
        width: MediaQuery.of(context).size.width >= 768 ? 320 : MediaQuery.of(context).size.width - 48,
        child: CustomToast(
          message: message,
          type: type,
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

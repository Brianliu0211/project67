import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

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
      'phone': '0912-345678',
      'email': 'chunya.lin@gmail.com',
      'tags': ['高意願', '醫療險', '定期壽險'],
      'notes': '對家庭防護極有興趣，育有二子。預計下月發薪後再行拜訪談細節。',
      'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
    },
    {
      'id': 'mock-2',
      'name': '王小明',
      'phone': '0923-456789',
      'email': 'xiaoming.wang@gmail.com',
      'tags': ['已簽單', '汽車責任險'],
      'notes': '新購進口休旅車，已完成汽車責任險與甲式車體險簽單，保單寄送中。',
      'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
    },
    {
      'id': 'mock-3',
      'name': '陳美玲',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('讀取資料庫失敗: $e\n自動啟用離線列表。'),
            backgroundColor: Colors.amber.shade900,
          ),
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
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('使用者未登入');

      await supabase.from('customers').insert({
        'profile_id': user.id,
        'name': name,
        'phone': phone,
        'email': email,
        'tags': tags,
        'notes': notes,
      });

      await _fetchCustomers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增失敗: $e'), backgroundColor: Colors.redAccent),
        );
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
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('customers').update({
        'name': name,
        'phone': phone,
        'email': email,
        'tags': tags,
        'notes': notes,
      }).eq('id', id);

      await _fetchCustomers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('修改失敗: $e'), backgroundColor: Colors.redAccent),
        );
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
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('customers').delete().eq('id', id);
      await _fetchCustomers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刪除失敗: $e'), backgroundColor: Colors.redAccent),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Display Add/Edit Dialog Form
  void _showCustomerForm({Map<String, dynamic>? customer}) {
    final isEdit = customer != null;
    final nameController = TextEditingController(text: isEdit ? customer['name'] : '');
    final phoneController = TextEditingController(text: isEdit ? customer['phone'] : '');
    final emailController = TextEditingController(text: isEdit ? customer['email'] : '');
    final tagsController = TextEditingController(
        text: isEdit ? (customer['tags'] as List).join(', ') : '');
    final notesController = TextEditingController(text: isEdit ? customer['notes'] : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: Text(isEdit ? '編輯客戶檔案' : '新增客戶檔案', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '客戶姓名 (必填)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: '電話號碼',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email 信箱',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(
                      labelText: '標籤 (逗號區隔)',
                      hintText: '例如: 高意願, 醫療險, 車險',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_offer_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '備註紀錄',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ADB5),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('客戶姓名為必填項目')),
                  );
                  return;
                }

                // Parse tags comma string to string list
                final tagsList = tagsController.text
                    .split(RegExp(r'[,，]'))
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();

                if (isEdit) {
                  _updateCustomer(
                    id: customer['id'],
                    name: name,
                    phone: phoneController.text.trim(),
                    email: emailController.text.trim(),
                    tags: tagsList,
                    notes: notesController.text.trim(),
                  );
                } else {
                  _createCustomer(
                    name: name,
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('確認刪除', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('確定要刪除客戶「$name」的完整檔案嗎？此操作無法還原。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消', style: TextStyle(color: Colors.white54)),
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
                    decoration: InputDecoration(
                      hintText: '搜尋客戶姓名或標籤...',
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      fillColor: const Color(0xFF161B22),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF30363D)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFF00ADB5), width: 1.5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _showCustomerForm(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ADB5),
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
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00ADB5)),
                  )
                : _filteredCustomers.isEmpty
                    ? _buildEmptyState()
                    : _buildCustomerGrid(isWideScreen, screenWidth),
          ),
        ],
      ),
    );
  }

  // Grid/List Layout
  Widget _buildCustomerGrid(bool isWideScreen, double screenWidth) {
    // RWD grid columns calculation
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
      // Mobile
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
        return _buildCustomerCard(customer);
      },
    );
  }

  // Single Customer Card UI
  Widget _buildCustomerCard(Map<String, dynamic> customer) {
    final String name = customer['name'] ?? '';
    final String phone = customer['phone'] ?? '未填寫';
    final String email = customer['email'] ?? '未填寫';
    final List tags = customer['tags'] ?? [];
    final String notes = customer['notes'] ?? '';
    
    final String nameInitial = name.isNotEmpty ? name.substring(0, 1) : '?';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF21262D), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section (Avatar & Info & Action buttons)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: const Color(0xFF00ADB5).withOpacity(0.1),
                  radius: 20,
                  child: Text(
                    nameInitial,
                    style: const TextStyle(
                      color: Color(0xFF00F5FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Name & Info Columns
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 12, color: Colors.white30),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              phone,
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.email, size: 12, color: Colors.white30),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email, 
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Card Actions Column
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white54, size: 18),
                      onPressed: () => _showCustomerForm(customer: customer),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                      onPressed: () => _showDeleteConfirm(customer['id'], name),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Notes Preview
            if (notes.isNotEmpty) ...[
              const Divider(color: Color(0xFF21262D), height: 12),
              Text(
                notes,
                style: const TextStyle(
                  color: Colors.white30,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
            ],
            
            // Tags Row
            if (tags.isNotEmpty)
              SizedBox(
                height: 22,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    final tag = tags[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00ADB5).withOpacity(0.08),
                        border: Border.all(color: const Color(0xFF00ADB5).withOpacity(0.2), width: 1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF00ADB5),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      )),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: const Color(0xFF00ADB5).withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            '尚未建立客戶或查無此人',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '點選右上角的「新增客戶」按鈕開始建立客戶資料。\n您也可以輸入其他關鍵字搜尋。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white30,
            ),
          ),
        ],
      ),
    );
  }
}

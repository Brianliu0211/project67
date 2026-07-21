import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../main.dart';
import '../services/app_settings.dart';
import 'customer_management_tab.dart'; // To use CustomToast
import '../widgets/animations.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  const ProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _companyController;
  late TextEditingController _jobTitleController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _bioController;

  String _userEmail = '';
  String _currentAvatarUrl = '';
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isImageCleared = false;

  // Focus Nodes for Enter key navigation
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _companyFocus = FocusNode();
  final FocusNode _jobTitleFocus = FocusNode();
  final FocusNode _websiteFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _bioFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _companyController = TextEditingController();
    _jobTitleController = TextEditingController();
    _websiteController = TextEditingController();
    _addressController = TextEditingController();
    _bioController = TextEditingController();

    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _bioController.dispose();

    _nameFocus.dispose();
    _phoneFocus.dispose();
    _companyFocus.dispose();
    _jobTitleFocus.dispose();
    _websiteFocus.dispose();
    _addressFocus.dispose();
    _bioFocus.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate 500ms network delay to make the shimmer skeleton clearly visible during debug preview
    await Future.delayed(const Duration(milliseconds: 500));

    if (isOfflineMode) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _nameController.text = prefs.getString('profile_name') ?? '王大同';
        _phoneController.text = prefs.getString('profile_phone') ?? '0912-345678';
        _companyController.text = prefs.getString('profile_company') ?? '國泰人壽';
        _jobTitleController.text = prefs.getString('profile_job_title') ?? '高級理財顧問';
        _websiteController.text = prefs.getString('profile_website') ?? 'www.cathayholdings.com';
        _addressController.text = prefs.getString('profile_address') ?? '台北市信義區松仁路7號';
        _bioController.text = prefs.getString('profile_bio') ?? '專業、誠信、客戶至上。致力於為每個家庭規劃最完善的保障方案。';
        _currentAvatarUrl = prefs.getString('profile_avatar_url') ?? '';
        _userEmail = 'offline@insurance.helper';
        _isLoading = false;
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        _userEmail = user.email ?? '';
        
        final data = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            _nameController.text = data['full_name'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _companyController.text = data['company'] ?? '';
            _jobTitleController.text = data['job_title'] ?? '';
            _websiteController.text = data['website'] ?? '';
            _addressController.text = data['address'] ?? '';
            _bioController.text = data['bio'] ?? '';
            _currentAvatarUrl = data['avatar_url'] ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '載入個人資料失敗: $e', ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    String finalAvatarUrl = _currentAvatarUrl;

    // 1. Handle image upload if a new image was chosen
    if (_isImageCleared) {
      finalAvatarUrl = '';
    } else if (_selectedImageBytes != null && _selectedImageName != null) {
      if (isOfflineMode) {
        finalAvatarUrl = 'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}';
      } else {
        try {
          final supabase = Supabase.instance.client;
          final user = supabase.auth.currentUser;
          if (user == null) throw Exception('使用者未登入');

          final extension = _selectedImageName != null && _selectedImageName!.contains('.') 
              ? _selectedImageName!.split('.').last 
              : 'jpg';
          final cleanExtension = RegExp(r'^[a-zA-Z0-9]+$').hasMatch(extension) ? extension : 'jpg';
          final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$cleanExtension';
          
          await supabase.storage.from('avatars').uploadBinary(
            fileName,
            _selectedImageBytes!,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
          
          finalAvatarUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
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

    // 2. Save data based on mode
    if (isOfflineMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_name', _nameController.text.trim());
        await prefs.setString('profile_phone', _phoneController.text.trim());
        await prefs.setString('profile_company', _companyController.text.trim());
        await prefs.setString('profile_job_title', _jobTitleController.text.trim());
        await prefs.setString('profile_website', _websiteController.text.trim());
        await prefs.setString('profile_address', _addressController.text.trim());
        await prefs.setString('profile_bio', _bioController.text.trim());
        await prefs.setString('profile_avatar_url', finalAvatarUrl);

        if (mounted) {
          setState(() {
            _currentAvatarUrl = finalAvatarUrl;
            _selectedImageBytes = null;
            _selectedImageName = null;
            _isImageCleared = false;
            _isLoading = false;
          });
          CustomToast.show(context, '個人資料已儲存 (離線暫存)', ToastType.success);
          widget.onProfileUpdated?.call();
        }
      } catch (e) {
        if (mounted) {
          CustomToast.show(context, '儲存失敗: $e', ToastType.error);
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('使用者未登入');

      await supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'company': _companyController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'website': _websiteController.text.trim(),
        'address': _addressController.text.trim(),
        'bio': _bioController.text.trim(),
        'avatar_url': finalAvatarUrl,
      }).eq('id', user.id);

      if (mounted) {
        setState(() {
          _currentAvatarUrl = finalAvatarUrl;
          _selectedImageBytes = null;
          _selectedImageName = null;
          _isImageCleared = false;
        });
        CustomToast.show(context, '個人資料已成功更新', ToastType.success);
        widget.onProfileUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '儲存失敗: $e', ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  ImageProvider? _getAvatarProvider() {
    if (_selectedImageBytes != null) {
      return MemoryImage(_selectedImageBytes!);
    }
    if (_isImageCleared || _currentAvatarUrl.isEmpty) {
      return null;
    }
    if (_currentAvatarUrl.startsWith('data:image/') || _currentAvatarUrl.startsWith('data:application/')) {
      try {
        final base64String = _currentAvatarUrl.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(_currentAvatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 768;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF30363D) : Colors.grey.shade300;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    InputDecoration buildInputDecoration(String labelText, IconData iconData, {String? hintText}) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: subTextColor, fontSize: 13),
        hintText: hintText,
        hintStyle: TextStyle(color: subTextColor, fontSize: 13),
        prefixIcon: Icon(iconData, color: primaryColor.withOpacity(0.7), size: 18),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0D1117).withOpacity(0.5) : Colors.grey.shade50,
      );
    }

    Widget profileHeaderCard() {
      final avatarProvider = _getAvatarProvider();
      final initialLetter = _nameController.text.isNotEmpty ? _nameController.text.substring(0, 1) : '?';

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            // Circle Avatar selector
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(54),
                onTap: () async {
                  try {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (image != null) {
                      final bytes = await image.readAsBytes();
                      setState(() {
                        _selectedImageBytes = bytes;
                        _selectedImageName = image.name;
                        _isImageCleared = false;
                      });
                    }
                  } catch (e) {
                    if (mounted) {
                      CustomToast.show(context, '選擇照片失敗: $e', ToastType.error);
                    }
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: primaryColor.withOpacity(0.12),
                        backgroundImage: avatarProvider,
                        child: avatarProvider == null
                            ? Text(
                                initialLetter,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 48,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: primaryColor,
                        child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (avatarProvider != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                label: const Text('清除頭像', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                onPressed: () {
                  setState(() {
                    _selectedImageBytes = null;
                    _selectedImageName = null;
                    _isImageCleared = true;
                  });
                },
              ),
            ] else ...[
              const SizedBox(height: 12),
            ],

            Text(
              _nameController.text.isNotEmpty ? _nameController.text : '您的姓名',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              _jobTitleController.text.isNotEmpty 
                  ? '${_jobTitleController.text} • ${_companyController.text.isNotEmpty ? _companyController.text : "保險經紀人"}'
                  : '尚未設定職稱',
              style: TextStyle(fontSize: 12, color: subTextColor),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline_rounded, size: 14, color: subTextColor),
                  const SizedBox(width: 6),
                  Text(_userEmail, style: TextStyle(fontSize: 11, color: subTextColor)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget profileForm() {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Basic Info
            Row(
              children: [
                Icon(Icons.person_outline_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text('基本資料設定', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              focusNode: _nameFocus,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_phoneFocus),
              decoration: buildInputDecoration('個人姓名', Icons.badge_outlined),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '請輸入您的姓名';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              style: TextStyle(color: textColor),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_companyFocus),
              decoration: buildInputDecoration('聯絡電話', Icons.phone_android_rounded),
            ),
            
            const SizedBox(height: 24),
            
            // Section 2: Business Card Details
            Row(
              children: [
                Icon(Icons.business_center_outlined, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text('商務與名片資訊', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _companyController,
                    focusNode: _companyFocus,
                    style: TextStyle(color: textColor),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_jobTitleFocus),
                    decoration: buildInputDecoration('所屬公司', Icons.corporate_fare_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _jobTitleController,
                    focusNode: _jobTitleFocus,
                    style: TextStyle(color: textColor),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_websiteFocus),
                    decoration: buildInputDecoration('專業職稱', Icons.work_outline_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              focusNode: _websiteFocus,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_addressFocus),
              decoration: buildInputDecoration('公司 / 個人網站', Icons.web_rounded, hintText: '例如: www.mywebsite.com'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              focusNode: _addressFocus,
              maxLines: 2,
              style: TextStyle(color: textColor),
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_bioFocus),
              decoration: buildInputDecoration('服務地址', Icons.location_on_outlined),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              focusNode: _bioFocus,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: buildInputDecoration('個人簡介 (會顯示在名片背面或詳細資訊中)', Icons.info_outline_rounded),
            ),
            
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveProfile,
              icon: _isLoading 
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_isLoading ? '正在儲存...' : '儲存變更', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 2,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: _isLoading && _userEmail.isEmpty
          ? const ProfileShimmer()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // RWD split layout
                      if (isWideScreen)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 260,
                              child: profileHeaderCard(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                ),
                                child: profileForm(),
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            profileHeaderCard(),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: profileForm(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// Profile Shimmer Skeleton Loading Widget
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 750;

    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF21262D) : Colors.grey.shade300;

    Widget shimmerHeaderCard() {
      return Card(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: const [
              ShimmerLoader(width: 96, height: 96, borderRadius: 48),
              SizedBox(height: 16),
              ShimmerLoader(width: 120, height: 18, borderRadius: 4),
              SizedBox(height: 8),
              ShimmerLoader(width: 160, height: 12, borderRadius: 4),
            ],
          ),
        ),
      );
    }

    Widget shimmerForm() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoader(width: 150, height: 20, borderRadius: 4),
          const SizedBox(height: 24),
          for (int i = 0; i < 4; i++) ...[
            const ShimmerLoader(width: 80, height: 14, borderRadius: 4),
            const SizedBox(height: 8),
            const ShimmerLoader(width: double.infinity, height: 44, borderRadius: 8),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: ShimmerLoader(width: 100, height: 40, borderRadius: 8),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: isWideScreen
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: shimmerHeaderCard(),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: shimmerForm(),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    shimmerHeaderCard(),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: shimmerForm(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

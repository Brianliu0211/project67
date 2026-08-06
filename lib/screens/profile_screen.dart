import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:html' as html if (dart.library.io) 'dart:io';
import '../main.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import 'customer_management_tab.dart'; // To use CustomToast
import '../widgets/custom_toast.dart';
import '../widgets/animations.dart';
import '../widgets/reset_password_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  const ProfileScreen({super.key, this.onProfileUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _cardRenderKey = GlobalKey(); // RepaintBoundary Key for PNG export
  bool _isLoading = false;
  bool _isExportingImage = false;
  int _activeTabIndex = 0; // Segmented Control Tab Index (0: 基本, 1: 商務, 2: 榮譽頭銜, 3: 安全)

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _lineIdController;
  late TextEditingController _companyController;
  late TextEditingController _jobTitleController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _bioController;
  late TextEditingController _customHonorController;
  late TextEditingController _customBadgeController;

  String _userEmail = '';
  String _currentAvatarUrl = '';
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isImageCleared = false;
  Uint8List? _qrCodeImageBytes;
  String _currentQrCodeUrl = '';

  // Digital Business Card Customization States
  Set<String> _selectedBadges = {'MDRT 頂尖會員', '人身保險業務員'};
  String _selectedTheme = 'system_primary'; // 'system_primary', 'dark_gold', 'cyan_slate', 'emerald', 'custom_color'
  Color _customCardColor = const Color(0xFF8B5CF6); // Default Violet Custom Swatch
  String _honorTitle = 'VIP 鑽石顧問'; // Professional Honor Title
  String _previewDevice = 'mobile'; // 'mobile', 'desktop'
  bool _isCardFlipped = false;
  String _glareMode = 'none'; // 'none' (default), 'tcg_rainbow', 'metallic_tint'

  // 3D Mouse Tilt State
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  double _glareX = 0.5;
  double _glareY = 0.5;

  List<String> _availableBadges = [
    'MDRT 頂尖會員',
    'CFP 國際理財規劃師',
    'RFA 退休理財顧問',
    '人身保險業務員',
    '投資型保單認證',
    '產物保險合格',
    '高淨值資產傳承',
    '企業團險專家',
  ];

  final List<String> _availableHonorTitles = [
    'VIP 鑽石顧問',
    '資深分行經理',
    '首席理財大師',
    '榮譽尊榮金鑽',
  ];

  // Focus Nodes for Inline Click-to-Edit
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _lineIdFocus = FocusNode();
  final FocusNode _companyFocus = FocusNode();
  final FocusNode _jobTitleFocus = FocusNode();
  final FocusNode _websiteFocus = FocusNode();
  final FocusNode _addressFocus = FocusNode();
  final FocusNode _bioFocus = FocusNode();

  late final Listenable _controllersListenable;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _lineIdController = TextEditingController();
    _companyController = TextEditingController();
    _jobTitleController = TextEditingController();
    _websiteController = TextEditingController();
    _addressController = TextEditingController();
    _bioController = TextEditingController();
    _customHonorController = TextEditingController();
    _customBadgeController = TextEditingController();

    _controllersListenable = Listenable.merge([
      _nameController,
      _phoneController,
      _lineIdController,
      _companyController,
      _jobTitleController,
      _websiteController,
      _addressController,
      _bioController,
    ]);

    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _lineIdController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _customHonorController.dispose();
    _customBadgeController.dispose();

    _nameFocus.dispose();
    _phoneFocus.dispose();
    _lineIdFocus.dispose();
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

    await Future.delayed(const Duration(milliseconds: 200));

    if (isOfflineMode) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _nameController.text = prefs.getString('profile_name') ?? '蘿蔔';
        _phoneController.text = prefs.getString('profile_phone') ?? '0912-345678';
        _lineIdController.text = prefs.getString('profile_line_id') ?? '';
        _companyController.text = prefs.getString('profile_company') ?? '國泰人壽';
        _jobTitleController.text = prefs.getString('profile_job_title') ?? '資深理財顧問';
        _websiteController.text = prefs.getString('profile_website') ?? '';
        _addressController.text = prefs.getString('profile_address') ?? '';
        _bioController.text = prefs.getString('profile_bio') ?? '專業、誠信、客戶至上。致力於為每個家庭規劃最完善的保障方案與資產傳承策略。';
        _currentAvatarUrl = prefs.getString('profile_avatar_url') ?? '';
        _userEmail = 'brain2013bb@gmail.com';
        _selectedTheme = prefs.getString('profile_theme') ?? 'system_primary';
        _honorTitle = prefs.getString('profile_honor_title') ?? 'VIP 鑽石顧問';
        final savedBadges = prefs.getStringList('profile_badges');
        if (savedBadges != null && savedBadges.isNotEmpty) {
          _selectedBadges = savedBadges.toSet();
        }
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
            _lineIdController.text = data['line_id'] ?? '';
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
        CustomToast.show(context, '${context.l10n('profile_load_failed')}: $e', ToastType.error);
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
            CustomToast.show(context, '${context.l10n('profile_avatar_upload_failed')}: $e', ToastType.error);
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    }

    if (isOfflineMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_name', _nameController.text.trim());
        await prefs.setString('profile_phone', _phoneController.text.trim());
        await prefs.setString('profile_line_id', _lineIdController.text.trim());
        await prefs.setString('profile_company', _companyController.text.trim());
        await prefs.setString('profile_job_title', _jobTitleController.text.trim());
        await prefs.setString('profile_website', _websiteController.text.trim());
        await prefs.setString('profile_address', _addressController.text.trim());
        await prefs.setString('profile_bio', _bioController.text.trim());
        await prefs.setString('profile_avatar_url', finalAvatarUrl);
        await prefs.setString('profile_theme', _selectedTheme);
        await prefs.setString('profile_honor_title', _honorTitle);
        await prefs.setStringList('profile_badges', _selectedBadges.toList());

        if (mounted) {
          setState(() {
            _currentAvatarUrl = finalAvatarUrl;
            _selectedImageBytes = null;
            _selectedImageName = null;
            _isImageCleared = false;
            _isLoading = false;
          });
          CustomToast.show(context, '🟢 ${context.l10n('profile_save_success_offline')}', ToastType.success);
          widget.onProfileUpdated?.call();
        }
      } catch (e) {
        if (mounted) {
          CustomToast.show(context, '${context.l10n('profile_save_failed')}: $e', ToastType.error);
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
        CustomToast.show(context, '🟢 ${context.l10n('profile_save_success')}', ToastType.success);
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

  // --- Export Front Business Card as HD Image (PNG) ---
  Future<void> _downloadCardAsImage() async {
    if (_isCardFlipped) {
      // Auto flip to Front before capture
      setState(() {
        _isCardFlipped = false;
      });
      await Future.delayed(const Duration(milliseconds: 350));
    }

    setState(() {
      _isExportingImage = true;
    });

    try {
      final boundary = _cardRenderKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('卡片元件尚未準備完成');

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0); // 3x HD Quality
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('圖片轉換失敗');

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : '保險名片';

      if (kIsWeb) {
        final blob = html.Blob([pngBytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', '${name}_電子名片.png')
          ..click();
        html.Url.revokeObjectUrl(url);
        CustomToast.show(context, '🟢 已成功匯出高清名片圖片 (${name}_電子名片.png)！', ToastType.success);
      } else {
        Clipboard.setData(ClipboardData(text: '名片圖片已產生 (${pngBytes.length} bytes)'));
        CustomToast.show(context, '已複製名片圖片資料檔！', ToastType.success);
      }
    } catch (e) {
      CustomToast.show(context, '匯出圖片失敗: $e', ToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isExportingImage = false;
        });
      }
    }
  }

  // --- Inline Edit Focus Helper ---
  void _focusInlineField(int tabIndex, FocusNode node) {
    setState(() {
      _activeTabIndex = tabIndex;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(node);
      }
    });
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

  // --- Dynamic Theme & Card Presets System-Harmonized ---
  Map<String, dynamic> _getCardThemeConfig(bool isDark, Color primaryColor) {
    switch (_selectedTheme) {
      case 'dark_gold':
        return {
          'bgGradient': [const Color(0xFF1C1917), const Color(0xFF292524)],
          'border': const Color(0xFFEAB308),
          'accent': const Color(0xFFEAB308),
          'badgeBg': const Color(0xFF78350F),
          'badgeText': const Color(0xFFFEF08A),
          'textColor': Colors.white,
          'subTextColor': const Color(0xFFD6D3D1),
        };
      case 'emerald':
        return {
          'bgGradient': isDark
              ? [const Color(0xFF064E3B), const Color(0xFF047857)]
              : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
          'border': const Color(0xFF10B981),
          'accent': const Color(0xFF10B981),
          'badgeBg': const Color(0xFF065F46),
          'badgeText': const Color(0xFFA7F3D0),
          'textColor': isDark ? Colors.white : const Color(0xFF064E3B),
          'subTextColor': isDark ? const Color(0xFFD1FAE5) : const Color(0xFF047857),
        };
      case 'cyan_slate':
        return {
          'bgGradient': isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)],
          'border': const Color(0xFF0EA5E9),
          'accent': const Color(0xFF0EA5E9),
          'badgeBg': const Color(0xFF0369A1),
          'badgeText': const Color(0xFFBAE6FD),
          'textColor': isDark ? Colors.white : const Color(0xFF0F172A),
          'subTextColor': isDark ? const Color(0xFF94A3B8) : const Color(0xFF0369A1),
        };
      case 'custom_color':
        return {
          'bgGradient': isDark
              ? [const Color(0xFF0F172A), _customCardColor.withOpacity(0.35)]
              : [_customCardColor.withOpacity(0.08), _customCardColor.withOpacity(0.18)],
          'border': _customCardColor,
          'accent': _customCardColor,
          'badgeBg': _customCardColor.withOpacity(0.18),
          'badgeText': _customCardColor,
          'textColor': isDark ? Colors.white : const Color(0xFF0F172A),
          'subTextColor': isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
        };
      case 'system_primary':
      default:
        // Harmonize 100% with App System Theme Primary Color!
        return {
          'bgGradient': isDark
              ? [const Color(0xFF161B22), const Color(0xFF0D1117)]
              : [Colors.white, const Color(0xFFF8FAFC)],
          'border': primaryColor.withOpacity(0.5),
          'accent': primaryColor,
          'badgeBg': primaryColor.withOpacity(0.12),
          'badgeText': primaryColor,
          'textColor': isDark ? Colors.white : const Color(0xFF0F172A),
          'subTextColor': isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    final Color bgColor = isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color borderColor = isDark ? const Color(0xFF30363D) : Colors.grey.shade300;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Master Navigation Header Bar
            _buildMasterHeader(isDark, primaryColor, textColor, subTextColor),
            const SizedBox(height: 24),

            // Responsive Layout: Split Screen on Desktop (42% Stage / 58% Form), Stacked on Mobile
            if (isWideScreen)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left 42%: Studio Stage Suspended Card Showcase with 3D Tilt & Image Downloader
                  Expanded(
                    flex: 42,
                    child: _buildStudioStageCanvas(isDark, primaryColor, textColor, subTextColor),
                  ),
                  const SizedBox(width: 28),
                  // Right 58%: Segmented Controls Progressive Form Editor
                  Expanded(
                    flex: 58,
                    child: _buildSegmentedFormEditor(isDark, primaryColor, cardBg, borderColor, textColor, subTextColor),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildStudioStageCanvas(isDark, primaryColor, textColor, subTextColor),
                  const SizedBox(height: 24),
                  _buildSegmentedFormEditor(isDark, primaryColor, cardBg, borderColor, textColor, subTextColor),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // --- MASTER NAVIGATION HEADER BAR ---
  Widget _buildMasterHeader(bool isDark, Color primaryColor, Color textColor, Color subTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.style_outlined, color: primaryColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  '個人帳號與名片設定',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _open3DTheaterModal,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.view_in_ar_rounded, size: 18),
              label: const Text('3D 劇院', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 2,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: Text(_isLoading ? '儲存中...' : '儲存變更', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ],
    );
  }

  // --- LEFT: STUDIO STAGE SUSPENDED CANVAS SHOWCASE WITH HD IMAGE EXPORT & 3D TILT ---
  Widget _buildStudioStageCanvas(bool isDark, Color primaryColor, Color textColor, Color subTextColor) {
    return Column(
      children: [
        // Minimal Stage Canvas Stage Box
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A26) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? const Color(0xFF222C3C) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Studio Stage Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox.shrink(),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isExportingImage ? null : _downloadCardAsImage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor.withOpacity(0.12),
                          foregroundColor: primaryColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: _isExportingImage
                            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor))
                            : const Icon(Icons.image_outlined, size: 16),
                        label: Text(_isExportingImage ? '產圖中...' : '下載高清名片 (PNG)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _isCardFlipped = !_isCardFlipped),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor.withOpacity(0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.flip_camera_android_rounded, size: 14),
                        label: Text(_isCardFlipped ? '正面 🎴' : '背面 🔄', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Interactive 3D Mouse Tilt Container with RepaintBoundary Key
              MouseRegion(
                onHover: (event) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    final size = renderBox.size;
                    final local = event.localPosition;
                    final dx = (local.dx / size.width) - 0.5;
                    final dy = (local.dy / size.height) - 0.5;
                    setState(() {
                      _tiltX = dy * 0.45;
                      _tiltY = -dx * 0.45;
                      _glareX = (dx + 0.5).clamp(0.0, 1.0);
                      _glareY = (dy + 0.5).clamp(0.0, 1.0);
                    });
                  }
                },
                onExit: (_) {
                  setState(() {
                    _tiltX = 0.0;
                    _tiltY = 0.0;
                    _glareX = 0.5;
                    _glareY = 0.5;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX(_tiltX)
                    ..rotateY(_tiltY),
                  transformAlignment: Alignment.center,
                  width: double.infinity,
                  child: ListenableBuilder(
                    listenable: _controllersListenable,
                    builder: (context, _) {
                      return RepaintBoundary(
                        key: _cardRenderKey,
                        child: _buildDynamicBusinessCard(isDark, primaryColor),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- DYNAMIC 3D BUSINESS CARD WITH SPECULAR GLARE, STRICT NULL PROTECTION & INLINE CLICK-TO-EDIT ---
  Widget _buildDynamicBusinessCard(bool isDark, Color primaryColor) {
    final theme = _getCardThemeConfig(isDark, primaryColor);
    final avatarProvider = _getAvatarProvider();
    final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : '您的姓名';
    final initialLetter = name.substring(0, 1);
    final company = _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : '保險經紀人公司';
    final jobTitle = _jobTitleController.text.trim().isNotEmpty ? _jobTitleController.text.trim() : '高級理財顧問';
    final phone = _phoneController.text.trim();
    final lineId = _lineIdController.text.trim();
    final email = _userEmail;
    final website = _websiteController.text.trim();
    final address = _addressController.text.trim();
    final bio = _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : '專業、誠信、客戶至上。為您與家庭提供全方位的保障與資產規劃服務。';

    final Color cardBorderColor = theme['border'];
    final Color cardAccentColor = theme['accent'];
    final Color cardTextColor = theme['textColor'];
    final Color cardSubColor = theme['subTextColor'];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme['bgGradient'],
        ),
        border: Border.all(color: cardBorderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: cardAccentColor.withOpacity(0.3),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isCardFlipped
                  ? _buildCardBackSide(cardTextColor, cardSubColor, cardAccentColor, theme, bio, website)
                  : _buildCardFrontSide(avatarProvider, initialLetter, name, jobTitle, company, phone, lineId, email, address, website, cardTextColor, cardSubColor, cardAccentColor, theme),
            ),
            // Dynamic Holographic Foil Overlay (Inspired by todo-tcg.vercel.app mouse-following foil shimmer spotlight!)
            if (_glareMode == 'tcg_rainbow')
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(_glareX * 2.0 - 1.0, _glareY * 2.0 - 1.0),
                        radius: 1.1,
                        colors: const [
                          Color(0x66FFFFFF),
                          Color(0x55FF0055),
                          Color(0x5500E5FF),
                          Color(0x55FFD700),
                          Color(0x4400FF66),
                          Color(0x00000000),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (_glareMode == 'metallic_tint')
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(_glareX * 2.0 - 1.0, _glareY * 2.0 - 1.0),
                        radius: 0.85,
                        colors: [
                          Colors.white.withOpacity(0.6),
                          cardAccentColor.withOpacity(0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Front Side of Card with Strict Empty Protection
  Widget _buildCardFrontSide(
    ImageProvider? avatarProvider,
    String initialLetter,
    String name,
    String jobTitle,
    String company,
    String phone,
    String lineId,
    String email,
    String address,
    String website,
    Color cardTextColor,
    Color cardSubColor,
    Color cardAccentColor,
    Map<String, dynamic> theme,
  ) {
    return Padding(
      key: const ValueKey('front'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Header Row (Clickable -> Tab 1 Business)
          InkWell(
            onTap: () => _focusInlineField(1, _companyFocus),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, color: cardAccentColor, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        company,
                        style: TextStyle(color: cardTextColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  // Professional Honor Title Chip (Dynamic Theme Color Adaptation, renders ONLY if non-empty!)
                  if (_honorTitle.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: cardAccentColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: cardAccentColor.withOpacity(0.4), blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        _honorTitle,
                        style: TextStyle(
                          color: (cardAccentColor.computeLuminance() > 0.6) ? const Color(0xFF0F172A) : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Avatar & Name Row (Clickable -> Tab 0 Basic)
          InkWell(
            onTap: () => _focusInlineField(0, _nameFocus),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(36),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cardAccentColor, width: 2),
                            boxShadow: [
                              BoxShadow(color: cardAccentColor.withOpacity(0.3), blurRadius: 8),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: cardAccentColor.withOpacity(0.15),
                            backgroundImage: avatarProvider,
                            child: avatarProvider == null
                                ? Text(
                                    initialLetter,
                                    style: TextStyle(color: cardAccentColor, fontSize: 28, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: cardAccentColor,
                            child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cardTextColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          jobTitle,
                          style: TextStyle(fontSize: 14, color: cardAccentColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Badges Row (MDRT, CFP...) (Clickable -> Tab 2 Badges)
          if (_selectedBadges.isNotEmpty)
            InkWell(
              onTap: () => setState(() => _activeTabIndex = 2),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _selectedBadges.map((badge) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme['badgeBg'],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cardAccentColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        '🏆 $badge',
                        style: TextStyle(color: theme['badgeText'], fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Quick Action Hub Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionHubBtn(Icons.phone_in_talk_rounded, '撥打電話', cardAccentColor, () {
                  final p = phone.isNotEmpty ? phone : '未設定電話';
                  CustomToast.show(context, '通話已連線至 $p', ToastType.success);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionHubBtn(Icons.chat_bubble_outline_rounded, '加 LINE', Colors.greenAccent, () {
                  final l = lineId.isNotEmpty ? lineId : '未設定 LINE ID';
                  CustomToast.show(context, 'LINE ID: $l 已開啟', ToastType.success);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionHubBtn(Icons.mail_outline_rounded, '發送 Email', Colors.amberAccent, () {
                  final e = email.isNotEmpty ? email : '未設定 Email';
                  CustomToast.show(context, '郵件連線至 $e', ToastType.success);
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Info Rows with STRICT EMPTY FIELD PROTECTION (Only show if non-empty!)
          if (phone.isNotEmpty)
            InkWell(
              onTap: () => _focusInlineField(0, _phoneFocus),
              child: _buildCardInfoRow(Icons.phone_android_rounded, phone, cardSubColor),
            ),
          if (lineId.isNotEmpty)
            InkWell(
              onTap: () => _focusInlineField(0, _lineIdFocus),
              child: _buildCardInfoRow(Icons.chat_rounded, 'LINE ID: $lineId', cardSubColor),
            ),
          if (email.isNotEmpty)
            _buildCardInfoRow(Icons.mail_outline_rounded, email, cardSubColor),
          if (address.isNotEmpty)
            InkWell(
              onTap: () => _focusInlineField(1, _addressFocus),
              child: _buildCardInfoRow(Icons.location_on_outlined, address, cardSubColor),
            ),
          if (website.isNotEmpty)
            InkWell(
              onTap: () => _focusInlineField(1, _websiteFocus),
              child: _buildCardInfoRow(Icons.web_rounded, website, cardSubColor),
            ),
        ],
      ),
    );
  }

  // Back Side of Card (Refined Brand Ornament & Motto)
  Widget _buildCardBackSide(
    Color cardTextColor,
    Color cardSubColor,
    Color cardAccentColor,
    Map<String, dynamic> theme,
    String bio,
    String website,
  ) {
    return Padding(
      key: const ValueKey('back'),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, color: cardAccentColor, size: 18),
                  const SizedBox(width: 6),
                  Text('保險客戶管理助手 • 專屬背板', style: TextStyle(color: cardAccentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
              Icon(Icons.qr_code_2_rounded, color: cardAccentColor, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => _focusInlineField(2, _bioFocus),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardAccentColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bio,
                style: TextStyle(color: cardTextColor, fontSize: 12, height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Real QR Code Image / Dynamic Scan Box (Only show if uploaded or LINE ID present)
          if (_qrCodeImageBytes != null || _currentQrCodeUrl.isNotEmpty || _lineIdController.text.trim().isNotEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: cardAccentColor.withOpacity(0.3), blurRadius: 8)],
                ),
                child: Column(
                  children: [
                    if (_qrCodeImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_qrCodeImageBytes!, width: 90, height: 90, fit: BoxFit.cover),
                      )
                    else
                      Icon(Icons.qr_code_2_rounded, size: 68, color: Colors.black87),
                    const SizedBox(height: 4),
                    Text(
                      _lineIdController.text.trim().isNotEmpty
                          ? '掃碼加 LINE (${_lineIdController.text.trim()})'
                          : '掃碼連線服務據點',
                      style: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionHubBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3D IMMERSIVE FULLSCREEN THEATER MODAL ---
  void _open3DTheaterModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = AppSettings.instance.primaryColor;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                width: 600,
                height: 520,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withOpacity(0.9) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: primaryColor.withOpacity(0.4), width: 2),
                  boxShadow: [
                    BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 5),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.view_in_ar_rounded, color: primaryColor, size: 24),
                              const SizedBox(width: 10),
                              Text(
                                '3D 劇院沉浸式預覽舞台',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          '滑鼠懸停傾斜與光影極致體驗中...',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: 380,
                        child: _buildDynamicBusinessCard(isDark, primaryColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- RIGHT: SEGMENTED CONTROLS PROGRESSIVE FORM EDITOR (58%) ---
  Widget _buildSegmentedFormEditor(
    bool isDark,
    Color primaryColor,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subTextColor,
  ) {
    final List<Map<String, dynamic>> tabs = [
      {'icon': Icons.person_outline_rounded, 'label': '👤 基本資料'},
      {'icon': Icons.business_center_outlined, 'label': '💼 商務資歷'},
      {'icon': Icons.card_membership_rounded, 'label': '🏆 榮譽頭銜'},
      {'icon': Icons.shield_outlined, 'label': '🔒 帳號安全'},
    ];

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Control Tabs Header
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: List.generate(tabs.length, (idx) {
                final isSelected = _activeTabIndex == idx;
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_activeTabIndex != idx) {
                        setState(() {
                          _activeTabIndex = idx;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          tabs[idx]['label'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? primaryColor : subTextColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Persistent IndexedStack Container for 0ms Instant Zero-Lag Tab Switching!
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IndexedStack(
              index: _activeTabIndex,
              children: [
                _buildTab0BasicInfo(isDark, primaryColor, textColor, subTextColor),
                _buildTab1BusinessDetails(isDark, primaryColor, textColor, subTextColor),
                _buildTab2BadgesAndTheme(isDark, primaryColor, textColor, subTextColor),
                _buildTab3SecurityAndPassword(isDark, primaryColor, textColor, subTextColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 0: BASIC INFO ---
  Widget _buildTab0BasicInfo(bool isDark, Color primaryColor, Color textColor, Color subTextColor) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('個人基本與聯絡資料', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 4),
        Text('修改內容將毫秒級同步反映於左側電子名片', style: TextStyle(fontSize: 12, color: subTextColor)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          focusNode: _nameFocus,
          style: TextStyle(color: textColor),
          decoration: _buildInputDeco(context.l10n('profile_name'), Icons.badge_outlined, isDark, primaryColor, subTextColor),
          validator: (val) => val == null || val.trim().isEmpty ? '請輸入您的姓名' : null,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                style: TextStyle(color: textColor),
                keyboardType: TextInputType.phone,
                decoration: _buildInputDeco(context.l10n('profile_phone'), Icons.phone_android_rounded, isDark, primaryColor, subTextColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lineIdController,
                focusNode: _lineIdFocus,
                style: TextStyle(color: textColor),
                decoration: _buildInputDeco('LINE ID (選填)', Icons.chat_bubble_outline_rounded, isDark, primaryColor, subTextColor, hintText: '例: lobo_insurance'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          enabled: false,
          initialValue: _userEmail,
          style: TextStyle(color: subTextColor),
          decoration: _buildInputDeco('Email 信箱 (登入帳號)', Icons.mail_outline_rounded, isDark, primaryColor, subTextColor),
        ),
      ],
    );
  }

  // --- TAB 1: BUSINESS DETAILS ---
  Widget _buildTab1BusinessDetails(bool isDark, Color primaryColor, Color textColor, Color subTextColor) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('商務與公司聯絡資訊', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 4),
        Text('提供客戶完整的服務據點與網站連結', style: TextStyle(fontSize: 12, color: subTextColor)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _companyController,
                focusNode: _companyFocus,
                style: TextStyle(color: textColor),
                decoration: _buildInputDeco(context.l10n('profile_company'), Icons.corporate_fare_outlined, isDark, primaryColor, subTextColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _jobTitleController,
                focusNode: _jobTitleFocus,
                style: TextStyle(color: textColor),
                decoration: _buildInputDeco(context.l10n('profile_job_title'), Icons.work_outline_rounded, isDark, primaryColor, subTextColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _websiteController,
          focusNode: _websiteFocus,
          style: TextStyle(color: textColor),
          decoration: _buildInputDeco('個人/公司網站 (選填)', Icons.web_rounded, isDark, primaryColor, subTextColor, hintText: 'www.mcdonalds.com'),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocus,
          maxLines: 2,
          style: TextStyle(color: textColor),
          decoration: _buildInputDeco('服務據點 / 通訊地址 (選填)', Icons.location_on_outlined, isDark, primaryColor, subTextColor),
        ),
      ],
    );
  }

  // --- TAB 2: BADGES, CUSTOM HONOR TITLE AND THEMES WITH FULL CRUD TAG MANAGEMENT ---
  Widget _buildTab2BadgesAndTheme(bool isDark, Color primaryColor, Color textColor, Color subTextColor) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('顧問榮譽頭銜與專業認證標籤管理', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 4),
        Text('可自由新增、選擇與刪除展現於名片上之榮譽頭銜與專業認證標籤', style: TextStyle(fontSize: 12, color: subTextColor)),
        const SizedBox(height: 16),

        // 1. Honor Title CRUD
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1. 榮譽頭銜標籤 (選擇 / 刪除)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
            Text('目前共 ${_availableHonorTitles.length} 項', style: TextStyle(fontSize: 11, color: subTextColor)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Option 0: Don't display any honor title (Deselect / 不顯示)
            ChoiceChip(
              selected: _honorTitle.isEmpty,
              label: const Text('🚫 不顯示頭銜 (空白)'),
              checkmarkColor: primaryColor.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : Colors.white,
              selectedColor: primaryColor,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _honorTitle.isEmpty
                    ? (primaryColor.computeLuminance() > 0.45 ? const Color(0xFF0F172A) : Colors.white)
                    : textColor,
              ),
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _honorTitle = '';
                  });
                }
              },
            ),
            ..._availableHonorTitles.map((honor) {
              final isSelected = _honorTitle == honor;
              final isBright = primaryColor.computeLuminance() > 0.45;
              final activeFontColor = isBright ? const Color(0xFF0F172A) : Colors.white;

              return InputChip(
                selected: isSelected,
                label: Text(honor),
                selectedColor: primaryColor,
                checkmarkColor: activeFontColor,
                deleteIcon: const Icon(Icons.cancel_rounded, size: 14),
                deleteIconColor: isSelected ? activeFontColor.withOpacity(0.8) : subTextColor,
                onDeleted: () {
                  setState(() {
                    _availableHonorTitles.remove(honor);
                    if (_honorTitle == honor) {
                      _honorTitle = '';
                    }
                  });
                  CustomToast.show(context, '已刪除頭銜標籤：$honor', ToastType.warning);
                },
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? activeFontColor : textColor,
                ),
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                onPressed: () {
                  setState(() {
                    _honorTitle = honor;
                  });
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customHonorController,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: _buildInputDeco('新增自訂榮譽頭銜 (如: 首席理財大師)', Icons.add_moderator_rounded, isDark, primaryColor, subTextColor),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                final txt = _customHonorController.text.trim();
                if (txt.isNotEmpty) {
                  if (!_availableHonorTitles.contains(txt)) {
                    setState(() {
                      _availableHonorTitles.add(txt);
                      _honorTitle = txt;
                      _customHonorController.clear();
                    });
                    CustomToast.show(context, '已新增並套用頭銜：$txt', ToastType.success);
                  } else {
                    CustomToast.show(context, '此頭銜已存在！', ToastType.warning);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新增頭銜', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Professional Certification Badges CRUD
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('2. 專業證照與榮譽徽章 (多選 / 新增 / 刪除)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
            Text('已選 ${_selectedBadges.length} / 共 ${_availableBadges.length} 項', style: TextStyle(fontSize: 11, color: subTextColor)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableBadges.map((badge) {
            final isSelected = _selectedBadges.contains(badge);
            final isPrimaryBright = primaryColor.computeLuminance() > 0.45;
            final selectedFontColor = isPrimaryBright ? const Color(0xFF0F172A) : Colors.white;

            return InputChip(
              selected: isSelected,
              label: Text(badge),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedBadges.add(badge);
                  } else {
                    _selectedBadges.remove(badge);
                  }
                });
              },
            );
          }).toList(),
        ),
        // Section 2 Dedicated Add Badge TextField & Button
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customBadgeController,
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: _buildInputDeco('新增自訂證照/榮譽徽章 (如: 美國百萬圓桌)', Icons.verified_outlined, isDark, primaryColor, subTextColor),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                final txt = _customBadgeController.text.trim();
                if (txt.isNotEmpty) {
                  if (!_availableBadges.contains(txt)) {
                    setState(() {
                      _availableBadges.add(txt);
                      _selectedBadges.add(txt);
                      _customBadgeController.clear();
                    });
                    CustomToast.show(context, '已新增並勾選證照：$txt', ToastType.success);
                  } else {
                    CustomToast.show(context, '此證照標籤已存在！', ToastType.warning);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('新增證照', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 3. Theme Presets & Custom Color Palette
        Text('3. 選擇名片質感主題配色與自訂自由色盤', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildThemePresetChip('system_primary', '全站主題 (預設)', primaryColor, isDark),
            _buildThemePresetChip('cyan_slate', '極致藍曜', const Color(0xFF0EA5E9), isDark),
            _buildThemePresetChip('dark_gold', '尊爵黑金', const Color(0xFFEAB308), isDark),
            _buildThemePresetChip('emerald', '活力翡翠', const Color(0xFF10B981), isDark),
            _buildThemePresetChip('custom_color', '🎨 自訂自由色盤', _customCardColor, isDark),
          ],
        ),
        if (_selectedTheme == 'custom_color') ...[
          const SizedBox(height: 12),
          Text('點選色票客製名片主色：', style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildColorSwatch(const Color(0xFF8B5CF6), '紫羅蘭'),
              _buildColorSwatch(const Color(0xFFEC4899), '玫瑰粉紅'),
              _buildColorSwatch(const Color(0xFF3B82F6), '皇家寶藍'),
              _buildColorSwatch(const Color(0xFFF97316), '活力珊瑚橘'),
              _buildColorSwatch(const Color(0xFF06B6D4), '極光靛青'),
              _buildColorSwatch(const Color(0xFF64748B), '高雅石墨灰'),
              _buildColorSwatch(const Color(0xFF14B8A6), '湖水碧綠'),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // 4. Glare Mode Selector (Default: 🚫 無光澤)
        Text('4. 選擇 3D 名片雷射光澤模式', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildGlareChip('none', '🚫 無光澤 (預設純淨)', isDark, primaryColor),
            _buildGlareChip('tcg_rainbow', '🌈 TCG 炫彩彩虹雷射', isDark, primaryColor),
            _buildGlareChip('metallic_tint', '✨ 同色系金屬琉光', isDark, primaryColor),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _bioController,
          focusNode: _bioFocus,
          maxLines: 3,
          style: TextStyle(color: textColor),
          decoration: _buildInputDeco('服務理念與個人簡介', Icons.info_outline_rounded, isDark, primaryColor, subTextColor),
        ),
        const SizedBox(height: 14),

        // QR Code Real Upload Entrance
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickQrCodeImage,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(
                _qrCodeImageBytes != null ? '更換 QR Code 圖片' : '📷 上傳個人 / LINE QR Code 圖片 (選填)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            if (_qrCodeImageBytes != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _qrCodeImageBytes = null),
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                tooltip: '移除 QR Code',
              ),
            ],
          ],
        ),
      ],
    );
  }

  // --- TAB 3: SECURITY AND PASSWORD ---
  Widget _buildTab3SecurityAndPassword(bool isDark, Color primaryColor, Color textColor, Color subTextColor) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('變更密碼 / 安全設定', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 4),
        Text('定期更新密碼以確保您的客戶 CRM 與保單資料安全', style: TextStyle(fontSize: 12, color: subTextColor)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 36, color: primaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('帳號雙層安全防護', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('您可以點擊右側按鈕設定並更新您的個人密碼', style: TextStyle(color: subTextColor, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const ResetPasswordDialog(),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.lock_reset_rounded, size: 16),
                label: const Text('重設密碼', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemePresetChip(String key, String name, Color color, bool isDark) {
    final isSelected = _selectedTheme == key;
    final isBright = color.computeLuminance() > 0.45;
    final activeFontColor = isBright ? const Color(0xFF0F172A) : Colors.white;

    return ChoiceChip(
      selected: isSelected,
      label: Text(name),
      checkmarkColor: activeFontColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: isSelected ? activeFontColor : (isDark ? Colors.white70 : Colors.black87),
      ),
      selectedColor: color,
      avatar: CircleAvatar(backgroundColor: isSelected ? activeFontColor : color, radius: 6),
      onSelected: (val) {
        if (val) {
          setState(() {
            _selectedTheme = key;
          });
        }
      },
    );
  }

  Widget _buildGlareChip(String key, String name, bool isDark, Color primaryColor) {
    final isSelected = _glareMode == key;
    final isBright = primaryColor.computeLuminance() > 0.45;
    final activeFontColor = isBright ? const Color(0xFF0F172A) : Colors.white;

    return ChoiceChip(
      selected: isSelected,
      label: Text(name),
      checkmarkColor: activeFontColor,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: isSelected ? activeFontColor : (isDark ? Colors.white70 : Colors.black87),
      ),
      selectedColor: primaryColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      onSelected: (val) {
        if (val) {
          setState(() {
            _glareMode = key;
          });
        }
      },
    );
  }

  InputDecoration _buildInputDeco(
    String label,
    IconData icon,
    bool isDark,
    Color primaryColor,
    Color subTextColor, {
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: subTextColor, fontSize: 12),
      hintText: hintText,
      hintStyle: TextStyle(color: subTextColor.withOpacity(0.5), fontSize: 12),
      prefixIcon: Icon(icon, color: primaryColor, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
    );
  }

  Future<void> _pickImage() async {
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
  }

  Future<void> _pickQrCodeImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _qrCodeImageBytes = bytes;
        });
        CustomToast.show(context, '🟢 已成功選擇 QR Code 圖片！', ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '選擇 QR Code 圖片失敗: $e', ToastType.error);
      }
    }
  }

  Widget _buildColorSwatch(Color color, String label) {
    final isSelected = _selectedTheme == 'custom_color' && _customCardColor == color;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTheme = 'custom_color';
          _customCardColor = color;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(backgroundColor: color, radius: 6),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

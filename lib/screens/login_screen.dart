import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models/user_role.dart';
import '../widgets/forgot_password_dialog.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/custom_toast.dart';
import 'home_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _teamCodeController = TextEditingController(text: 'TAIPEI-01');
  UserRole _selectedRole = UserRole.agent;
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUrlErrors();
    });
  }

  void _checkUrlErrors() {
    if (kIsWeb) {
      final uri = Uri.base;
      final error = uri.queryParameters['error'];
      final errorCode = uri.queryParameters['error_code'];

      if (errorCode == 'otp_expired' || (error != null && error.isNotEmpty)) {
        CustomToast.show(
          context,
          '⚠️ 驗證連結已過期或失效！若您收到了多封驗證信，請務必點擊「最新發出的那一封」，或在下方重試登入/發送。',
          ToastType.warning,
          actionLabel: '重發驗證信',
          onActionPressed: () {
            setState(() {
              _isSignUp = false;
            });
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _teamCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (isOfflineMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('離線模式下無法註冊/登入。請填寫您的 .env 金鑰，或使用上方橫幅的「直接跳過登入」。'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      if (_isSignUp) {
        // Sign up
        String? redirectTo;
        if (kIsWeb) {
          final origin = Uri.base.origin;
          redirectTo = (origin.contains('localhost') && !origin.contains(':8080'))
              ? 'http://localhost:8080'
              : origin;
        } else {
          redirectTo = 'http://localhost:8080';
        }

        final prefs = await SharedPreferences.getInstance();
        final bool enableAutoApproval = prefs.getBool('enable_auto_approval') ?? false;
        // Default to active during development so users do not get blocked by approval dialogs
        final String status = enableAutoApproval ? 'active' : 'pending';

        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          emailRedirectTo: redirectTo,
          data: {
            'full_name': _nameController.text.trim(),
            'role': UserRole.agent.value, // Public registration is strictly locked to 'agent'
            'team_code': _teamCodeController.text.trim(),
            'team_name': '國泰台北第一通訊處',
            'status': status,
          },
        );

        // Precise check: Supabase returns user with empty identities list if email is already registered
        if (response.user != null && (response.user!.identities?.isEmpty ?? false)) {
          if (mounted) {
            CustomToast.show(
              context,
              '⚠️ 此 Email (${_emailController.text.trim()}) 已經被註冊過囉！已為您帶入帳號並切換至登入模式。',
              ToastType.warning,
            );
            setState(() {
              _isSignUp = false;
            });
          }
          return;
        }

        // Ensure profiles table has explicit profile record for new user
        if (response.user != null) {
          try {
            await supabase.from('profiles').upsert({
              'id': response.user!.id,
              'email': _emailController.text.trim(),
              'full_name': _nameController.text.trim(),
              'role': UserRole.agent.value,
              'status': status,
              'team_name': '國泰台北第一通訊處',
            });
          } catch (_) {}
        }

        if (mounted) {
          if (status == 'pending') {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('📋 帳號提交成功（待審核）'),
                content: Text(
                  '您的帳號已成功註冊！\n'
                  '申請通訊處：國泰台北第一通訊處 (${_teamCodeController.text.trim()})\n'
                  '申請身分：${UserRole.agent.labelZh}\n\n'
                  '目前為企業嚴格模式，需等待同通訊處團隊主管審核開通後方可登入使用。',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('我知道了'),
                  ),
                ],
              ),
            );
          } else if (response.session == null) {
            // Email confirmation required by Supabase project
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('✉️ 帳號建立成功 (需驗證 Email)'),
                content: Text(
                  '您的帳號已成功建立！\n'
                  '驗證信已寄送至：${_emailController.text.trim()}\n\n'
                  '📌 登入指引：\n'
                  '1. 請至 Email 收件匣點擊驗證連結。\n'
                  '2. 💡【重要提示】若您目前使用「無痕模式」，點擊 Email 連結後請將開啟的網址「複製並貼回此無痕視窗」，驗證方可生效。\n'
                  '3. 完成驗證後，點擊下方「返回登入」即可直接輸入密碼登入！',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _isSignUp = false;
                      });
                    },
                    child: const Text('返回登入'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00ADB5),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final url = Uri.parse('https://mail.google.com/');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('開啟信箱'),
                  ),
                ],
              ),
            );
          } else {
            CustomToast.show(
              context,
              '註冊成功！帳號已開通並自動登入。',
              ToastType.success,
            );
          }
        }
      } else {
        // Sign in
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          CustomToast.show(context, '登入成功！歡迎回來', ToastType.success);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        String msg = e.message;
        if (msg.contains('User already registered') || msg.contains('already exists')) {
          msg = '此 Email 已被註冊！請直接切換至「業務員登入」或點擊「忘記密碼」。';
        } else if (msg.contains('Password should be at least')) {
          msg = '密碼長度不足，請輸入至少 6 位字元。';
        } else if (msg.contains('Invalid login credentials')) {
          msg = '帳號尚未註冊或密碼錯誤，請重新確認。';
        } else if (msg.contains('Email not confirmed')) {
          CustomToast.show(
            context,
            '電子信箱尚未完成驗證！請至 Email 收件匣點擊「最新的」驗證連結。',
            ToastType.warning,
            actionLabel: '重發驗證信',
            onActionPressed: () async {
              final email = _emailController.text.trim();
              if (email.isEmpty) {
                CustomToast.show(context, '請先在上方填寫您的 Email 帳號', ToastType.warning);
                return;
              }
              try {
                await Supabase.instance.client.auth.resend(
                  type: OtpType.signup,
                  email: email,
                );
                if (mounted) {
                  CustomToast.show(context, '全新驗證信已寄出！請至 Email 收件匣點擊最新信件。', ToastType.success);
                }
              } catch (resendErr) {
                if (mounted) {
                  CustomToast.show(context, '重發失敗: $resendErr', ToastType.error);
                }
              }
            },
          );
          return;
        }
        CustomToast.show(context, msg, ToastType.error);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '操作失敗: $e', ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (isOfflineMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('離線模式下無法使用 Google 登入。請使用上方橫幅的「直接跳過登入」。'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      String? redirectTo;
      if (kIsWeb) {
        final origin = Uri.base.origin;
        redirectTo = (origin.contains('localhost') && !origin.contains(':8080'))
            ? 'http://localhost:8080'
            : origin;
      } else {
        redirectTo = 'http://localhost:8080';
      }

      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        queryParams: {
          'prompt': 'select_account',
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google 登入發起失敗: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _appendEmailDomain(String domain) {
    final currentText = _emailController.text.trim();
    if (currentText.isEmpty) {
      _emailController.text = domain;
    } else if (currentText.contains('@')) {
      final prefix = currentText.split('@')[0];
      _emailController.text = '$prefix$domain';
    } else {
      _emailController.text = '$currentText$domain';
    }
    _emailController.selection = TextSelection.fromPosition(
      TextPosition(offset: _emailController.text.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // Background subtle gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F172A), // Slate 900
                  Color(0xFF020617), // Slate 950
                ],
              ),
            ),
          ),
          
          // Outer scroll view for keyboard resizing
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // App Icon or Logo Placeholder
                      const Icon(
                        Icons.shield_outlined,
                        size: 64,
                        color: Color(0xFF00ADB5),
                      ),
                      const SizedBox(height: 16),
                      
                      // App Title
                      Text(
                        'insurance_helper',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // App Subtitle
                      Text(
                        '智慧保險 CRM & AI 語意跟進排程',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Form Card
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(
                            color: Color(0xFF1E293B), // Border color Slate 800
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _isSignUp ? '建立業務帳號' : '業務員登入',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              
                              // Name Input (Only shown on Sign Up)
                              if (_isSignUp) ...[
                                TextFormField(
                                  controller: _nameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: '姓名 (綽號就好惹~)',
                                    hintText: '例：王大明',
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return '請輸入姓名';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Email Input Label & Quick Domain Selector
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '電子信箱',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: _appendEmailDomain,
                                    tooltip: '快速套用常用電子信箱網域',
                                    offset: const Offset(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    color: const Color(0xFF1E293B),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00ADB5).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFF00ADB5).withOpacity(0.3),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.alternate_email_rounded, size: 14, color: Color(0xFF00ADB5)),
                                          SizedBox(width: 4),
                                          Text(
                                            '常用信箱網域 ▾',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF00ADB5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                        value: '@gmail.com',
                                        child: Row(
                                          children: [
                                            Text('🌐 ', style: TextStyle(fontSize: 14)),
                                            Text('Google ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                            Text('(@gmail.com)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: '@yahoo.com.tw',
                                        child: Row(
                                          children: [
                                            Text('✉️ ', style: TextStyle(fontSize: 14)),
                                            Text('Yahoo 台灣 ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                            Text('(@yahoo.com.tw)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: '@outlook.com',
                                        child: Row(
                                          children: [
                                            Text('💼 ', style: TextStyle(fontSize: 14)),
                                            Text('Outlook / Hotmail ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                            Text('(@outlook.com)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: '@icloud.com',
                                        child: Row(
                                          children: [
                                            Text('🍏 ', style: TextStyle(fontSize: 14)),
                                            Text('Apple iCloud ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                            Text('(@icloud.com)', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Email Input
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  hintText: '請輸入 Email 帳號',
                                  prefixIcon: Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return '請輸入 Email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                    return '請輸入有效的 Email 格式';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Password Input
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isLoading) {
                                    _handleSubmit();
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: '密碼',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '請輸入密碼';
                                  }
                                  if (value.length < 6) {
                                    return '密碼長度需至少 6 個字元';
                                  }
                                  return null;
                                },
                              ),
                              if (!_isSignUp) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => ForgotPasswordDialog(
                                          initialEmail: _emailController.text.trim(),
                                        ),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      '忘記密碼？',
                                      style: TextStyle(
                                        color: Color(0xFF00ADB5),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              
                              // Submit Button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ADB5),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(_isSignUp ? '註冊帳號' : '登入'),
                              ),
                              const SizedBox(height: 16),
                              
                              // Divider
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.white24)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      '或使用第三方帳號',
                                      style: TextStyle(fontSize: 12, color: Colors.white54),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Colors.white24)),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Google Sign-In Button
                              GoogleStyleSignInButton(
                                onPressed: _handleGoogleSignIn,
                                label: '使用 Google 繼續',
                                isLoading: _isLoading,
                              ),
                              const SizedBox(height: 12),
                              
                              // Toggle Sign In / Sign Up
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isSignUp = !_isSignUp;
                                    if (_isSignUp) {
                                      if (_teamCodeController.text.trim().isEmpty) {
                                        _teamCodeController.text = 'TAIPEI-01';
                                      }
                                      // Removed auto-name filling from email prefix
                                    }
                                  });
                                },
                                child: Text(
                                  _isSignUp ? '已有帳號？返回登入' : '沒有帳號？立即註冊一個',
                                  style: const TextStyle(
                                    color: Color(0xFF00ADB5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: const Color(0xFF00ADB5).withOpacity(0.4)),
                                  foregroundColor: const Color(0xFF00ADB5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                                  );
                                },
                                icon: const Icon(Icons.speed_rounded, size: 16),
                                label: const Text('🚀 快速進入系統預覽與測試模式', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Offline Preview Mode Banner at top
          if (isOfflineMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.amber.shade900.withOpacity(0.95),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '⚠️ 離線預覽模式已啟用 ($offlineReason)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const HomeScreen()),
                            );
                          },
                          child: const Text(
                            '直接跳過登入',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../widgets/custom_toast.dart';
import 'login_screen.dart';

class PendingApprovalScreen extends StatefulWidget {
  final String userEmail;
  final VoidCallback? onRefreshStatus;

  const PendingApprovalScreen({
    super.key,
    required this.userEmail,
    this.onRefreshStatus,
  });

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isChecking = false;

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    try {
      if (isOfflineMode) {
        CustomToast.show(context, '離線模式下無連線審核數據。', ToastType.warning);
        return;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('status')
            .eq('id', user.id)
            .maybeSingle();

        final status = data?['status'] as String? ?? 'pending';
        if (mounted) {
          if (status == 'active') {
            CustomToast.show(context, '🎉 您的帳號已成功獲准開通！', ToastType.success);
            widget.onRefreshStatus?.call();
          } else {
            CustomToast.show(context, '📋 帳號仍在審核中，請耐心地等待主管開通。', ToastType.warning);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '檢查失敗: $e', ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _handleSignOut() async {
    try {
      if (!isOfflineMode) {
        await Supabase.instance.client.auth.signOut();
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, '登出失敗: $e', ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pending_actions_rounded,
                        size: 40,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '📋 帳號審核中 (Pending Approval)',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '您的帳號已成功完成驗證！\n'
                      '登入帳號：${widget.userEmail}\n'
                      '申請通訊處：國泰台北第一通訊處 (TAIPEI-01)\n\n'
                      '基於通訊處個資與客戶資產安全防護，新註冊帳號需由「團隊主管」於戰情室進行身分確認並點擊開通後，方可登入存取系統。',
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isChecking ? null : _checkStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ADB5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _isChecking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        _isChecking ? '檢查中...' : '🔄 重新整理審核狀態',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _handleSignOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        '🚪 返回登入頁',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

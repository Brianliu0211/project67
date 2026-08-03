import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_settings.dart';
import '../services/app_localizations.dart';
import '../services/voice_transcription_service.dart';

enum RecordingState {
  recording,
  processing,
  success,
  warning,
  error,
}

class VoiceSchedulerOverlay extends StatefulWidget {
  const VoiceSchedulerOverlay({Key? key}) : super(key: key);

  @override
  State<VoiceSchedulerOverlay> createState() => _VoiceSchedulerOverlayState();
}

class _VoiceSchedulerOverlayState extends State<VoiceSchedulerOverlay> {
  final VoiceTranscriptionService _service = VoiceTranscriptionService();
  RecordingState _state = RecordingState.recording;
  bool _hasPermission = false;
  String? _errorMessage;
  int _seconds = 0;
  Timer? _timer;

  // 暫存解析結果與警告
  Map<String, dynamic>? _eventResult;
  List<String> _warningMessages = [];

  @override
  void initState() {
    super.initState();
    _checkPermissionAndStart();
  }

  Future<void> _checkPermissionAndStart() async {
    try {
      final hasPerm = await _service.hasPermission();
      if (hasPerm) {
        setState(() {
          _hasPermission = true;
          _state = RecordingState.recording;
          _eventResult = null;
          _warningMessages = [];
        });
        await _service.startRecording();
        _startTimer();
      } else {
        setState(() {
          _errorMessage = '麥克風權限被拒絕，請在系統設定中允許存取麥克風。';
          _state = RecordingState.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '無法啟動錄音: $e';
        _state = RecordingState.error;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds >= 60) {
        _finish();
      } else {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _cancel() async {
    _stopTimer();
    try {
      await _service.cancelRecording();
    } catch (e) {
      debugPrint('取消錄音失敗: $e');
    }
    if (mounted) {
      Navigator.of(context).pop(null);
    }
  }

  Future<void> _discardEvent() async {
    _stopTimer();
    setState(() {
      _state = RecordingState.processing;
    });

    if (_eventResult != null && _eventResult!['event'] != null) {
      final eventId = _eventResult!['event']['id'];
      if (eventId != null) {
        try {
          await Supabase.instance.client
              .from('schedule_events')
              .delete()
              .eq('id', eventId);
        } catch (e) {
          debugPrint('捨棄行程失敗: $e');
        }
      }
    }
    if (mounted) {
      Navigator.of(context).pop(null);
    }
  }

  Future<void> _finish() async {
    _stopTimer();
    setState(() {
      _state = RecordingState.processing;
    });

    try {
      final result = await _service.transcribeAndCreateEvent(DateTime.now());
      final status = result['status'] as String? ?? 'green';
      final warnings = List<String>.from(result['warning_messages'] ?? []);

      if (mounted) {
        _eventResult = result;
        _warningMessages = warnings;

        if (status == 'yellow') {
          setState(() {
            _state = RecordingState.warning;
          });
        } else {
          setState(() {
            _state = RecordingState.success;
          });
          // 綠燈 1.2 秒後自動關閉並回傳
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted) {
              Navigator.of(context).pop(result);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _state = RecordingState.error;
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _state = RecordingState.recording;
      _errorMessage = null;
      _eventResult = null;
      _warningMessages = [];
    });
    await _checkPermissionAndStart();
  }

  @override
  void dispose() {
    _stopTimer();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppSettings.instance.primaryColor;
    final themeMode = AppSettings.instance.themeMode;
    final bool isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    // 自適應遮罩顏色 (根據紅黃綠狀態渲染不同光暈)
    Color glowColor = Colors.transparent;
    if (_state == RecordingState.success) {
      glowColor = Colors.green.withOpacity(0.06);
    } else if (_state == RecordingState.warning) {
      glowColor = Colors.orange.withOpacity(0.06);
    } else if (_state == RecordingState.error) {
      glowColor = Colors.red.withOpacity(0.06);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. BackdropFilter 磨砂玻璃模糊 (sigma: 15)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // 2. 主題色調與狀態半透明墨色層
          Positioned.fill(
            child: Stack(
              children: [
                // 底色墨色層
                Container(
                  color: isDark
                      ? Colors.black.withOpacity(0.65)
                      : Colors.white.withOpacity(0.8),
                ),
                // 主題色混入層
                Container(
                  color: primaryColor.withOpacity(isDark ? 0.08 : 0.05),
                ),
                // 狀態光暈疊加層
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: glowColor,
                ),
              ],
            ),
          ),
          // 3. UI 內容層
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // 中央顯示區
                  _buildCentralContent(primaryColor, textColor, subTextColor),
                  const Spacer(flex: 3),
                  // 底部按鈕區
                  _buildBottomControls(primaryColor, textColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCentralContent(Color primaryColor, Color textColor, Color subTextColor) {
    switch (_state) {
      case RecordingState.recording:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 錄音波動動畫與麥克風
            Stack(
              alignment: Alignment.center,
              children: [
                PulseCircle(delay: 0.0, color: primaryColor),
                PulseCircle(delay: 1.0, color: primaryColor),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              _formatDuration(_seconds),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                context.l10n('voice_overlay_listening'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n('voice_overlay_listening'),
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
              ),
            ),
          ],
        );
      case RecordingState.processing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                strokeWidth: 6,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              context.l10n('voice_overlay_analyzing'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                context.l10n('voice_overlay_analyzing'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subTextColor,
                ),
              ),
            ),
          ],
        );
      case RecordingState.success: // 🟢 綠燈 UI
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const PulseCircle(delay: 0.0, color: Colors.green),
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent,
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              context.l10n('voice_overlay_success'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                '已完美建立行程，即將為您刷新行事曆！',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: subTextColor,
                ),
              ),
            ),
          ],
        );
      case RecordingState.warning: // 🟡 黃燈 UI
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange, width: 2),
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.orange,
                size: 54,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '行程已建立，但資訊有所遺漏',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _warningMessages.map((warning) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚠️ ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            warning,
                            style: TextStyle(
                              fontSize: 14,
                              color: textColor.withOpacity(0.9),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      case RecordingState.error: // 🔴 紅燈 UI
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.1),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 64,
              ),
            ),
            const SizedBox(height: 48),
            Text(
              '解析失敗',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _errorMessage ?? '未知的錯誤，請再試一次。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.redAccent,
                  height: 1.4,
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildBottomControls(Color primaryColor, Color textColor) {
    final isError = _state == RecordingState.error;
    final isWarning = _state == RecordingState.warning;
    final isProcessing = _state == RecordingState.processing;
    final isSuccess = _state == RecordingState.success;

    // 綠燈成功狀態下不需顯示控制按鈕
    if (isSuccess) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 取消 / 捨棄行程
        ElevatedButton(
          onPressed: isProcessing ? null : (isWarning ? _discardEvent : _cancel),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: isWarning ? Colors.redAccent : textColor,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(
                color: isWarning ? Colors.redAccent.withOpacity(0.4) : textColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
          ),
          child: Text(
            isError
                ? context.l10n('close')
                : isWarning
                    ? context.l10n('discard_event')
                    : context.l10n('cancel'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        // 完成 / 重新錄音 / 手動調整
        ElevatedButton(
          onPressed: isProcessing ? null : (isError ? _retry : (isWarning ? () => Navigator.of(context).pop(_eventResult) : _finish)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isError ? Colors.redAccent : (isWarning ? Colors.orange : primaryColor),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: (isError ? Colors.redAccent : (isWarning ? Colors.orange : primaryColor)).withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: Text(
            isError
                ? context.l10n('re_record')
                : isWarning
                    ? context.l10n('manual_adjust')
                    : context.l10n('done'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// 脈衝波紋同心圓組件
class PulseCircle extends StatefulWidget {
  final double delay;
  final Color color;
  const PulseCircle({Key? key, required this.delay, required this.color}) : super(key: key);

  @override
  State<PulseCircle> createState() => _PulseCircleState();
}

class _PulseCircleState extends State<PulseCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) {
        _controller.repeat();
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

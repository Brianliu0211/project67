import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_transcription_service.dart';

/// 語音錄音 UI 元件
///
/// 提供完整的錄音 → AI 轉錄流程 UI，包含：
/// - 待機模式（顯示「錄音」按鈕）
/// - 錄音中（脈衝動畫 + 計時器 + 停止/取消按鈕）
/// - 轉錄中（Loading 指示器）
/// - 錯誤狀態（自動 4 秒後復原）
///
/// 轉錄完成後，透過 [onTranscribed] 回調將文字傳回父 Widget。
///
/// 使用範例：
/// ```dart
/// VoiceRecorderWidget(
///   primaryColor: Colors.teal,
///   isDark: true,
///   onTranscribed: (text) {
///     notesController.text += '\n$text';
///   },
/// )
/// ```
class VoiceRecorderWidget extends StatefulWidget {
  final Color primaryColor;
  final bool isDark;
  final void Function(String text) onTranscribed;

  const VoiceRecorderWidget({
    super.key,
    required this.primaryColor,
    required this.isDark,
    required this.onTranscribed,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

enum _RecorderState { idle, recording, transcribing, error }

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  final _service = VoiceTranscriptionService();
  _RecorderState _state = _RecorderState.idle;
  int _recordingSeconds = 0;
  String _errorMessage = '';
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const int _maxRecordingSeconds = 120; // 最長 2 分鐘

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _service.dispose();
    super.dispose();
  }

  // ─── Timer Helpers ───────────────────────────────────────────

  void _startTimer() {
    _recordingSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordingSeconds++);
      if (_recordingSeconds >= _maxRecordingSeconds) {
        _stopAndTranscribe();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ─── Actions ─────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      await _service.startRecording();
      if (!mounted) return;
      setState(() => _state = _RecorderState.recording);
      _pulseController.repeat(reverse: true);
      _startTimer();
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _stopAndTranscribe() async {
    _stopTimer();
    _pulseController.stop();
    _pulseController.reset();
    if (!mounted) return;
    setState(() => _state = _RecorderState.transcribing);

    try {
      final transcript = await _service.stopAndTranscribe();
      if (!mounted) return;
      setState(() => _state = _RecorderState.idle);
      widget.onTranscribed(transcript);
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _cancelRecording() async {
    _stopTimer();
    _pulseController.stop();
    _pulseController.reset();
    await _service.cancelRecording();
    if (mounted) setState(() => _state = _RecorderState.idle);
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _state = _RecorderState.error;
      _errorMessage = message;
    });
    // 4 秒後自動回到待機狀態
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _state == _RecorderState.error) {
        setState(() => _state = _RecorderState.idle);
      }
    });
  }

  // ─── Formatting ──────────────────────────────────────────────

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor;
    final isDark = widget.isDark;

    // 決定容器背景和邊框顏色
    final Color bgColor;
    final Color borderColor;
    switch (_state) {
      case _RecorderState.recording:
        bgColor = Colors.red.withValues(alpha: isDark ? 0.12 : 0.07);
        borderColor = Colors.red.withValues(alpha: 0.45);
        break;
      case _RecorderState.transcribing:
        bgColor = primaryColor.withValues(alpha: isDark ? 0.12 : 0.06);
        borderColor = primaryColor.withValues(alpha: 0.35);
        break;
      case _RecorderState.error:
        bgColor = Colors.orange.withValues(alpha: isDark ? 0.12 : 0.06);
        borderColor = Colors.orange.withValues(alpha: 0.45);
        break;
      case _RecorderState.idle:
        bgColor = primaryColor.withValues(alpha: isDark ? 0.10 : 0.05);
        borderColor = primaryColor.withValues(alpha: 0.22);
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: _buildContent(primaryColor, isDark),
    );
  }

  Widget _buildContent(Color primaryColor, bool isDark) {
    switch (_state) {
      case _RecorderState.idle:
        return _buildIdleUI(primaryColor, isDark);
      case _RecorderState.recording:
        return _buildRecordingUI(isDark);
      case _RecorderState.transcribing:
        return _buildTranscribingUI(primaryColor, isDark);
      case _RecorderState.error:
        return _buildErrorUI(isDark);
    }
  }

  /// 待機 UI
  Widget _buildIdleUI(Color primaryColor, bool isDark) {
    return Row(
      children: [
        Icon(Icons.mic_outlined, color: primaryColor, size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '點擊錄音，AI 自動轉為文字備註',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _RecordButton(
          color: primaryColor,
          label: '錄音',
          icon: Icons.fiber_manual_record,
          onTap: _startRecording,
        ),
      ],
    );
  }

  /// 錄音中 UI（含脈衝動畫與計時器）
  Widget _buildRecordingUI(bool isDark) {
    return Row(
      children: [
        // 脈衝紅點
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 計時器
        Text(
          '錄音中  ${_formatDuration(_recordingSeconds)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.red.shade700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const Spacer(),
        // 取消按鈕
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black38,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 完成按鈕
        _RecordButton(
          color: Colors.red.shade600,
          label: '完成',
          icon: Icons.stop_rounded,
          onTap: _stopAndTranscribe,
        ),
      ],
    );
  }

  /// 轉錄中 UI
  Widget _buildTranscribingUI(Color primaryColor, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'AI 轉錄中，請稍候...',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black45,
          ),
        ),
      ],
    );
  }

  /// 錯誤 UI
  Widget _buildErrorUI(bool isDark) {
    return Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.orange,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Helper Widget ────────────────────────────────────────────

/// 錄音/停止按鈕（共用樣式）
class _RecordButton extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _RecordButton({
    required this.color,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

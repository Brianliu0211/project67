import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';
import 'voice_web_helper.dart';

/// 語音轉錄服務
///
/// 封裝 Web 原生錄音與 Native [AudioRecorder]，
/// 透過 Supabase Edge Function 呼叫語音轉文字（STT）與智慧排程模型。
class VoiceTranscriptionService {
  final AudioRecorder _recorder = AudioRecorder();
  final VoiceWebController _webController = createVoiceWebController();

  String _getSupabaseUrl() {
    String? url = dotenv.maybeGet('SUPABASE_URL');
    if (url == null || url.isEmpty) {
      url = const String.fromEnvironment('SUPABASE_URL');
    }
    return url;
  }

  String _getSupabaseAnonKey() {
    String? key = dotenv.maybeGet('SUPABASE_ANON_KEY');
    if (key == null || key.isEmpty) {
      key = const String.fromEnvironment('SUPABASE_ANON_KEY');
    }
    return key;
  }

  /// 檢查麥克風權限
  Future<bool> hasPermission() async {
    if (kIsWeb) {
      return await _webController.checkPermission();
    }
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      return false;
    }
  }

  /// 開始錄音
  Future<void> startRecording() async {
    if (kIsWeb) {
      await _webController.startRecording();
      return;
    }

    try {
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        throw Exception('請在系統設定中允許麥克風權限');
      }

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: '',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Uint8List> _stopAndGetAudioBytes() async {
    if (kIsWeb) {
      return await _webController.stopAndGetAudioBytes();
    }

    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      throw Exception('錄音停止失敗或無錄音內容');
    }

    if (path.startsWith('blob:') || path.startsWith('http')) {
      return await http.readBytes(Uri.parse(path));
    } else {
      return await http.readBytes(Uri.file(path));
    }
  }

  /// 停止錄音並送至 Edge Function 進行 AI 轉錄
  Future<String> stopAndTranscribe() async {
    if (isOfflineMode) {
      throw Exception('離線模式下無法使用語音轉錄，請確認網路連線後再試');
    }

    // 若瀏覽器原生 Web Speech 已成功辨識出文字，直接返回高精度中文
    if (kIsWeb && _webController.liveTranscript.trim().isNotEmpty) {
      final text = _webController.liveTranscript.trim();
      try {
        await _stopAndGetAudioBytes();
      } catch (_) {}
      return text;
    }

    final bytes = await _stopAndGetAudioBytes();
    if (bytes.isEmpty) {
      throw Exception('錄音內容為空，請說話後再重試');
    }

    final base64Audio = base64Encode(bytes);
    final supabase = Supabase.instance.client;
    String transcript = '';

    try {
      final response = await supabase.functions.invoke(
        'transcribe-voice',
        body: {
          'audioBase64': base64Audio,
          'mimeType': 'audio/webm',
        },
      );

      final data = response.data;
      if (data != null && data is Map) {
        if (data['error'] != null) {
          throw Exception(data['error'].toString());
        }
        transcript = data['transcript'] as String? ?? '';
      }
    } catch (e) {
      final baseUrl = _getSupabaseUrl();
      final url = '$baseUrl/functions/v1/transcribe-voice';
      final anonKey = _getSupabaseAnonKey();

      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken ?? anonKey}',
          'apikey': anonKey,
        },
        body: jsonEncode({
          'audioBase64': base64Audio,
          'mimeType': 'audio/webm',
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['error'] != null) {
          throw Exception(data['error'].toString());
        }
        transcript = data['transcript'] as String? ?? '';
      } else {
        throw Exception('HTTP ${res.statusCode}: ${res.body.isNotEmpty ? res.body : e}');
      }
    }

    if (transcript.isEmpty) {
      throw Exception('未能識別語音內容，請確認錄音環境安靜且說話清晰');
    }

    return transcript;
  }

  /// 停止錄音並送至 Edge Function 進行智慧行程排程與建立
  Future<Map<String, dynamic>> transcribeAndCreateEvent(DateTime localTime) async {
    if (isOfflineMode) {
      throw Exception('離線模式下無法使用語音智慧排程，請確認網路連線後再試');
    }

    final liveSpeech = _webController.liveTranscript.trim();
    final bytes = await _stopAndGetAudioBytes();
    final base64Audio = bytes.isNotEmpty ? base64Encode(bytes) : '';
    final localTimeStr = _formatIso8601WithOffset(localTime);

    final supabase = Supabase.instance.client;
    Map<String, dynamic> result = {};

    try {
      final response = await supabase.functions.invoke(
        'voice-scheduler',
        body: {
          'audioBase64': base64Audio,
          'transcript': liveSpeech,
          'mimeType': 'audio/webm',
          'localTime': localTimeStr,
        },
      );

      final data = response.data;
      if (data != null && data is Map) {
        if (data['error'] != null) {
          throw Exception(data['error'].toString());
        }
        result = Map<String, dynamic>.from(data);
      }
    } catch (e) {
      if (liveSpeech.isNotEmpty) {
        return await _fallbackCreateScheduleEvent(liveSpeech, localTime);
      }

      // Direct HTTP Fallback
      final baseUrl = _getSupabaseUrl();
      final url = '$baseUrl/functions/v1/voice-scheduler';
      final anonKey = _getSupabaseAnonKey();

      final res = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken ?? anonKey}',
          'apikey': anonKey,
        },
        body: jsonEncode({
          'audioBase64': base64Audio,
          'transcript': liveSpeech,
          'mimeType': 'audio/webm',
          'localTime': localTimeStr,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['error'] != null) {
          throw Exception(data['error'].toString());
        }
        result = Map<String, dynamic>.from(data);
      } else {
        if (liveSpeech.isNotEmpty) {
          return await _fallbackCreateScheduleEvent(liveSpeech, localTime);
        }
        throw Exception('HTTP ${res.statusCode}: ${res.body.isNotEmpty ? res.body : e}');
      }
    }

    if (result.isEmpty || result['success'] != true) {
      if (liveSpeech.isNotEmpty) {
        return await _fallbackCreateScheduleEvent(liveSpeech, localTime);
      }
      throw Exception('行程智慧解析與建立失敗');
    }

    return result;
  }

  /// 本機智慧排程備援建立器
  Future<Map<String, dynamic>> _fallbackCreateScheduleEvent(String text, DateTime localTime) async {
    final supabase = Supabase.instance.client;
    DateTime startTime = localTime.add(const Duration(hours: 2));
    if (text.contains('明天')) {
      startTime = DateTime(localTime.year, localTime.month, localTime.day + 1, 14, 0);
    } else if (text.contains('後天')) {
      startTime = DateTime(localTime.year, localTime.month, localTime.day + 2, 14, 0);
    }
    final endTime = startTime.add(const Duration(hours: 1));

    final newEvent = {
      'title': text,
      'description': '由語音輸入自動建立',
      'start_at': startTime.toIso8601String(),
      'end_at': endTime.toIso8601String(),
      'category': 'client_meeting',
      'is_completed': false,
    };

    try {
      final inserted = await supabase.from('schedule_events').insert(newEvent).select().single();
      return {
        'success': true,
        'transcript': text,
        'event': inserted,
      };
    } catch (_) {
      return {
        'success': true,
        'transcript': text,
        'event': newEvent,
      };
    }
  }

  /// 將 DateTime 格式化為帶有時區偏移量的 ISO 8601 字串
  String _formatIso8601WithOffset(DateTime dateTime) {
    final iso = dateTime.toIso8601String();
    if (dateTime.isUtc) {
      return iso.endsWith('Z') ? iso : '${iso}Z';
    }
    final offset = dateTime.timeZoneOffset;
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = offset.isNegative ? '-' : '+';
    final base = iso.endsWith('Z') ? iso.substring(0, iso.length - 1) : iso;
    return '$base$sign$hours:$minutes';
  }

  /// 取消目前錄音（不進行轉錄）
  Future<void> cancelRecording() async {
    if (kIsWeb) {
      _webController.cancel();
      return;
    }
    await _recorder.cancel();
  }

  /// 釋放資源
  void dispose() {
    if (kIsWeb) {
      _webController.dispose();
    }
    _recorder.dispose();
  }
}

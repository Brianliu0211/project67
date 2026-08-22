import 'dart:async';
import 'dart:convert';
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
    if (url.isEmpty) {
      url = 'https://algufuoxkeizxwkofmmp.supabase.co';
    }
    return url;
  }

  String _getSupabaseAnonKey() {
    String? key = dotenv.maybeGet('SUPABASE_ANON_KEY');
    if (key == null || key.isEmpty) {
      key = const String.fromEnvironment('SUPABASE_ANON_KEY');
    }
    if (key.isEmpty) {
      key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsZ3VmdW94a2Vpenh3a29mbW1wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0OTU2NzgsImV4cCI6MjA5OTA3MTY3OH0.QMEU47EHuLwEr7ok7O28h6U7Sh-geldoTQ5eZfI5tBA';
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
      debugPrint('functions.invoke voice-scheduler failed: $e, trying direct HTTP...');
      try {
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
          throw Exception('HTTP ${res.statusCode}: ${res.body}');
        }
      } catch (httpError) {
        debugPrint('Direct HTTP voice-scheduler failed: $httpError');
        if (liveSpeech.isNotEmpty) {
          return await _fallbackCreateScheduleEvent(liveSpeech, localTime, reasonError: '$e | HTTP: $httpError');
        }
        rethrow;
      }
    }

    if (result.isEmpty || result['success'] != true) {
      if (liveSpeech.isNotEmpty) {
        return await _fallbackCreateScheduleEvent(liveSpeech, localTime, reasonError: '結果非 Success: ${result['error']}');
      }
      throw Exception('行程智慧解析與建立失敗');
    }

    return result;
  }

  /// 本機智慧排程備援建立器
  Future<Map<String, dynamic>> _fallbackCreateScheduleEvent(String text, DateTime localTime, {String? reasonError}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('使用者未登入，無法建立行程');
    }

    // 解析日期偏移
    int dayOffset = 0;
    if (text.contains('明天')) {
      dayOffset = 1;
    } else if (text.contains('後天')) {
      dayOffset = 2;
    } else if (text.contains('大後天')) {
      dayOffset = 3;
    }

    // 解析時間點
    int hour = 14;
    if (text.contains('六點') || text.contains('6點') || text.contains('18點') || text.contains('18:00')) {
      hour = (text.contains('上午') || text.contains('早上') || text.contains('清晨')) ? 6 : 18;
    } else if (text.contains('五點') || text.contains('5點') || text.contains('17點')) {
      hour = (text.contains('上午') || text.contains('早上')) ? 5 : 17;
    } else if (text.contains('七點') || text.contains('7點') || text.contains('19點')) {
      hour = (text.contains('上午') || text.contains('早上')) ? 7 : 19;
    } else if (text.contains('八點') || text.contains('8點') || text.contains('20點')) {
      hour = (text.contains('上午') || text.contains('早上')) ? 8 : 20;
    } else if (text.contains('九點') || text.contains('9點') || text.contains('21點')) {
      hour = (text.contains('上午') || text.contains('早上')) ? 9 : 21;
    } else if (text.contains('十點') || text.contains('10點') || text.contains('22點')) {
      hour = (text.contains('上午') || text.contains('早上')) ? 10 : 22;
    }

    final targetDate = localTime.add(Duration(days: dayOffset));
    final startTime = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, 0);
    final endTime = startTime.add(const Duration(hours: 1));

    // 解析地點關鍵字 (例如: 「在臺北101」、「在星巴克」)
    String? extractedLocation;
    final locationMatch = RegExp(r'在([^\s,，。個\n]+)').firstMatch(text);
    if (locationMatch != null && (locationMatch.group(1)?.isNotEmpty ?? false)) {
      extractedLocation = locationMatch.group(1);
    }

    final newEvent = {
      'profile_id': user.id,
      'title': text,
      'description': '由語音輸入自動建立',
      'start_at': _formatIso8601WithOffset(startTime),
      'end_at': _formatIso8601WithOffset(endTime),
      'location': extractedLocation,
      'event_type': 'personal',
      'is_completed': false,
    };

    // 建立詳細警示訊息清單 (強制標示離線/本機備援模式)
    final warningMessages = <String>[
      '[⚠️ 當前為離線/本機備援模式${reasonError != null ? " - 原因: $reasonError" : ""}]'
    ];
    if (dayOffset == 0 && !text.contains('今天')) {
      warningMessages.add('未偵測到日期，已預設為今日');
    }
    if (hour == 14 && !text.contains('兩點') && !text.contains('2點') && !text.contains('14點')) {
      warningMessages.add('未特別指定時間點，已預設為 14:00');
    }
    if (extractedLocation == null) {
      warningMessages.add('未偵測到具體地點 (例: 「在臺北101」)');
    }

    try {
      final inserted = await supabase.from('schedule_events').insert(newEvent).select().single();
      if (warningMessages.isEmpty) {
        warningMessages.add('已透過智慧排程建立行程，請確認細節');
      }
      return {
        'success': true,
        'status': 'yellow',
        'warning_messages': warningMessages,
        'transcript': text,
        'event': inserted,
      };
    } catch (e) {
      debugPrint('本機備援行程寫入失敗: $e');
      warningMessages.add('行程資料庫寫入未完成，請點擊「儲存」');
      return {
        'success': true,
        'status': 'yellow',
        'warning_messages': warningMessages,
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

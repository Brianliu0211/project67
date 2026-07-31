import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

/// 語音轉錄服務
///
/// 封裝 [AudioRecorder] 的錄音流程，並透過 Supabase Edge Function
/// 呼叫 Gemini 2.0 Flash API 進行語音轉文字（STT）。
///
/// 完全相容 Web、Android、iOS 等平台。
class VoiceTranscriptionService {
  final AudioRecorder _recorder = AudioRecorder();

  /// 檢查麥克風權限
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// 開始錄音
  ///
  /// 拋出 [Exception] 若麥克風權限被拒絕
  Future<void> startRecording() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      throw Exception('麥克風權限被拒絕，請在瀏覽器或系統設定中允許存取麥克風');
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus, // 瀏覽器預設 audio/webm;codecs=opus
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: '',
    );
  }

  /// 停止錄音並送至 Edge Function 進行 AI 轉錄
  ///
  /// 返回轉錄後的文字字串。
  Future<String> stopAndTranscribe() async {
    if (isOfflineMode) {
      throw Exception('離線模式下無法使用語音轉錄，請確認網路連線後再試');
    }

    // 停止錄音並取得路徑 (Web 上為 blob:http://... URL)
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      throw Exception('錄音停止失敗或無錄音內容');
    }

    // 透過 HTTP GET 讀取 blob 位元組資料 (相容 Web 與 Native)
    final List<int> bytes;
    try {
      if (path.startsWith('blob:') || path.startsWith('http')) {
        bytes = await http.readBytes(Uri.parse(path));
      } else {
        // Native 平台
        bytes = await http.readBytes(Uri.file(path));
      }
    } catch (e) {
      throw Exception('讀取錄音資料失敗: $e');
    }

    if (bytes.isEmpty) {
      throw Exception('錄音資料為空，請確認麥克風正常運作後重試');
    }

    // Base64 編碼供 Edge Function 接收
    final base64Audio = base64Encode(bytes);

    final supabase = Supabase.instance.client;
    String transcript = '';

    // 優先使用 Supabase SDK invoke()
    try {
      final response = await supabase.functions.invoke(
        'rapid-responder',
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
      // 若 SDK invoke 失敗，使用 direct HTTP POST 作為 Fallback
      final baseUrl = const String.fromEnvironment('SUPABASE_URL');
      final url = '$baseUrl/functions/v1/rapid-responder';
      final anonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

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

  /// 取消目前錄音（不進行轉錄）
  Future<void> cancelRecording() async {
    await _recorder.cancel();
  }

  /// 釋放資源
  void dispose() {
    _recorder.dispose();
  }
}

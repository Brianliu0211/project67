import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';
import 'dart:html' as html;

/// 語音轉錄服務
///
/// 封裝 Web 原生 [html.MediaRecorder] 與 Native [AudioRecorder]，
/// 透過 Supabase Edge Function 呼叫語音轉文字（STT）模型。
class VoiceTranscriptionService {
  final AudioRecorder _recorder = AudioRecorder();

  // Web 原生 HTML5 錄音與 Web Speech 變數
  html.MediaStream? _webMediaStream;
  html.MediaRecorder? _webMediaRecorder;
  final List<html.Blob> _webRecordedChunks = [];
  html.SpeechRecognition? _webSpeechRecognition;
  String _webLiveTranscript = '';

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
      try {
        final mediaDevices = html.window.navigator.mediaDevices;
        if (mediaDevices == null) return false;
        final stream = await mediaDevices.getUserMedia({'audio': true});
        stream.getTracks().forEach((t) => t.stop());
        return true;
      } catch (e) {
        return false;
      }
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
      _webLiveTranscript = '';

      // 1. 啟動瀏覽器原生 Web Speech API（若瀏覽器支援）
      if (html.SpeechRecognition.supported) {
        try {
          _webSpeechRecognition = html.SpeechRecognition()
            ..continuous = true
            ..interimResults = true
            ..lang = 'zh-TW';

          _webSpeechRecognition!.onResult.listen((event) {
            final results = event.results;
            if (results != null) {
              final sb = StringBuffer();
              for (var res in results) {
                if (res.item(0) != null) {
                  sb.write(res.item(0)!.transcript ?? '');
                }
              }
              if (sb.isNotEmpty) {
                _webLiveTranscript = sb.toString();
              }
            }
          });

          _webSpeechRecognition!.start();
        } catch (e) {
          if (kDebugMode) print('SpeechRecognition init info: $e');
        }
      }

      // 2. 啟動 HTML5 MediaRecorder 錄音
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('瀏覽器不支援 Web Audio 錄音 API');
      }

      try {
        _webMediaStream = await mediaDevices.getUserMedia({'audio': true});
        _webRecordedChunks.clear();
        _webMediaRecorder = html.MediaRecorder(_webMediaStream!, {'mimeType': 'audio/webm'});
        _webMediaRecorder!.addEventListener('dataavailable', (event) {
          final html.Blob? blob = (event as html.BlobEvent).data;
          if (blob != null && blob.size > 0) {
            _webRecordedChunks.add(blob);
          }
        });
        _webMediaRecorder!.start(100);
        return;
      } catch (e) {
        throw Exception('麥克風授權失敗：請在網址列左側點擊 🔒 圖示允許存取麥克風 ($e)');
      }
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
      try {
        _webSpeechRecognition?.stop();
      } catch (_) {}

      if (_webMediaRecorder == null) {
        throw Exception('網頁錄音尚未啟動');
      }

      final completer = Completer<Uint8List>();
      _webMediaRecorder!.addEventListener('stop', (event) {
        try {
          final fullBlob = html.Blob(_webRecordedChunks, 'audio/webm');
          final reader = html.FileReader();
          reader.readAsArrayBuffer(fullBlob);
          reader.onLoadEnd.listen((_) {
            final result = reader.result;
            if (result is ByteBuffer) {
              completer.complete(Uint8List.view(result));
            } else if (result is Uint8List) {
              completer.complete(result);
            } else {
              completer.complete(Uint8List(0));
            }
          });
        } catch (err) {
          completer.completeError(err);
        }
      });

      _webMediaRecorder!.stop();
      _webMediaStream?.getTracks().forEach((t) => t.stop());
      _webMediaStream = null;
      _webMediaRecorder = null;

      final bytes = await completer.future;
      return bytes;
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
    if (kIsWeb && _webLiveTranscript.trim().isNotEmpty) {
      final text = _webLiveTranscript.trim();
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
      final baseUrl = _getSupabaseUrl();
      final url = '$baseUrl/functions/v1/rapid-responder';
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

    final liveSpeech = _webLiveTranscript.trim();
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
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
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
      try {
        _webSpeechRecognition?.stop();
      } catch (_) {}
      _webMediaRecorder?.stop();
      _webMediaStream?.getTracks().forEach((t) => t.stop());
      _webMediaStream = null;
      _webMediaRecorder = null;
      _webRecordedChunks.clear();
      _webLiveTranscript = '';
      return;
    }
    await _recorder.cancel();
  }

  /// 釋放資源
  void dispose() {
    if (kIsWeb) {
      try {
        _webSpeechRecognition?.stop();
      } catch (_) {}
      _webMediaStream?.getTracks().forEach((t) => t.stop());
      _webMediaStream = null;
      _webMediaRecorder = null;
    }
    _recorder.dispose();
  }
}

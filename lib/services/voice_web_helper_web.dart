// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'voice_web_helper.dart';

class VoiceWebControllerWeb implements VoiceWebController {
  html.MediaStream? _mediaStream;
  html.MediaRecorder? _mediaRecorder;
  final List<html.Blob> _recordedChunks = [];
  html.SpeechRecognition? _speechRecognition;
  String _liveTranscript = '';

  @override
  String get liveTranscript => _liveTranscript;

  @override
  void reset() {
    _liveTranscript = '';
    _recordedChunks.clear();
  }

  @override
  Future<bool> checkPermission() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) return false;
      final stream = await mediaDevices.getUserMedia({'audio': true});
      stream.getTracks().forEach((t) => t.stop());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> startRecording() async {
    reset();

    // 1. Web Speech API
    if (html.SpeechRecognition.supported) {
      try {
        _speechRecognition = html.SpeechRecognition()
          ..continuous = true
          ..interimResults = true
          ..lang = 'zh-TW';

        _speechRecognition!.onResult.listen((event) {
          final results = event.results;
          if (results != null) {
            final sb = StringBuffer();
            for (var res in results) {
              if (res.item(0) != null) {
                sb.write(res.item(0)!.transcript ?? '');
              }
            }
            if (sb.isNotEmpty) {
              _liveTranscript = sb.toString();
            }
          }
        });

        _speechRecognition!.start();
      } catch (_) {}
    }

    // 2. HTML5 MediaRecorder
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw Exception('瀏覽器不支援 Web Audio 錄音 API');
    }

    try {
      _mediaStream = await mediaDevices.getUserMedia({'audio': true});
      _recordedChunks.clear();
      _mediaRecorder = html.MediaRecorder(_mediaStream!, {'mimeType': 'audio/webm'});
      _mediaRecorder!.addEventListener('dataavailable', (event) {
        final html.Blob? blob = (event as html.BlobEvent).data;
        if (blob != null && blob.size > 0) {
          _recordedChunks.add(blob);
        }
      });
      _mediaRecorder!.start(100);
    } catch (e) {
      throw Exception('麥克風授權失敗：請在網址列左側點擊 🔒 圖示允許存取麥克風 ($e)');
    }
  }

  @override
  Future<Uint8List> stopAndGetAudioBytes() async {
    try {
      _speechRecognition?.stop();
    } catch (_) {}

    if (_mediaRecorder == null) {
      throw Exception('網頁錄音尚未啟動');
    }

    final completer = Completer<Uint8List>();
    _mediaRecorder!.addEventListener('stop', (event) {
      try {
        final fullBlob = html.Blob(_recordedChunks, 'audio/webm');
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

    _mediaRecorder!.stop();
    _mediaStream?.getTracks().forEach((t) => t.stop());
    _mediaStream = null;
    _mediaRecorder = null;

    return await completer.future;
  }

  @override
  void cancel() {
    try {
      _speechRecognition?.stop();
    } catch (_) {}
    _mediaRecorder?.stop();
    _mediaStream?.getTracks().forEach((t) => t.stop());
    _mediaStream = null;
    _mediaRecorder = null;
    reset();
  }

  @override
  void dispose() {
    cancel();
  }
}

VoiceWebController createVoiceWebControllerImpl() => VoiceWebControllerWeb();

import 'dart:typed_data';
import 'voice_web_helper_stub.dart'
    if (dart.library.html) 'voice_web_helper_web.dart' as impl;

/// 網頁端語音錄音與即時辨識控制器介面
abstract class VoiceWebController {
  Future<bool> checkPermission();
  Future<void> startRecording();
  Future<Uint8List> stopAndGetAudioBytes();
  String get liveTranscript;
  void cancel();
  void dispose();
  void reset();
}

VoiceWebController createVoiceWebController() => impl.createVoiceWebControllerImpl();

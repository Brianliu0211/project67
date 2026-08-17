import 'dart:typed_data';
import 'voice_web_helper.dart';

class VoiceWebControllerStub implements VoiceWebController {
  @override
  Future<bool> checkPermission() async => false;

  @override
  Future<void> startRecording() async {}

  @override
  Future<Uint8List> stopAndGetAudioBytes() async => Uint8List(0);

  @override
  String get liveTranscript => '';

  @override
  void cancel() {}

  @override
  void dispose() {}

  @override
  void reset() {}
}

VoiceWebController createVoiceWebControllerImpl() => VoiceWebControllerStub();

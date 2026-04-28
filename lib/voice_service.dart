import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceService {
  final FlutterTts _tts = FlutterTts();

  VoiceService() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
    // Set a premium sounding voice if possible (depends on OS)
    await _tts.setVoice({"name": "en-us-x-sfg#female_1-local", "locale": "en-US"});
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }
}

final voiceServiceProvider = Provider((ref) => VoiceService());

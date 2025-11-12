import 'package:flutter_tts/flutter_tts.dart';

/// Service for managing text-to-speech functionality
class TTSService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _enabled = true;

  // TTS settings
  double _speechRate = 0.5; // 0.0 to 1.0
  double _volume = 0.8; // 0.0 to 1.0
  double _pitch = 1.0; // 0.5 to 2.0

  TTSService();

  /// Initialize the TTS engine
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set default language
      await _tts.setLanguage('en-US');

      // Set initial settings
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(_volume);
      await _tts.setPitch(_pitch);

      _initialized = true;
    } catch (e) {
      print('[TTS] Initialization error: $e');
      _initialized = false;
    }
  }

  /// Enable or disable TTS
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Check if TTS is enabled
  bool get isEnabled => _enabled;

  /// Set speech rate (0.0 slow to 1.0 fast)
  Future<void> setSpeechRate(double rate) async {
    if (!_initialized) await initialize();
    _speechRate = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_speechRate);
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    if (!_initialized) await initialize();
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
  }

  /// Set pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    if (!_initialized) await initialize();
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
  }

  /// Speak text
  Future<void> speak(String text) async {
    if (!_enabled) return;
    if (!_initialized) await initialize();

    try {
      await _tts.speak(text);
    } catch (e) {
      print('[TTS] Speak error: $e');
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (!_initialized) return;

    try {
      await _tts.stop();
    } catch (e) {
      print('[TTS] Stop error: $e');
    }
  }

  /// Get available voices
  Future<List<dynamic>> getVoices() async {
    if (!_initialized) await initialize();

    try {
      return await _tts.getVoices;
    } catch (e) {
      print('[TTS] Get voices error: $e');
      return [];
    }
  }

  /// Set voice by name
  Future<void> setVoice(Map<String, String> voice) async {
    if (!_initialized) await initialize();

    try {
      await _tts.setVoice(voice);
    } catch (e) {
      print('[TTS] Set voice error: $e');
    }
  }

  /// Speak countdown number
  Future<void> speakCountdown(int number) async {
    final words = {
      5: 'Five',
      4: 'Four',
      3: 'Three',
      2: 'Two',
      1: 'One',
      0: 'Begin',
    };

    final text = words[number] ?? number.toString();
    await speak(text);
  }

  /// Speak calibration instruction
  Future<void> speakInstruction(String instruction) async {
    await speak(instruction);
  }

  /// Speak completion message
  Future<void> speakCompletion() async {
    await speak('Calibration complete');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
  }
}

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// Servicio para capturar audio y convertir a texto
class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _lastWords = '';
  List<String> _recognitionResults = [];

  factory SpeechService() {
    return _instance;
  }

  SpeechService._internal() {
    _speechToText = stt.SpeechToText();
  }

  /// Getter para verificar si está escuchando
  bool get isListening => _isListening;

  /// Getter para obtener el último texto reconocido
  String get lastWords => _lastWords;

  /// Getter para obtener todos los resultados
  List<String> get recognitionResults => _recognitionResults;

  /// Inicializa el servicio de speech-to-text
  Future<bool> initialize() async {
    try {
      // Solicitar permisos de micrófono
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        print('🎤 Permiso de micrófono denegado');
        return false;
      }

      final available = await _speechToText.initialize(
        onError: (error) {
          print('🎤 Error en speech: ${error.errorMsg}');
          _isListening = false;
        },
        onStatus: (status) {
          print('🎤 Status: $status');
        },
      );
      return available;
    } catch (e) {
      print('Error initializing speech: $e');
      return false;
    }
  }

  /// Inicia la escucha de audio
  Future<void> startListening({
    required Function(String) onResult,
    required Function() onDone,
    String localeId = 'es_ES',
  }) async {
    if (!_speechToText.isAvailable) {
      print('🎤 Speech to text no disponible');
      return;
    }

    if (_isListening) return;

    try {
      _isListening = true;
      _recognitionResults.clear();
      _lastWords = '';

      _speechToText.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          _recognitionResults.add(_lastWords);
          
          print('🎤 Reconocido: $_lastWords');
          onResult(_lastWords);

          // Si es resultado final, llamar a onDone
          if (result.finalResult) {
            print('🎤 Resultado final: $_lastWords');
            Future.delayed(const Duration(milliseconds: 500), () {
              onDone();
            });
          }
        },
        localeId: localeId,
        cancelOnError: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      print('Error starting listening: $e');
      _isListening = false;
      onDone();
    }
  }

  /// Detiene la escucha de audio
  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
      _isListening = false;
    } catch (e) {
      print('Error stopping listening: $e');
      _isListening = false;
    }
  }

  /// Cancela la escucha de audio
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
      _isListening = false;
      _lastWords = '';
      _recognitionResults.clear();
    } catch (e) {
      print('Error canceling listening: $e');
      _isListening = false;
    }
  }

  /// Obtiene los idiomas disponibles
  Future<List<String>> getLocales() async {
    try {
      final locales = await _speechToText.locales();
      return locales.map((locale) => locale.localeId).toList();
    } catch (e) {
      print('Error getting locales: $e');
      return [];
    }
  }
}

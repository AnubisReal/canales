import 'package:flutter/services.dart';

class VideoIntentService {
  static const MethodChannel _channel = MethodChannel(
    'com.canales.app/video_intent',
  );

  /// Abre un video en reproductores externos usando Intent de Android
  static Future<bool> openVideoWithIntent(String url) async {
    try {
      final result = await _channel.invokeMethod('openVideo', {'url': url});
      return result == true;
    } on PlatformException catch (e) {
      print('Error al abrir video con Intent: ${e.message}');
      return false;
    }
  }

  /// Verifica si una aplicación está instalada
  static Future<bool> isAppInstalled(String packageName) async {
    try {
      final result = await _channel.invokeMethod('isAppInstalled', {
        'packageName': packageName,
      });
      return result == true;
    } on PlatformException catch (e) {
      print('Error al verificar app instalada: ${e.message}');
      return false;
    }
  }
}

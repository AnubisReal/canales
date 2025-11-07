import 'package:http/http.dart' as http;
import 'settings_service.dart';

class AcestreamService {
  /// Obtiene la URL del motor Acestream desde la configuración
  static String get aceEngineUrl => SettingsService.acestreamServerUrl;
  
  /// Extrae el hash de Acestream de la URL
  static String? extractAcestreamHash(String url) {
    // Buscar el patrón id= en la URL
    final regex = RegExp(r'id=([a-fA-F0-9]{40})');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
  
  /// Verifica si el motor Acestream está corriendo
  static Future<bool> isAcestreamEngineRunning() async {
    try {
      final response = await http.get(
        Uri.parse('$aceEngineUrl/webui/api/service?method=get_version'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Inicia un stream de Acestream y devuelve la URL HTTP para reproducir
  static Future<String?> startAcestreamStream(String hash) async {
    try {
      // Verificar que el motor esté corriendo
      if (!await isAcestreamEngineRunning()) {
        throw Exception('Motor Acestream no está corriendo');
      }
      
      // Primero intentar obtener el stream con timeout más largo
      try {
        final startResponse = await http.get(
          Uri.parse('$aceEngineUrl/ace/getstream?id=$hash'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 30));
        
        if (startResponse.statusCode == 200) {
          // El motor devuelve la URL directamente
          return '$aceEngineUrl/ace/getstream?id=$hash';
        }
      } catch (e) {
        print('Primer intento falló: $e');
      }
      
      // Segundo intento: usar la API de webui para iniciar el contenido
      try {
        final webUIResponse = await http.get(
          Uri.parse('$aceEngineUrl/webui/api/service?method=start_content&content_id=$hash&format=json'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 20));
        
        if (webUIResponse.statusCode == 200) {
          // Esperar un poco para que el stream se inicialice
          await Future.delayed(const Duration(seconds: 3));
          return '$aceEngineUrl/ace/getstream?id=$hash';
        }
      } catch (e) {
        print('Segundo intento falló: $e');
      }
      
      // Tercer intento: URL directa sin verificación previa
      return '$aceEngineUrl/ace/getstream?id=$hash';
      
    } catch (e) {
      print('Error iniciando stream Acestream: $e');
      return null;
    }
  }
  
  /// Para un stream de Acestream
  static Future<void> stopAcestreamStream(String hash) async {
    try {
      await http.get(
        Uri.parse('$aceEngineUrl/webui/api/service?method=stop_content&content_id=$hash'),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      print('Error parando stream Acestream: $e');
    }
  }
}

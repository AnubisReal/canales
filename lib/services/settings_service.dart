import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static String _acestreamServerUrl = 'http://127.0.0.1:6878';
  static String _defaultPlayerPackage = ''; // '' = Preguntar siempre
  static const String _keyDefaultPlayer = 'default_player_package';
  
  /// Obtiene la URL del servidor Acestream configurada
  static String get acestreamServerUrl => _acestreamServerUrl;
  
  /// Obtiene el package name del reproductor por defecto
  static String get defaultPlayerPackage => _defaultPlayerPackage;
  
  /// Establece una nueva URL del servidor Acestream
  static void setAcestreamServerUrl(String url) {
    // Asegurar que la URL tenga el formato correcto
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    
    // Remover barra final si existe
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    
    _acestreamServerUrl = url;
  }
  
  /// Establece la IP del servidor Acestream (añade automáticamente http:// y :6878)
  static void setAcestreamServerIp(String ip) {
    // Limpiar la IP
    ip = ip.trim();
    
    // Si no tiene puerto, agregar el puerto por defecto de Acestream
    if (!ip.contains(':')) {
      ip = '$ip:6878';
    }
    
    setAcestreamServerUrl('http://$ip');
  }
  
  /// Obtiene solo la IP del servidor (sin http:// y puerto)
  static String getAcestreamServerIp() {
    String url = _acestreamServerUrl;
    
    // Remover protocolo
    url = url.replaceAll('http://', '').replaceAll('https://', '');
    
    // Remover puerto si es el por defecto
    if (url.endsWith(':6878')) {
      url = url.replaceAll(':6878', '');
    }
    
    return url;
  }
  
  /// Resetea a la configuración por defecto (localhost)
  static void resetToDefault() {
    _acestreamServerUrl = 'http://127.0.0.1:6878';
  }
  
  /// Carga el reproductor por defecto desde SharedPreferences
  static Future<void> loadDefaultPlayer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _defaultPlayerPackage = prefs.getString(_keyDefaultPlayer) ?? '';
      print('✅ Reproductor por defecto cargado: ${_defaultPlayerPackage.isEmpty ? "Preguntar siempre" : _defaultPlayerPackage}');
    } catch (e) {
      print('⚠️ Error al cargar reproductor por defecto: $e');
      _defaultPlayerPackage = '';
    }
  }
  
  /// Guarda el reproductor por defecto en SharedPreferences
  static Future<void> setDefaultPlayer(String packageName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDefaultPlayer, packageName);
      _defaultPlayerPackage = packageName;
      print('✅ Reproductor por defecto guardado: ${packageName.isEmpty ? "Preguntar siempre" : packageName}');
    } catch (e) {
      print('❌ Error al guardar reproductor por defecto: $e');
    }
  }
  
  /// Valida si una IP es válida
  static bool isValidIp(String ip) {
    // Regex básico para validar IP
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    
    if (ip == 'localhost' || ip == '127.0.0.1') {
      return true;
    }
    
    if (!ipRegex.hasMatch(ip)) {
      return false;
    }
    
    // Verificar que cada octeto esté entre 0-255
    final parts = ip.split('.');
    for (String part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return false;
      }
    }
    
    return true;
  }
}

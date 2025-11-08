import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/channel.dart';

class M3UService {
  static const String _cacheKey = 'cached_m3u_content';
  static const String _cacheTimeKey = 'cached_m3u_time';
  static const String _m3uUrlKey = 'user_m3u_url';
  
  /// Verifica si el usuario ya configuró una URL M3U
  static Future<bool> hasM3uUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_m3uUrlKey);
    return url != null && url.isNotEmpty;
  }
  
  /// Obtiene la URL M3U guardada por el usuario
  static Future<String?> getM3uUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_m3uUrlKey);
  }
  
  /// Guarda la URL M3U del usuario
  static Future<void> setM3uUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_m3uUrlKey, url);
    print('✅ URL M3U guardada: $url');
  }
  
  /// Elimina la URL M3U y el caché
  static Future<void> clearM3uUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_m3uUrlKey);
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
    print('🗑️ URL M3U y caché eliminados');
  }

  /// Obtiene canales desde caché o descarga si no existe
  static Future<List<Channel>> fetchChannels() async {
    // Intentar cargar desde caché primero
    final cachedChannels = await _loadFromCache();
    if (cachedChannels != null && cachedChannels.isNotEmpty) {
      print('✅ Canales cargados desde caché: ${cachedChannels.length} canales');
      
      // Descargar en segundo plano para actualizar caché
      _updateCacheInBackground();
      
      return cachedChannels;
    }

    // Si no hay caché, descargar ahora
    print('📥 No hay caché, descargando canales de IPFS...');
    return await _downloadAndCache();
  }

  /// Descarga canales y los guarda en caché
  static Future<List<Channel>> _downloadAndCache() async {
    try {
      final m3uUrl = await getM3uUrl();
      if (m3uUrl == null || m3uUrl.isEmpty) {
        throw Exception('No hay URL M3U configurada');
      }
      
      final response = await http.get(
        Uri.parse(m3uUrl),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout: La descarga de canales tardó más de 15 segundos');
        },
      );
      
      if (response.statusCode == 200) {
        // Forzar decodificación UTF-8 para caracteres especiales (tildes, ñ, etc.)
        final content = utf8.decode(response.bodyBytes);
        final channels = _parseM3U(content);
        
        // Guardar en caché
        await _saveToCache(content);
        
        print('✅ Canales descargados y guardados en caché: ${channels.length} canales');
        return channels;
      } else {
        throw Exception('Error al cargar la lista M3U: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  /// Actualiza el caché en segundo plano sin bloquear
  static Future<void> _updateCacheInBackground() async {
    try {
      print('🔄 Actualizando caché de canales en segundo plano...');
      final m3uUrl = await getM3uUrl();
      if (m3uUrl == null || m3uUrl.isEmpty) {
        print('⚠️ No hay URL M3U configurada para actualizar');
        return;
      }
      
      final response = await http.get(
        Uri.parse(m3uUrl),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout al actualizar caché');
        },
      );
      
      if (response.statusCode == 200) {
        // Forzar decodificación UTF-8
        final content = utf8.decode(response.bodyBytes);
        await _saveToCache(content);
        print('✅ Caché de canales actualizado en segundo plano');
      }
    } catch (e) {
      print('⚠️ Error al actualizar caché en segundo plano: $e');
      // No lanzar error, solo log
    }
  }

  /// Guarda el contenido M3U en caché
  static Future<void> _saveToCache(String content) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, content);
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Carga canales desde caché
  static Future<List<Channel>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedContent = prefs.getString(_cacheKey);
      
      if (cachedContent != null && cachedContent.isNotEmpty) {
        return _parseM3U(cachedContent);
      }
    } catch (e) {
      print('⚠️ Error al cargar caché: $e');
    }
    return null;
  }

  /// Limpia el caché de canales
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
    print('🗑️ Caché de canales limpiado');
  }

  static List<Channel> _parseM3U(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Buscar líneas EXTINF
      if (line.startsWith('#EXTINF:')) {
        // La siguiente línea debería ser la URL
        if (i + 1 < lines.length) {
          final url = lines[i + 1].trim();
          if (url.isNotEmpty && !url.startsWith('#')) {
            try {
              final channel = Channel.fromM3UEntry(line, url);
              // Solo agregar canales con logo válido
              if (channel.logoUrl.isNotEmpty) {
                channels.add(channel);
              }
            } catch (e) {
              // Ignorar canales con errores de parsing
              continue;
            }
          }
        }
      }
    }
    
    return channels;
  }
}

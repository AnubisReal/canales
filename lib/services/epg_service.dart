import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:path_provider/path_provider.dart';
import '../models/epg_channel.dart';
import '../models/epg_programme.dart';

class EpgService {
  static const String epgUrl =
      'https://raw.githubusercontent.com/davidmuma/EPG_dobleM/master/guiatv_color.xml.gz';
  static const String _cacheFileName = 'epg_cache.json';

  static List<EpgChannel> _channels = [];
  static List<EpgProgramme> _programmes = [];
  static DateTime? _lastUpdate;
  static bool _isLoading = false;
  static bool _isLoaded = false;
  
  // HashMap para búsqueda rápida O(1)
  static Map<String, EpgChannel> _channelsByNormalizedName = {};

  /// Asegura que el EPG esté cargado antes de usarlo (carga bajo demanda)
  static Future<void> _ensureEpgLoaded() async {
    // Si ya está cargado y no necesita actualización, no hacer nada
    if (_isLoaded && !needsUpdate()) {
      return;
    }

    // Si ya está cargando, NO ESPERAR - retornar inmediatamente
    // Esto evita bloqueos de 30 segundos
    if (_isLoading) {
      print('⏳ EPG ya está cargando, continuando sin esperar...');
      return;
    }

    // Iniciar carga en segundo plano sin esperar
    downloadAndParseEpg().catchError((e) {
      print('⚠️ Error al cargar EPG: $e');
      return false;
    });
  }

  /// Espera a que el EPG termine de cargar (con timeout)
  static Future<bool> waitForEpgLoad({Duration timeout = const Duration(seconds: 30)}) async {
    // Si ya está cargado, retornar inmediatamente
    if (_isLoaded) {
      return true;
    }

    print('⏳ Esperando a que el EPG termine de cargar...');
    final startTime = DateTime.now();
    
    // Esperar en bucle hasta que se cargue o se agote el timeout
    while (!_isLoaded) {
      // Verificar timeout
      if (DateTime.now().difference(startTime) > timeout) {
        print('⚠️ Timeout esperando carga de EPG');
        return false;
      }
      
      // Esperar un poco antes de verificar de nuevo
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    print('✅ EPG cargado exitosamente');
    return true;
  }

  /// Descarga y parsea el EPG en un Isolate (no bloquea la UI)
  static Future<bool> downloadAndParseEpg() async {
    if (_isLoading) return false;
    
    _isLoading = true;
    try {
      // Intentar cargar desde caché primero
      final cacheLoaded = await _loadFromCache();
      if (cacheLoaded && !needsUpdate()) {
        print('✅ EPG cargado desde caché local');
        _isLoading = false;
        return true;
      }

      print('📥 Descargando guía EPG en segundo plano...');
      final response = await http.get(
        Uri.parse(epgUrl),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Timeout: La descarga de EPG tardó más de 20 segundos');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Error al descargar EPG: ${response.statusCode}');
      }

      print('📦 Procesando EPG en segundo plano...');

      // Procesar en un Isolate para no bloquear la UI
      final result = await Isolate.run(
        () => _parseEpgInIsolate(response.bodyBytes),
      );

      if (result != null) {
        _channels = result['channels'] as List<EpgChannel>;
        _programmes = result['programmes'] as List<EpgProgramme>;
        _lastUpdate = DateTime.now();
        _isLoaded = true;
        
        // Construir HashMap para búsqueda rápida
        _buildChannelHashMap();

        print('✅ Canales parseados: ${_channels.length}');
        print('✅ Programas parseados: ${_programmes.length}');
        
        // Guardar en caché
        await _saveToCache();
        
        _isLoading = false;
        return true;
      }

      _isLoading = false;
      return false;
    } catch (e) {
      print('❌ Error al descargar/parsear EPG: $e');
      _isLoading = false;
      return false;
    }
  }

  /// Función que se ejecuta en el Isolate (hilo separado)
  static Map<String, dynamic>? _parseEpgInIsolate(List<int> bytes) {
    try {
      // Descomprimir
      final archive = GZipDecoder().decodeBytes(bytes);
      final xmlString = utf8.decode(archive);

      // Parsear XML
      final document = XmlDocument.parse(xmlString);
      final root = document.rootElement;

      // Parsear canales
      final channelElements = root.findElements('channel');
      final channels = channelElements
          .map((e) => EpgChannel.fromXml(e))
          .toList();

      // Parsear programas
      final programmeElements = root.findElements('programme');
      final programmes = programmeElements
          .map((e) => EpgProgramme.fromXml(e))
          .toList();

      // Filtrar solo programas de hoy y mañana
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 2));
      final filteredProgrammes = programmes.where((p) {
        return p.stop.isAfter(now) && p.start.isBefore(tomorrow);
      }).toList();

      return {'channels': channels, 'programmes': filteredProgrammes};
    } catch (e) {
      print('❌ Error en Isolate: $e');
      return null;
    }
  }

  /// Construir HashMap para búsqueda rápida
  static void _buildChannelHashMap() {
    _channelsByNormalizedName.clear();
    
    for (final epgChannel in _channels) {
      // Agregar por ID normalizado
      final normalizedId = _normalizeChannelName(epgChannel.id);
      _channelsByNormalizedName[normalizedId] = epgChannel;
      
      // Agregar por cada display name normalizado
      for (final displayName in epgChannel.displayNames) {
        final normalizedName = _normalizeChannelName(displayName);
        _channelsByNormalizedName[normalizedName] = epgChannel;
      }
    }
    
    print('📊 HashMap construido con ${_channelsByNormalizedName.length} entradas');
  }

  /// Busca un canal EPG que coincida con el tvg-id del canal M3U
  static Future<EpgChannel?> findMatchingEpgChannel(String tvgId) async {
    // Asegurar que el EPG esté cargado
    await _ensureEpgLoaded();
    
    // Si tvgId está vacío, no hay match posible
    if (tvgId.isEmpty) {
      return null;
    }
    
    // Búsqueda EXACTA por ID (sin normalización)
    // Esto evita duplicados y asegura match correcto
    for (final epgChannel in _channels) {
      if (epgChannel.id == tvgId) {
        return epgChannel;
      }
    }

    return null;
  }

  /// Obtiene el programa actual de un canal
  static Future<EpgProgramme?> getCurrentProgramme(String channelId) async {
    // Asegurar que el EPG esté cargado
    await _ensureEpgLoaded();
    final now = DateTime.now();

    for (final programme in _programmes) {
      if (programme.channelId == channelId && programme.isLive) {
        return programme;
      }
    }

    return null;
  }

  /// Obtiene los próximos programas de un canal
  static Future<List<EpgProgramme>> getUpcomingProgrammes(
    String channelId, {
    int count = 10,
  }) async {
    // Asegurar que el EPG esté cargado
    await _ensureEpgLoaded();
    final now = DateTime.now();

    final upcoming = _programmes
        .where((p) => p.channelId == channelId && p.isUpcoming)
        .toList();

    // Ordenar por fecha de inicio
    upcoming.sort((a, b) => a.start.compareTo(b.start));

    return upcoming.take(count).toList();
  }

  /// Obtiene todos los programas de un canal (pasados, actuales y futuros)
  static Future<List<EpgProgramme>> getAllProgrammes(String channelId) async {
    // Asegurar que el EPG esté cargado
    await _ensureEpgLoaded();
    final programmes = _programmes
        .where((p) => p.channelId == channelId)
        .toList();

    // Ordenar por fecha de inicio
    programmes.sort((a, b) => a.start.compareTo(b.start));

    return programmes;
  }

  /// Obtiene todos los programas de un canal para un día específico
  static Future<List<EpgProgramme>> getProgrammesForDay(
    String channelId,
    DateTime day,
  ) async {
    // Asegurar que el EPG esté cargado
    await _ensureEpgLoaded();
    
    final startOfDay = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59);

    final programmes = _programmes
        .where((p) =>
            p.channelId == channelId &&
            p.start.isAfter(startOfDay) &&
            p.start.isBefore(endOfDay))
        .toList();

    // Ordenar por fecha de inicio
    programmes.sort((a, b) => a.start.compareTo(b.start));

    return programmes;
  }

  /// Obtiene TODOS los programas de hoy de todos los canales
  static Future<List<EpgProgramme>> getAllProgrammesToday() async {
    // Asegurar que el EPG esté cargado
    await _ensureEpgLoaded();
    
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final programmes = _programmes
        .where((p) =>
            p.start.isAfter(startOfDay) &&
            p.start.isBefore(endOfDay))
        .toList();

    return programmes;
  }

  /// Normaliza el nombre del canal para comparación
  static String _normalizeChannelName(String name) {
    // Eliminar todo después de "-->" o "---" (proveedores/fuentes)
    if (name.contains('-->')) {
      name = name.split('-->')[0];
    }
    if (name.contains('---')) {
      name = name.split('---')[0];
    }
    
    return name
        .toLowerCase()
        // Eliminar calidades
        .replaceAll(' hd', '')
        .replaceAll(' fhd', '')
        .replaceAll(' uhd', '')
        .replaceAll(' sd', '')
        .replaceAll('hd', '')
        .replaceAll('fhd', '')
        .replaceAll('uhd', '')
        .replaceAll(' 1080', '')
        .replaceAll(' 720', '')
        .replaceAll('1080', '')
        .replaceAll('720', '')
        // Eliminar extensiones
        .replaceAll('.tv', '')
        // Normalizar operadores
        .replaceAll('movistar', 'm')
        .replaceAll('m+', 'm')
        .replaceAll('m.', 'm')
        // Eliminar símbolos y números
        .replaceAll('+', '')
        .replaceAll('.', '')
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll(RegExp(r'[0-9]+[a-z]?'), '') // Eliminar números como "59c", "1", "2", etc.
        // Eliminar espacios
        .replaceAll(' ', '')
        .trim();
  }

  /// Verifica si necesita actualizar el EPG
  static bool needsUpdate() {
    if (_lastUpdate == null) return true;

    final hoursSinceUpdate = DateTime.now().difference(_lastUpdate!).inHours;
    return hoursSinceUpdate >= 12; // Actualizar cada 12 horas
  }

  /// Guarda los datos del EPG en caché local
  static Future<void> _saveToCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_cacheFileName');

      // Convertir datos a JSON (incluyendo timestamp)
      final cacheData = {
        'lastUpdate': DateTime.now().toIso8601String(),
        'channels': _channels.map((c) => c.toJson()).toList(),
        'programmes': _programmes.map((p) => p.toJson()).toList(),
      };

      // Guardar archivo JSON
      await file.writeAsString(jsonEncode(cacheData));

      print('💾 EPG guardado en caché local (${_channels.length} canales, ${_programmes.length} programas)');
    } catch (e) {
      print('⚠️ Error al guardar caché: $e');
    }
  }

  /// Carga los datos del EPG desde caché local
  static Future<bool> _loadFromCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_cacheFileName');

      // Verificar si existe el archivo
      if (!await file.exists()) {
        print('📂 No existe caché local de EPG');
        return false;
      }

      // Leer y parsear JSON
      final jsonStr = await file.readAsString();
      final cacheData = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Leer timestamp de última actualización
      final lastUpdateStr = cacheData['lastUpdate'] as String?;
      if (lastUpdateStr != null) {
        _lastUpdate = DateTime.parse(lastUpdateStr);
      }

      // Convertir de JSON a objetos
      _channels = (cacheData['channels'] as List)
          .map((json) => EpgChannel.fromJson(json))
          .toList();
      _programmes = (cacheData['programmes'] as List)
          .map((json) => EpgProgramme.fromJson(json))
          .toList();

      _isLoaded = true;
      
      // Construir HashMap después de cargar desde caché
      _buildChannelHashMap();
      
      final cacheAge = _lastUpdate != null 
          ? DateTime.now().difference(_lastUpdate!).inHours 
          : 0;
      
      print('📂 EPG cargado desde caché: ${_channels.length} canales, ${_programmes.length} programas (${cacheAge}h antiguo)');
      return true;
    } catch (e) {
      print('⚠️ Error al cargar caché: $e');
      return false;
    }
  }

  /// Obtiene estadísticas del EPG
  static Map<String, dynamic> getStats() {
    return {
      'channels': _channels.length,
      'programmes': _programmes.length,
      'lastUpdate': _lastUpdate?.toIso8601String(),
    };
  }
}

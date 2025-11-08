import '../models/channel.dart';
import '../models/epg_channel.dart';
import '../models/epg_programme.dart';
import 'epg_service.dart';

class FootballMatch {
  final EpgProgramme programme;
  final Channel channel;
  final String channelName;

  FootballMatch({
    required this.programme,
    required this.channel,
    required this.channelName,
  });
}

class FootballService {
  static List<FootballMatch> _cachedMatches = [];
  static bool _isLoading = false;
  static bool _isLoaded = false;
  static DateTime? _lastUpdate;

  /// Obtiene los partidos cacheados, filtrando los que ya terminaron
  static List<FootballMatch> getCachedMatches() {
    // Filtrar en tiempo real los partidos que ya terminaron
    return _cachedMatches.where((match) => !match.programme.isPast).toList();
  }

  /// Verifica si los datos están cargados
  static bool isLoaded() {
    return _isLoaded;
  }

  /// Verifica si está cargando
  static bool isLoading() {
    return _isLoading;
  }

  /// Pre-carga los partidos de fútbol en segundo plano
  static Future<void> preloadFootballMatches(List<Channel> channels) async {
    if (_isLoading) return;

    _isLoading = true;
    print('⚽ Iniciando pre-carga de partidos de fútbol...');

    try {
      final matches = <FootballMatch>[];
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Obtener TODOS los programas de hoy
      final allProgrammes = await EpgService.getAllProgrammesToday();

      // Crear un mapa de channelId -> Channel para búsqueda rápida
      // PARALELIZAR la búsqueda de canales EPG para mejorar rendimiento
      print('🚀 Buscando canales EPG en paralelo...');
      final channelMap = <String, Channel>{};
      
      // Dividir en lotes de 10 para no sobrecargar
      const batchSize = 10;
      for (var i = 0; i < channels.length; i += batchSize) {
        final batch = channels.skip(i).take(batchSize).toList();
        
        // Procesar lote en paralelo
        final results = await Future.wait(
          batch.map((channel) async {
            final epgChannel = await EpgService.findMatchingEpgChannel(channel.id);
            return {'channel': channel, 'epgChannel': epgChannel};
          }),
        );
        
        // Agregar resultados al mapa
        for (final result in results) {
          final epgChannel = result['epgChannel'] as EpgChannel?;
          if (epgChannel != null) {
            channelMap[epgChannel.id] = result['channel'] as Channel;
          }
        }
      }
      
      print('✅ ${channelMap.length} canales EPG encontrados');

      // Filtrar programas de fútbol usando la categoría
      for (final programme in allProgrammes) {
        // Verificar que sea de hoy
        if (programme.start.isBefore(startOfDay) || programme.start.isAfter(endOfDay)) {
          continue;
        }

        // FILTRO IMPORTANTE: Solo mostrar partidos que NO han terminado
        // Usar el getter isPast del modelo EpgProgramme
        if (programme.isPast) {
          continue; // Partido ya terminado, saltar
        }

        // Usar la categoría del programa
        if (programme.category == null) continue;

        final category = programme.category!.toLowerCase();

        // Verificar si la categoría es de fútbol
        final isFootball = category.contains('futbol') ||
            category.contains('fútbol') ||
            category.contains('football') ||
            category.contains('soccer');

        if (isFootball) {
          final channel = channelMap[programme.channelId];
          if (channel != null) {
            matches.add(FootballMatch(
              programme: programme,
              channel: channel,
              channelName: channel.name,
            ));
          }
        }
      }

      // Ordenar por hora de inicio
      matches.sort((a, b) => a.programme.start.compareTo(b.programme.start));

      _cachedMatches = matches;
      _lastUpdate = DateTime.now();
      _isLoaded = true;
      _isLoading = false;

      print('✅ Partidos de fútbol pre-cargados: ${matches.length} partidos');
    } catch (e) {
      print('❌ Error al pre-cargar partidos de fútbol: $e');
      _isLoading = false;
    }
  }

  /// Fuerza una recarga de los partidos
  static Future<void> reloadMatches(List<Channel> channels) async {
    _isLoaded = false;
    await preloadFootballMatches(channels);
  }
}

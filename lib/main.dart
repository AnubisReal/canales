import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'models/channel.dart';
import 'models/epg_programme.dart';
import 'services/m3u_service.dart';
import 'services/epg_service.dart';
import 'services/football_service.dart';
import 'services/favorites_service.dart';
import 'screens/channel_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/m3u_setup_screen.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'dart:io' show Platform;
import 'dart:async';

// Clase para resultados de búsqueda de programas
class ProgrammeSearchResult {
  final EpgProgramme programme;
  final Channel channel;
  final String channelName;

  ProgrammeSearchResult({
    required this.programme,
    required this.channel,
    required this.channelName,
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Forzar orientación landscape para Android TV
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Cargar configuración del reproductor por defecto
  await SettingsService.loadDefaultPlayer();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isChecking = true;
  bool _hasM3uUrl = false;

  @override
  void initState() {
    super.initState();
    _checkM3uUrl();
  }

  Future<void> _checkM3uUrl() async {
    final hasUrl = await M3UService.hasM3uUrl();
    if (mounted) {
      setState(() {
        _hasM3uUrl = hasUrl;
        _isChecking = false;
      });
    }
  }

  void _onM3uConfigured() {
    _checkM3uUrl();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return MaterialApp(
        title: 'Canales',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.blue)),
        ),
      );
    }

    return MaterialApp(
      title: 'Canales',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: _hasM3uUrl
          ? const ChannelsScreen()
          : M3uSetupScreen(onConfigured: _onM3uConfigured),
    );
  }
}

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen>
    with WidgetsBindingObserver {
  List<Channel> channels = [];
  List<Channel> filteredChannels = [];
  List<dynamic> displayItems = []; // Puede ser canales o partidos
  bool isShowingFootballMatches = false; // True si estamos mostrando partidos
  bool isLoading = true;
  String? error;
  String selectedCategory = 'Todos';
  int selectedCategoryIndex = 0;
  int selectedChannelIndex = 0;
  bool isNavigatingCategories = false; // true = categorías, false = canales

  bool isSettingsButtonSelected =
      false; // true = botón de configuración seleccionado
  bool isRefreshButtonSelected =
      false; // true = botón de actualizar seleccionado
  bool isSearchButtonSelected = false; // true = botón de búsqueda seleccionado
  bool isFavoritesButtonSelected =
      false; // true = botón de favoritos seleccionado
  bool isShowingFavorites = false; // true = mostrando solo favoritos
  bool isRefreshing = false; // true = está actualizando datos
  bool isSearching = false; // true = modo búsqueda activo
  String searchQuery = ''; // texto de búsqueda
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FocusNode _searchFocusNode =
      FocusNode(); // FocusNode para el campo de búsqueda
  bool _hasLoadedOnce = false; // Evitar recargas múltiples

  // Variables para doble pulsación de atrás
  DateTime? _lastBackPress;
  static const _backPressThreshold = Duration(seconds: 2);

  // Variables para el indicador EPG
  bool isEpgLoaded = false;
  bool showEpgIndicator = true;
  Timer? _epgBlinkTimer;
  Timer? _epgStatusTimer; // Timer para verificar estado EPG

  // Índice de programas para búsqueda rápida
  Map<String, List<ProgrammeSearchResult>> _programmeIndex =
      {}; // título_programa -> [resultados]
  bool _isProgrammeIndexBuilt = false;

  // Resultados de búsqueda de programas (similar a FootballMatch)
  List<ProgrammeSearchResult> _searchProgrammeResults = [];
  bool _isShowingProgrammeResults =
      false; // true = mostrando resultados de programas

  // Variables para scroll automático en TV
  final int tvColumns = 6; // Columnas fijas para TV
  final int tvRows = 3; // Filas visibles para TV (canales normales)
  final int tvRowsFootball =
      3; // Filas visibles para fútbol (pósters más altos)
  int startRowIndex = 0; // Primera fila visible en el scroll

  // Obtener filas visibles según la sección actual
  int get currentTvRows => isShowingFootballMatches ? tvRowsFootball : tvRows;

  final List<String> categories = [
    'Todos',
    'Deportes',
    'Futbol',
    'Entretenimiento',
  ];

  // Detectar si estamos en Android TV o necesitamos navegación por teclado
  bool get isAndroidTV {
    try {
      return Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  // Para mostrar siempre el indicador visual cuando hay navegación por teclado
  bool get showKeyboardNavigation => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadChannels();
    _checkEpgStatus();
    _loadFavorites();
    _checkForUpdates(); // Verificar actualizaciones al iniciar
  }
  
  // Verificar si hay actualizaciones disponibles
  Future<void> _checkForUpdates() async {
    // Esperar 5 segundos para no interferir con la carga inicial
    await Future.delayed(const Duration(seconds: 5));
    
    final updateInfo = await UpdateService.checkForUpdate();
    
    if (updateInfo != null && updateInfo['hasUpdate'] == true && mounted) {
      _showUpdateDialog(updateInfo);
    }
  }
  
  // Mostrar diálogo de actualización disponible
  void _showUpdateDialog(Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue, size: 28),
            SizedBox(width: 12),
            Text(
              '🎉 Actualización disponible',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nueva versión: ${updateInfo['version']}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              updateInfo['releaseNotes'] ?? 'Nueva versión disponible',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'Tamaño: ${(updateInfo['size'] / 1024 / 1024).toStringAsFixed(1)} MB',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Más tarde',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstallUpdate(updateInfo);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Actualizar ahora',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
  
  // Descargar e instalar actualización
  Future<void> _downloadAndInstallUpdate(Map<String, dynamic> updateInfo) async {
    // Mostrar diálogo de progreso
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(
        downloadUrl: updateInfo['downloadUrl'],
      ),
    );
  }

  Future<void> _loadFavorites() async {
    await FavoritesService.loadFavorites();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('🔄 App lifecycle changed to: $state');

    if (state == AppLifecycleState.resumed) {
      // App volvió al primer plano
      print('✅ App resumed - No recargar datos, usar caché');

      // Verificar si todavía existe la URL M3U
      _checkM3uUrlExists();

      // NO recargar canales, ya están en memoria
      // Solo verificar si EPG necesita actualización
      if (EpgService.needsUpdate()) {
        print('📥 EPG necesita actualización, cargando en segundo plano...');
        EpgService.downloadAndParseEpg();
      }
    } else if (state == AppLifecycleState.paused) {
      // App fue a segundo plano
      print('⏸️ App paused');
    }
  }

  Future<void> _checkM3uUrlExists() async {
    final hasUrl = await M3UService.hasM3uUrl();
    if (!hasUrl && mounted) {
      print('⚠️ URL M3U eliminada - Volviendo a pantalla de configuración');
      // Si no hay URL, volver a la pantalla de configuración inicial
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => M3uSetupScreen(
            onConfigured: () {
              // Recargar la app cuando se configure
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const MyApp()),
              );
            },
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _epgBlinkTimer?.cancel();
    _epgStatusTimer?.cancel(); // Cancelar timer de estado EPG
    super.dispose();
  }

  Future<void> _loadChannels() async {
    // Evitar cargas múltiples
    if (_hasLoadedOnce && channels.isNotEmpty) {
      print('✅ Canales ya cargados en memoria, reutilizando...');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Cargar canales M3U
      final loadedChannels = await M3UService.fetchChannels();

      setState(() {
        channels = loadedChannels;
        _filterChannels();
        isLoading = false;
        _hasLoadedOnce = true; // Marcar como cargado
      });

      print('✅ Canales cargados.');

      // Iniciar carga de EPG en segundo plano (no bloquea la UI)
      _loadEpgInBackground();

      // Pre-cargar partidos de fútbol en segundo plano
      _preloadFootballMatches();
    } catch (e) {
      print('❌ Error al cargar canales: $e');
      setState(() {
        error = _getUserFriendlyError(e.toString());
        isLoading = false;
      });
    }
  }

  // Manejar doble pulsación del botón atrás para salir
  void _handleBackPress() {
    final now = DateTime.now();

    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > _backPressThreshold) {
      // Primera pulsación o pasó mucho tiempo
      _lastBackPress = now;

      // Mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⬅️ Pulsa ATRÁS de nuevo para salir de la app',
            style: TextStyle(fontSize: 16),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      // Segunda pulsación dentro del tiempo límite - SALIR
      SystemNavigator.pop(); // Cierra la app
    }
  }

  // Convertir errores técnicos en mensajes amigables
  String _getUserFriendlyError(String technicalError) {
    if (technicalError.contains('Timeout')) {
      return 'La conexión está tardando demasiado.\nVerifica tu conexión a internet.';
    } else if (technicalError.contains('SocketException') ||
        technicalError.contains('Failed host lookup')) {
      return 'No hay conexión a internet.\nVerifica tu red y vuelve a intentar.';
    } else if (technicalError.contains('404')) {
      return 'El servidor no está disponible.\nInténtalo más tarde.';
    } else {
      return 'Error al cargar los canales.\n$technicalError';
    }
  }

  // Cargar EPG en segundo plano sin bloquear la UI
  Future<void> _loadEpgInBackground() async {
    print('📥 Iniciando carga de EPG en segundo plano...');
    try {
      await EpgService.downloadAndParseEpg();
      print('✅ EPG cargado exitosamente en segundo plano.');

      // Construir índice de programas para búsqueda
      _buildProgrammeIndex();
    } catch (e) {
      print('⚠️ Error al cargar EPG en segundo plano: $e');
      // No mostrar error al usuario, el EPG es opcional
    }
  }

  // Construir índice de programas para búsqueda rápida
  Future<void> _buildProgrammeIndex() async {
    if (_isProgrammeIndexBuilt || channels.isEmpty) return;

    print('🔍 Construyendo índice de programas para búsqueda...');
    final index = <String, List<ProgrammeSearchResult>>{};

    try {
      for (final channel in channels) {
        // Buscar canal EPG correspondiente
        final epgChannel = await EpgService.findMatchingEpgChannel(
          channel.name,
        );
        if (epgChannel == null) continue;

        // Obtener programa actual
        final currentProgramme = await EpgService.getCurrentProgramme(
          epgChannel.id,
        );
        if (currentProgramme != null) {
          final titleLower = currentProgramme.title.toLowerCase();
          final result = ProgrammeSearchResult(
            programme: currentProgramme,
            channel: channel,
            channelName: channel.name,
          );
          index.putIfAbsent(titleLower, () => []).add(result);
        }

        // Obtener próximos 3 programas
        final upcomingProgrammes = await EpgService.getUpcomingProgrammes(
          epgChannel.id,
          count: 3,
        );

        for (final programme in upcomingProgrammes) {
          final titleLower = programme.title.toLowerCase();
          final result = ProgrammeSearchResult(
            programme: programme,
            channel: channel,
            channelName: channel.name,
          );

          // Evitar duplicados del mismo canal
          final existingResults = index[titleLower] ?? [];
          final alreadyExists = existingResults.any(
            (r) => r.channel.streamUrl == channel.streamUrl,
          );

          if (!alreadyExists) {
            index.putIfAbsent(titleLower, () => []).add(result);
          }
        }
      }

      if (mounted) {
        setState(() {
          _programmeIndex = index;
          _isProgrammeIndexBuilt = true;
        });
      }

      print(
        '✅ Índice de programas construido: ${index.length} programas únicos',
      );
    } catch (e) {
      print('⚠️ Error al construir índice de programas: $e');
    }
  }

  // Pre-cargar partidos de fútbol en segundo plano
  Future<void> _preloadFootballMatches() async {
    print('⚽ Iniciando pre-carga de partidos de fútbol...');
    try {
      // Esperar a que el EPG esté cargado primero (con timeout de 30 segundos)
      final epgLoaded = await EpgService.waitForEpgLoad(
        timeout: const Duration(seconds: 30),
      );

      if (!epgLoaded) {
        print(
          '⚠️ EPG no se cargó a tiempo, no se pueden cargar partidos de fútbol',
        );
        return;
      }

      await FootballService.preloadFootballMatches(channels);
      print('✅ Partidos de fútbol pre-cargados exitosamente.');

      // Actualizar la vista si estamos en la categoría de Fútbol
      if (mounted && selectedCategory == 'Futbol') {
        setState(() {
          displayItems = FootballService.getCachedMatches();
        });
      }
    } catch (e) {
      print('⚠️ Error al pre-cargar partidos de fútbol: $e');
      // No mostrar error al usuario
    }
  }

  // Cargar partidos de fútbol inmediatamente (cuando el usuario selecciona la categoría)
  Future<void> _loadFootballMatchesNow() async {
    print('⚽ Cargando partidos de fútbol inmediatamente...');
    try {
      await FootballService.preloadFootballMatches(channels);

      // Actualizar la vista
      if (mounted && selectedCategory == 'Futbol') {
        setState(() {
          displayItems = FootballService.getCachedMatches();
        });
      }

      print('✅ Partidos de fútbol cargados: ${displayItems.length} partidos');
    } catch (e) {
      print('⚠️ Error al cargar partidos de fútbol: $e');
    }
  }

  // Actualizar canales y EPG
  Future<void> _refreshData() async {
    if (isRefreshing) return;

    setState(() {
      isRefreshing = true;
      isEpgLoaded = false;
      showEpgIndicator = true;
    });

    print('🔄 Iniciando actualización de datos...');

    try {
      // 1. Recargar canales M3U
      print('📥 Descargando lista de canales...');
      final loadedChannels = await M3UService.fetchChannels();

      setState(() {
        channels = loadedChannels;
        _filterChannels();
      });

      print('✅ Canales actualizados: ${channels.length} canales');

      // 2. Recargar EPG
      print('📥 Descargando EPG...');
      await EpgService.downloadAndParseEpg();
      print('✅ EPG actualizado');

      // 3. Recargar partidos de fútbol
      print('⚽ Actualizando partidos de fútbol...');
      await FootballService.reloadMatches(channels);

      // Si estamos en la sección de Futbol, actualizar la vista
      if (isShowingFootballMatches) {
        setState(() {
          displayItems = FootballService.getCachedMatches();
        });
      }

      print('✅ Partidos de fútbol actualizados');

      setState(() {
        isEpgLoaded = true;
        isRefreshing = false;
      });

      print('✅ Actualización completada exitosamente');

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Datos actualizados correctamente'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error al actualizar datos: $e');
      setState(() {
        isRefreshing = false;
      });

      // Mostrar mensaje de error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al actualizar: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Verificar periódicamente el estado del EPG
  void _checkEpgStatus() {
    // Cancelar timer anterior si existe
    _epgStatusTimer?.cancel();

    _epgStatusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final stats = EpgService.getStats();
      final wasLoaded = isEpgLoaded;
      final newIsLoaded = stats['programmes'] > 0;

      if (newIsLoaded != wasLoaded) {
        setState(() {
          isEpgLoaded = newIsLoaded;
        });

        // Si acaba de cargarse, iniciar parpadeo
        if (isEpgLoaded) {
          _startEpgBlink();
        }
      }
    });
  }

  // Iniciar animación de parpadeo del indicador EPG
  void _startEpgBlink() {
    _epgBlinkTimer?.cancel();
    _epgBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        showEpgIndicator = !showEpgIndicator;
      });
    });
  }

  void _filterChannels() {
    if (selectedCategory == 'Futbol') {
      // Mostrar partidos de fútbol en lugar de canales
      isShowingFootballMatches = true;
      displayItems = FootballService.getCachedMatches();
      filteredChannels = []; // No hay canales filtrados

      // Si no hay partidos cargados y no está cargando, cargar ahora
      if (displayItems.isEmpty &&
          !FootballService.isLoading() &&
          !FootballService.isLoaded()) {
        print('⚽ Partidos de fútbol no cargados, cargando ahora...');
        _loadFootballMatchesNow();
      }
    } else {
      // Mostrar canales normalmente
      isShowingFootballMatches = false;

      if (selectedCategory == 'Todos') {
        filteredChannels = channels;
      } else if (selectedCategory == 'Deportes') {
        filteredChannels = channels.where((channel) {
          final group = channel.group.toUpperCase();
          return group.contains('LA LIGA') ||
              group.contains('DAZN') ||
              group.contains('FORMULA 1') ||
              group.contains('HYPERMOTION') ||
              group.contains('LIGA DE CAMPEONES') ||
              group.contains('EUROSPORT') ||
              group.contains('FUTBOL') ||
              group.contains('DEPORTES') ||
              group.contains('SPORT') ||
              group.contains('UFC') ||
              group.contains('TENNIS') ||
              group.contains('NBA') ||
              group.contains('MOTOR') ||
              group.contains('BUNDESLIGA') ||
              group.contains('1RFEF');
        }).toList();
      } else if (selectedCategory == 'Entretenimiento') {
        filteredChannels = channels.where((channel) {
          final group = channel.group.toUpperCase();
          return group.contains('MOVISTAR') ||
              group.contains('TDT') ||
              group.contains('OTROS');
        }).toList();
      }

      // Aplicar filtro de favoritos si está activo
      if (isShowingFavorites) {
        final favoriteChannels = FavoritesService.getFavorites();
        filteredChannels = filteredChannels.where((channel) {
          return favoriteChannels.any(
            (fav) => fav.streamUrl == channel.streamUrl,
          );
        }).toList();
      }

      // Aplicar búsqueda si está activa
      if (isSearching && searchQuery.isNotEmpty) {
        filteredChannels = _searchChannelsAndProgrammes(
          filteredChannels,
          searchQuery,
        );

        // Si hay resultados de programas, mostrarlos en lugar de canales normales
        if (_isShowingProgrammeResults && _searchProgrammeResults.isNotEmpty) {
          displayItems = _searchProgrammeResults;
        } else {
          displayItems = filteredChannels;
        }
      } else {
        displayItems = filteredChannels;
        _isShowingProgrammeResults = false;
        _searchProgrammeResults = [];
      }
    }
  }

  // Buscar en canales y programas EPG
  List<Channel> _searchChannelsAndProgrammes(
    List<Channel> channelsList,
    String query,
  ) {
    final queryLower = query.toLowerCase();
    final matchingChannels = <Channel>{}; // Usar Set para evitar duplicados
    final matchingProgrammes = <ProgrammeSearchResult>[];

    // 1. Buscar en nombres de canales
    for (final channel in channelsList) {
      if (channel.name.toLowerCase().contains(queryLower)) {
        matchingChannels.add(channel);
      }
    }

    // 2. Buscar en grupos de canales
    for (final channel in channelsList) {
      if (channel.group.toLowerCase().contains(queryLower)) {
        matchingChannels.add(channel);
      }
    }

    // 3. Buscar en programas EPG (usando el índice pre-construido)
    if (_isProgrammeIndexBuilt && _programmeIndex.isNotEmpty) {
      // Buscar en títulos de programas
      for (final entry in _programmeIndex.entries) {
        final programmeTitle = entry.key;
        final programmeResults = entry.value;

        if (programmeTitle.contains(queryLower)) {
          // Añadir resultados de programas que están en la lista filtrada
          for (final result in programmeResults) {
            if (channelsList.contains(result.channel)) {
              matchingProgrammes.add(result);
            }
          }
        }
      }
    }

    // Si encontramos programas, mostrar vista de programas (como en Fútbol)
    if (matchingProgrammes.isNotEmpty) {
      _searchProgrammeResults = matchingProgrammes;
      _isShowingProgrammeResults = true;
    } else {
      _searchProgrammeResults = [];
      _isShowingProgrammeResults = false;
    }

    return matchingChannels.toList();
  }

  void _onCategorySelected(String category) {
    setState(() {
      selectedCategory = category;
      selectedCategoryIndex = categories.indexOf(category);
      selectedChannelIndex = 0; // Reset selection when changing category
      startRowIndex = 0; // Reset scroll when changing category
      isNavigatingCategories = false; // Volver a navegar canales
      _filterChannels();
    });
  }

  // Alternar modo de búsqueda
  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        searchQuery = '';
        _searchController.clear();
        _filterChannels();
      } else {
        // Solicitar foco al campo de búsqueda después de que se construya
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }

  // Alternar vista de favoritos
  void _toggleFavoritesView() {
    setState(() {
      isShowingFavorites = !isShowingFavorites;
      selectedChannelIndex = 0;
      startRowIndex = 0;
      _filterChannels();
    });
  }

  // Obtener items visibles según el scroll actual (canales, partidos o programas)
  List<dynamic> get visibleItems {
    final items = (isShowingFootballMatches || _isShowingProgrammeResults)
        ? displayItems
        : filteredChannels;
    if (!isAndroidTV || items.isEmpty) return items;

    final int totalItems = items.length;
    final int maxVisibleItems =
        tvColumns * currentTvRows; // Usar filas dinámicas
    final int startIndex = startRowIndex * tvColumns;
    final int endIndex = (startIndex + maxVisibleItems).clamp(0, totalItems);

    if (startIndex >= totalItems) return [];
    return items.sublist(startIndex, endIndex);
  }

  // Mantener compatibilidad con código existente
  List<Channel> get visibleChannels =>
      visibleItems.whereType<Channel>().toList();

  // Obtener la posición real del canal seleccionado en el grid visible
  int get visibleSelectedIndex {
    if (!isAndroidTV) return selectedChannelIndex;
    return selectedChannelIndex - (startRowIndex * tvColumns);
  }

  void _handleKeyEvent(KeyEvent event) async {
    print('Key event: ${event.logicalKey}'); // Debug
    if (event is KeyDownEvent) {
      // Manejar botón ATRÁS (solo si NO está en modo búsqueda, ya se maneja en onKeyEvent)
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        // Si no hay búsqueda activa, intentar salir de la app
        if (!isSearching) {
          _handleBackPress();
        }
        return;
      }

      // En Android TV, las teclas del control remoto ya vienen correctamente mapeadas
      // NO necesitamos hacer ninguna transformación
      print('Navigating categories: $isNavigatingCategories'); // Debug

      if (isNavigatingCategories) {
        // NAVEGACIÓN EN CATEGORÍAS Y BOTONES
        // Estamos en los botones (search, favorites, refresh o settings)
        if (isSearchButtonSelected ||
            isFavoritesButtonSelected ||
            isRefreshButtonSelected ||
            isSettingsButtonSelected) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            setState(() {
              if (isSettingsButtonSelected) {
                // De settings a refresh
                isSettingsButtonSelected = false;
                isRefreshButtonSelected = true;
              } else if (isRefreshButtonSelected) {
                // De refresh a favorites
                isRefreshButtonSelected = false;
                isFavoritesButtonSelected = true;
              } else if (isFavoritesButtonSelected) {
                // De favorites a search
                isFavoritesButtonSelected = false;
                isSearchButtonSelected = true;
              } else {
                // De search a categorías
                isSearchButtonSelected = false;
                selectedCategoryIndex = categories.length - 1;
              }
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            setState(() {
              if (isSearchButtonSelected) {
                // De search a favorites
                isSearchButtonSelected = false;
                isFavoritesButtonSelected = true;
              } else if (isFavoritesButtonSelected) {
                // De favorites a refresh
                isFavoritesButtonSelected = false;
                isRefreshButtonSelected = true;
              } else if (isRefreshButtonSelected) {
                // De refresh a settings
                isRefreshButtonSelected = false;
                isSettingsButtonSelected = true;
              }
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              // Bajar a los canales
              isNavigatingCategories = false;
              isSearchButtonSelected = false;
              isFavoritesButtonSelected = false;
              isRefreshButtonSelected = false;
              isSettingsButtonSelected = false;
              selectedChannelIndex = 0;
            });
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            if (isSearchButtonSelected) {
              // Alternar búsqueda
              _toggleSearch();
            } else if (isFavoritesButtonSelected) {
              // Alternar vista de favoritos
              _toggleFavoritesView();
            } else if (isRefreshButtonSelected) {
              // Ejecutar actualización
              _refreshData();
            } else if (isSettingsButtonSelected) {
              // Abrir configuración
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              // Verificar si todavía existe URL M3U al volver
              _checkM3uUrlExists();
            }
          }
        } else {
          // Estamos en las categorías
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            setState(() {
              if (selectedCategoryIndex < categories.length - 1) {
                selectedCategoryIndex++;
              } else {
                // Saltar al botón de búsqueda
                isSearchButtonSelected = true;
              }
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            setState(() {
              if (selectedCategoryIndex > 0) {
                selectedCategoryIndex--;
              }
            });
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              // Bajar a los canales
              isNavigatingCategories = false;
              selectedChannelIndex = 0;
            });
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            // Seleccionar categoría
            _onCategorySelected(categories[selectedCategoryIndex]);
          }
        }
      } else {
        // NAVEGACIÓN EN CANALES, PARTIDOS O PROGRAMAS
        final items = (isShowingFootballMatches || _isShowingProgrammeResults)
            ? displayItems
            : filteredChannels;
        if (items.isEmpty) return;

        final crossAxisCount = isAndroidTV ? tvColumns : 4;
        final totalItems = items.length;
        final currentRow = selectedChannelIndex ~/ crossAxisCount;
        final currentCol = selectedChannelIndex % crossAxisCount;
        final visibleRow =
            currentRow - startRowIndex; // Fila dentro del área visible

        print(
          'Current position: Row $currentRow, Col $currentCol, VisibleRow $visibleRow',
        ); // Debug

        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() {
            if (currentCol < crossAxisCount - 1) {
              final newIndex = selectedChannelIndex + 1;
              if (newIndex < totalItems) {
                selectedChannelIndex = newIndex;
              }
            }
          });
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() {
            if (currentCol > 0) {
              selectedChannelIndex = selectedChannelIndex - 1;
            }
          });
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            final newIndex = selectedChannelIndex + crossAxisCount;
            if (newIndex < totalItems) {
              selectedChannelIndex = newIndex;
              final newRow = newIndex ~/ crossAxisCount;
              final newVisibleRow = newRow - startRowIndex;

              // Scroll automático hacia abajo si la nueva fila no es visible
              if (isAndroidTV && newVisibleRow >= currentTvRows) {
                final maxStartRow =
                    (((totalItems - 1) ~/ crossAxisCount) - currentTvRows + 1)
                        .clamp(0, double.infinity)
                        .toInt();
                if (startRowIndex < maxStartRow) {
                  startRowIndex++;
                }
              }
            }
          });
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            if (currentRow > 0) {
              // Calcular la nueva posición ANTES de mover
              final newIndex = selectedChannelIndex - crossAxisCount;
              final newRow = newIndex ~/ crossAxisCount;
              final newVisibleRow = newRow - startRowIndex;

              // Scroll automático hacia arriba si la nueva fila no será visible
              if (isAndroidTV && newVisibleRow < 0 && startRowIndex > 0) {
                startRowIndex--;
              }

              // Ahora sí mover el selector
              selectedChannelIndex = newIndex;
            } else {
              // Subir a las categorías
              isNavigatingCategories = true;
              selectedCategoryIndex = categories.indexOf(selectedCategory);
            }
          });
        } else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.space) {
          print('Enter/Space pressed'); // Debug
          if (selectedChannelIndex < items.length) {
            if (isShowingFootballMatches) {
              // Abrir canal del partido seleccionado
              final match = items[selectedChannelIndex] as FootballMatch;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ChannelDetailScreen(channel: match.channel),
                ),
              );
            } else if (_isShowingProgrammeResults) {
              // Abrir canal del programa de búsqueda seleccionado
              final result =
                  items[selectedChannelIndex] as ProgrammeSearchResult;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      ChannelDetailScreen(channel: result.channel),
                ),
              );
            } else {
              // Abrir canal normal
              final channel = items[selectedChannelIndex] as Channel;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ChannelDetailScreen(channel: channel),
                ),
              );
            }
          }
        }
      }
    }
  }

  // Construir tarjeta de programa de búsqueda
  Widget _buildProgrammeCard(dynamic item, int actualIndex) {
    final result = item as ProgrammeSearchResult;
    final isSelected =
        !isNavigatingCategories && selectedChannelIndex == actualIndex;
    final timeFormat = DateFormat('HH:mm');

    return GestureDetector(
      onTap: () {
        setState(() => selectedChannelIndex = actualIndex);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChannelDetailScreen(channel: result.channel),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Póster del programa
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    child: result.programme.iconUrl != null
                        ? CachedNetworkImage(
                            imageUrl: result.programme.iconUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(
                                  Icons.tv,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(
                                  Icons.tv,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.tv,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                  // Badge EN VIVO
                  if (result.programme.isLive)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'EN VIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Hora
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        timeFormat.format(result.programme.start),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Información del programa
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.programme.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.channelName,
                    style: TextStyle(color: Colors.grey[400], fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construir tarjeta de partido de fútbol
  Widget _buildFootballMatchCard(dynamic item, int actualIndex) {
    final match = item as FootballMatch;
    final isSelected =
        !isNavigatingCategories && selectedChannelIndex == actualIndex;
    final timeFormat = DateFormat('HH:mm');

    return GestureDetector(
      onTap: () {
        setState(() => selectedChannelIndex = actualIndex);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChannelDetailScreen(channel: match.channel),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue, width: 3) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Póster del partido
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    child: match.programme.iconUrl != null
                        ? CachedNetworkImage(
                            imageUrl: match.programme.iconUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(
                                  Icons.sports_soccer,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Center(
                                child: Icon(
                                  Icons.sports_soccer,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.sports_soccer,
                                color: Colors.grey,
                                size: 40,
                              ),
                            ),
                          ),
                  ),
                  // Badge EN VIVO
                  if (match.programme.isLive)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'EN VIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Hora
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        timeFormat.format(match.programme.start),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Información del partido
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.programme.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    match.channelName,
                    style: TextStyle(color: Colors.grey[400], fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _LoadingScreen();
    }

    if (error != null) {
      return _ErrorScreen(
        error: error!,
        onRetry: () {
          setState(() {
            isLoading = true;
            error = null;
          });
          _loadChannels();
        },
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        // Manejar botón ATRÁS incluso si el campo de búsqueda tiene el foco
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack)) {
          if (isSearching) {
            _toggleSearch();
            return KeyEventResult.handled;
          }
        }
        
        // Si el campo de búsqueda tiene el foco, ignorar otros eventos para permitir escribir
        if (_searchFocusNode.hasFocus) {
          return KeyEventResult.ignored;
        }
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Grid de canales (fondo completo)
              LayoutBuilder(
                builder: (context, constraints) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final screenWidth = MediaQuery.of(context).size.width;

                  // Configuración de espaciado
                  final horizontalPadding = 8.0;
                  final crossAxisSpacing = isAndroidTV ? 10.0 : 8.0;
                  final mainAxisSpacing = isAndroidTV ? 10.0 : 8.0;
                  final crossAxisCount = isAndroidTV ? tvColumns : 4;

                  // Calcular espacios basados en porcentajes (mantener estética actual)
                  final topPadding =
                      100.0; // Mantener los 100px para la máscara
                  final bottomPadding =
                      8.0; // Reducido para aprovechar mejor el espacio
                  final availableHeight =
                      screenHeight - topPadding - bottomPadding;

                  // SIEMPRE mostrar 3 filas completas
                  final visibleRows = 3.0;

                  // Calcular altura por fila
                  final totalMainSpacing = mainAxisSpacing * (visibleRows - 1);
                  final rowHeight =
                      (availableHeight - totalMainSpacing) / visibleRows;

                  // Calcular ancho por item
                  final totalCrossSpacing =
                      crossAxisSpacing * (crossAxisCount - 1);
                  final itemWidth =
                      (screenWidth -
                          (horizontalPadding * 2) -
                          totalCrossSpacing) /
                      crossAxisCount;

                  // Calcular childAspectRatio dinámicamente
                  final childAspectRatio = itemWidth / rowHeight;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: GridView.builder(
                      padding: EdgeInsets.only(
                        top: topPadding,
                        bottom: bottomPadding,
                      ),
                      physics:
                          const NeverScrollableScrollPhysics(), // Desactivar scroll nativo
                      cacheExtent:
                          500, // Pre-renderizar items fuera de pantalla
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: crossAxisSpacing,
                        mainAxisSpacing: mainAxisSpacing,
                        childAspectRatio: childAspectRatio,
                      ),
                      itemCount: isAndroidTV
                          ? visibleItems.length
                          : displayItems.length,
                      itemBuilder: (context, index) {
                        final itemsList = isAndroidTV
                            ? visibleItems
                            : displayItems;
                        final item = itemsList[index];
                        final actualIndex = isAndroidTV
                            ? (startRowIndex * tvColumns) + index
                            : index;

                        // Construir tarjeta según el tipo de item
                        if (isShowingFootballMatches) {
                          return _buildFootballMatchCard(item, actualIndex);
                        } else if (_isShowingProgrammeResults) {
                          return _buildProgrammeCard(item, actualIndex);
                        } else {
                          return ChannelCard(
                            channel: item as Channel,
                            isSelected:
                                !isNavigatingCategories &&
                                selectedChannelIndex == actualIndex,
                            onFocusChange: (hasFocus) {
                              if (hasFocus) {
                                setState(() {
                                  selectedChannelIndex = actualIndex;
                                });
                              }
                            },
                          );
                        }
                      },
                    ),
                  );
                },
              ),
              // Gradiente superior para efecto de desvanecimiento
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Barra de navegación flotante (encima del gradiente)
              Positioned(
                top: 16.0,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Categorías centradas
                    Container(
                      margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30.0),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: categories.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value;
                          final isSelected = selectedCategory == category;
                          final isHighlighted =
                              isNavigatingCategories &&
                              selectedCategoryIndex == index &&
                              !isSearchButtonSelected &&
                              !isFavoritesButtonSelected &&
                              !isRefreshButtonSelected &&
                              !isSettingsButtonSelected;
                          return GestureDetector(
                            onTap: () => _onCategorySelected(entry.value),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(25.0),
                                border: isHighlighted
                                    ? Border.all(color: Colors.blue, width: 2)
                                    : isSelected
                                    ? Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Text(
                                entry.value,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[400],
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Botón de búsqueda expandible
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: isSearching ? 400 : 48,
                      height: 48,
                      margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                      decoration: BoxDecoration(
                        color: isSearching
                            ? Colors.black.withOpacity(0.7)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24.0),
                        border: isSearchButtonSelected || isSearching
                            ? Border.all(
                                color: Colors.blue,
                                width: isSearching ? 2 : 2,
                              )
                            : Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: isSearching
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.black.withOpacity(0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: isSearching
                          ? Row(
                              children: [
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.search,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _searchFocusNode,
                                    autofocus: true,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Buscar canales...',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        searchQuery = value;
                                        _filterChannels();
                                      });
                                    },
                                  ),
                                ),
                                if (searchQuery.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${filteredChannels.length}',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                  onPressed: _toggleSearch,
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                            )
                          : Center(
                              child: IconButton(
                                onPressed: _toggleSearch,
                                icon: const Icon(
                                  Icons.search,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                    ),
                    if (!isSearching) ...[
                      const SizedBox(width: 8),
                      // Botón de favoritos
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                        decoration: BoxDecoration(
                          color: isShowingFavorites
                              ? Colors.pink.withOpacity(0.3)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24.0),
                          border: isFavoritesButtonSelected
                              ? Border.all(color: Colors.blue, width: 2)
                              : Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: IconButton(
                            onPressed: _toggleFavoritesView,
                            icon: Icon(
                              isShowingFavorites
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isShowingFavorites
                                  ? Colors.pink
                                  : Colors.white,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón de actualizar
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24.0),
                          border: isRefreshButtonSelected
                              ? Border.all(color: Colors.blue, width: 2)
                              : Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: IconButton(
                            onPressed: isRefreshing ? null : _refreshData,
                            icon: isRefreshing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.refresh,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Botón de configuraciones
                      Container(
                        width: 48,
                        height: 48,
                        margin: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24.0),
                          border: isSettingsButtonSelected
                              ? Border.all(color: Colors.blue, width: 2)
                              : Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: IconButton(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                              // Verificar si todavía existe URL M3U al volver
                              _checkM3uUrlExists();
                            },
                            icon: const Icon(
                              Icons.settings,
                              color: Colors.white,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Indicador EPG en la esquina superior derecha
              Positioned(
                top: 8.0,
                right: 8.0,
                child: AnimatedOpacity(
                  opacity: isRefreshing
                      ? 0.3
                      : (isEpgLoaded && showEpgIndicator ? 1.0 : 0.3),
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(
                        color: isRefreshing
                            ? Colors.orange.withOpacity(0.6)
                            : (isEpgLoaded
                                  ? Colors.purple.withOpacity(0.6)
                                  : Colors.grey.withOpacity(0.3)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRefreshing)
                          Container(
                            width: 12,
                            height: 12,
                            margin: const EdgeInsets.only(right: 4),
                            child: const CircularProgressIndicator(
                              color: Colors.orange,
                              strokeWidth: 2,
                            ),
                          )
                        else if (isEpgLoaded)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          'EPG',
                          style: TextStyle(
                            color: isEpgLoaded
                                ? Colors.purple
                                : Colors.grey.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChannelCard extends StatelessWidget {
  final Channel channel;
  final bool isSelected;
  final Function(bool)? onFocusChange;

  const ChannelCard({
    super.key,
    required this.channel,
    this.isSelected = false,
    this.onFocusChange,
  });

  void _navigateToPlayer(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChannelDetailScreen(channel: channel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: onFocusChange,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            _navigateToPlayer(context);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.contextMenu) {
            _showChannelInfo(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _navigateToPlayer(context),
        onLongPress: () => _showChannelInfo(context),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[700]!,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      channel.logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.tv,
                            color: Colors.grey,
                            size: 32,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    channel.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChannelInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (channel.logoUrl.isNotEmpty)
                  Center(
                    child: Image.network(
                      channel.logoUrl,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.tv,
                          color: Colors.grey,
                          size: 64,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Categoría: ${channel.group}',
                  style: TextStyle(color: Colors.grey[300]),
                ),
                const SizedBox(height: 8),
                Text(
                  'ID: ${channel.id}',
                  style: TextStyle(color: Colors.grey[300]),
                ),
                const SizedBox(height: 8),
                Text(
                  'URL: ${channel.streamUrl}',
                  style: TextStyle(color: Colors.grey[300], fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24.0,
                        vertical: 12.0,
                      ),
                    ),
                    child: const Text(
                      'Cerrar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Widget extraído para pantalla de carga
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// Widget extraído para pantalla de error
class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorScreen({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 24),
              Text(
                error,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget para mostrar progreso de descarga de actualización
class _DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;

  const _DownloadProgressDialog({required this.downloadUrl});

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  bool _isDownloading = true;
  String _status = 'Descargando actualización...';

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    final success = await UpdateService.downloadAndInstall(
      downloadUrl: widget.downloadUrl,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _status = success 
            ? '✅ Actualización lista para instalar' 
            : '❌ Error al descargar';
      });

      if (success) {
        // Cerrar diálogo después de 2 segundos
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      title: const Row(
        children: [
          Icon(Icons.download, color: Colors.blue, size: 28),
          SizedBox(width: 12),
          Text(
            'Actualizando',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isDownloading) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[800],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 16),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _status,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

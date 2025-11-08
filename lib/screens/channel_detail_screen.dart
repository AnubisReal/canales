import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/channel.dart';
import '../models/epg_channel.dart';
import '../models/epg_programme.dart';
import '../services/epg_service.dart';
import '../services/acestream_service.dart';
import '../services/video_intent_service.dart';
import '../services/settings_service.dart';
import '../services/player_service.dart';
import '../services/favorites_service.dart';

class ChannelDetailScreen extends StatefulWidget {
  final Channel channel;

  const ChannelDetailScreen({super.key, required this.channel});

  @override
  State<ChannelDetailScreen> createState() => _ChannelDetailScreenState();
}

class _ChannelDetailScreenState extends State<ChannelDetailScreen> with SingleTickerProviderStateMixin {
  bool _isLoadingStream = true;
  bool _hasStreamError = false;
  String? _errorMessage;
  String? _acestreamHash;
  String? _playbackUrl;
  WebViewController? _webViewController;
  bool _showWebPlayer = false;

  EpgChannel? _epgChannel;
  EpgProgramme? _currentProgramme;
  List<EpgProgramme> _upcomingProgrammes = [];
  EpgProgramme? _displayedProgramme; // Programa que se muestra en la vista principal

  // Navegación por teclado
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0; // 0 = play button, 1+ = upcoming programmes
  int _programmeStartIndex = 0; // Índice de inicio de la ventana de programas visibles
  final int _visibleProgrammesCount = 4; // Número de programas visibles a la vez
  
  // Navegación en barra superior
  bool _isNavigatingTopBar = false; // true = navegando en barra superior
  int _topBarSelectedIndex = 0; // 0 = botón atrás, 1 = botón favoritos
  
  // Variables para doble pulsación de atrás
  DateTime? _lastBackPress;
  static const _backPressThreshold = Duration(seconds: 2);
  
  // Estado de favorito
  bool _isFavorite = false;
  
  // Animación para el badge EN VIVO
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    
    // Inicializar animación de parpadeo
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_blinkController);
    
    _loadEpgData();
    _checkFavoriteStatus();
    // NO iniciar Acestream automáticamente
    setState(() {
      _isLoadingStream = false;
    });
  }

  void _checkFavoriteStatus() {
    setState(() {
      _isFavorite = FavoritesService.isFavorite(widget.channel);
    });
  }

  Future<void> _toggleFavorite() async {
    final newStatus = await FavoritesService.toggleFavorite(widget.channel);
    setState(() {
      _isFavorite = newStatus;
    });
    
    // Mostrar mensaje
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? '❤️ Añadido a favoritos' : '💔 Eliminado de favoritos',
            style: const TextStyle(fontSize: 16),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: newStatus ? Colors.pink : Colors.grey[800],
        ),
      );
    }
  }

  Future<void> _loadEpgData() async {
    // Buscar canal EPG que coincida (ahora es async)
    _epgChannel = await EpgService.findMatchingEpgChannel(widget.channel.id);

    if (_epgChannel != null) {
      // Obtener programa actual
      _currentProgramme = await EpgService.getCurrentProgramme(_epgChannel!.id);

      // Obtener próximos programas (cargar más para permitir scroll)
      _upcomingProgrammes = await EpgService.getUpcomingProgrammes(
        _epgChannel!.id,
        count: 20,
      );

      // Inicializar el programa mostrado con el programa actual
      _displayedProgramme = _currentProgramme;

      setState(() {});
    }
  }

  void _checkAcestreamAndInitialize() async {
    try {
      _acestreamHash = AcestreamService.extractAcestreamHash(
        widget.channel.streamUrl,
      );

      if (_acestreamHash == null) {
        setState(() {
          _isLoadingStream = false;
          _hasStreamError = true;
          _errorMessage = 'URL de Acestream no válida';
        });
        return;
      }

      setState(() {
        _errorMessage = 'Verificando motor Acestream...';
      });

      final isRunning = await AcestreamService.isAcestreamEngineRunning();

      if (!isRunning) {
        setState(() {
          _isLoadingStream = false;
          _hasStreamError = true;
          _errorMessage = 'Motor Acestream no está corriendo';
        });
        return;
      }

      setState(() {
        _errorMessage = 'Iniciando stream...';
      });

      _playbackUrl = await AcestreamService.startAcestreamStream(
        _acestreamHash!,
      );

      if (_playbackUrl != null) {
        setState(() {
          _isLoadingStream = false;
          _hasStreamError = false;
        });
        _initializeWebPlayer();
      } else {
        setState(() {
          _isLoadingStream = false;
          _hasStreamError = true;
          _errorMessage = 'No se pudo iniciar el stream';
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingStream = false;
        _hasStreamError = true;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _initializeWebPlayer() {
    if (_playbackUrl != null) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(_buildPlayerHtml());

      setState(() {
        _showWebPlayer = true;
      });
    }
  }

  String _buildPlayerHtml() {
    return '''
      <!DOCTYPE html>
      <html>
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
              body {
                  margin: 0;
                  padding: 0;
                  background-color: #000;
                  display: flex;
                  justify-content: center;
                  align-items: center;
                  height: 100vh;
              }
              video {
                  width: 100%;
                  height: 100%;
                  max-width: 100vw;
                  max-height: 100vh;
              }
          </style>
      </head>
      <body>
          <video controls autoplay>
              <source src="$_playbackUrl" type="application/x-mpegURL">
              <source src="$_playbackUrl" type="video/mp4">
          </video>
      </body>
      </html>
    ''';
  }

  void _openInExternalPlayer() async {
    if (_playbackUrl == null) return;
    
    // Cargar configuración del reproductor por defecto
    await SettingsService.loadDefaultPlayer();
    final defaultPlayer = SettingsService.defaultPlayerPackage;
    
    print('🎬 Abriendo con reproductor: ${defaultPlayer.isEmpty ? "Selector del sistema" : defaultPlayer}');
    
    if (defaultPlayer.isEmpty) {
      // Preguntar siempre - usar selector del sistema (intent implícito)
      final uri = Uri.parse(_playbackUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      // Usar reproductor específico
      final success = await PlayerService.openWithPlayer(_playbackUrl!, defaultPlayer);
      
      if (!success) {
        // Si falla, intentar con el selector del sistema como fallback
        print('⚠️ Fallback al selector del sistema');
        final uri = Uri.parse(_playbackUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    if (_acestreamHash != null) {
      AcestreamService.stopAcestreamStream(_acestreamHash!);
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Manejar botón ATRÁS con doble pulsación
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _handleBackPress();
        return;
      }
      
      // En Android TV, las teclas del control remoto ya vienen correctamente mapeadas
      // NO necesitamos hacer ninguna transformación
      
      if (_isNavigatingTopBar) {
        // NAVEGACIÓN EN BARRA SUPERIOR
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() {
            if (_topBarSelectedIndex == 0) {
              _topBarSelectedIndex = 1; // De atrás a favoritos
            }
          });
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() {
            if (_topBarSelectedIndex == 1) {
              _topBarSelectedIndex = 0; // De favoritos a atrás
            }
          });
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            // Bajar a la zona de reproducción
            _isNavigatingTopBar = false;
            _selectedIndex = 0;
          });
        } else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.space) {
          if (_topBarSelectedIndex == 0) {
            // Botón atrás
            Navigator.of(context).pop();
          } else {
            // Botón favoritos
            _toggleFavorite();
          }
        }
      } else {
        // NAVEGACIÓN EN ZONA DE REPRODUCCIÓN Y PROGRAMAS
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            if (_selectedIndex == 0) {
              // Desde el botón play, subir a la barra superior
              _isNavigatingTopBar = true;
              _topBarSelectedIndex = 0; // Empezar en botón atrás
            }
          });
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          setState(() {
            if (_selectedIndex == 0) {
              // Desde el botón play, ir al primer programa
              _selectedIndex = 1;
              _displayedProgramme = _upcomingProgrammes.isNotEmpty ? _upcomingProgrammes[0] : _currentProgramme;
            } else {
              // Navegar entre programas
              final programIndex = _selectedIndex - 1;
              if (programIndex < _upcomingProgrammes.length - 1) {
                _selectedIndex++;
                _displayedProgramme = _upcomingProgrammes[programIndex + 1];
                
                // Scroll automático si el programa no es visible
                final visibleIndex = programIndex - _programmeStartIndex;
                if (visibleIndex >= _visibleProgrammesCount - 1) {
                  final maxStartIndex = _upcomingProgrammes.length - _visibleProgrammesCount;
                  if (_programmeStartIndex < maxStartIndex) {
                    _programmeStartIndex++;
                  }
                }
              }
            }
          });
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          setState(() {
            if (_selectedIndex > 0) {
              _selectedIndex--;
              
              // Actualizar el programa mostrado
              if (_selectedIndex == 0) {
                // Volver al botón play, mostrar programa actual
                _displayedProgramme = _currentProgramme;
              } else {
                // Mostrar el programa próximo seleccionado
                final programIndex = _selectedIndex - 1;
                _displayedProgramme = _upcomingProgrammes[programIndex];
              }
              
              // Scroll automático hacia la izquierda si es necesario
              if (_selectedIndex > 0) {
                final programIndex = _selectedIndex - 1;
                final visibleIndex = programIndex - _programmeStartIndex;
                if (visibleIndex < 0 && _programmeStartIndex > 0) {
                  _programmeStartIndex--;
                }
              }
            }
            // No hacer nada si ya está en el primer elemento
          });
        } else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.space) {
          _onSelectItem();
        }
      }
    }
  }

  void _onSelectItem() {
    if (_selectedIndex == 0) {
      // Botón play seleccionado - Mostrar diálogo con reproductores externos
      _showPlayerSelectionDialog();
    }
    // Los demás items (programas próximos) solo son informativos
  }

  // Manejar doble pulsación del botón atrás para volver
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
            '⬅️ Pulsa ATRÁS de nuevo para volver',
            style: TextStyle(fontSize: 16),
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      // Segunda pulsación dentro del tiempo límite - VOLVER
      Navigator.of(context).pop();
    }
  }

  void _showPlayerSelectionDialog() async {
    // El enlace del M3U ya es la URL HTTP del Acestream Engine
    // Ejemplo: http://127.0.0.1:6878/ace/getstream?id=xxxxx
    final streamUrl = widget.channel.streamUrl;
    
    if (!streamUrl.startsWith('http://127.0.0.1:6878/')) {
      _showErrorDialog('URL de stream no válida');
      return;
    }

    try {
      // Cargar configuración del reproductor por defecto
      await SettingsService.loadDefaultPlayer();
      final defaultPlayer = SettingsService.defaultPlayerPackage;
      
      print('🎬 Abriendo con reproductor: ${defaultPlayer.isEmpty ? "Selector del sistema" : defaultPlayer}');
      
      bool success = false;
      
      if (defaultPlayer.isEmpty) {
        // Preguntar siempre - usar selector del sistema (intent implícito)
        success = await VideoIntentService.openVideoWithIntent(streamUrl);
      } else {
        // Usar reproductor específico configurado
        success = await PlayerService.openWithPlayer(streamUrl, defaultPlayer);
        
        if (!success) {
          // Si falla el reproductor específico, intentar con el selector del sistema como fallback
          print('⚠️ Fallback al selector del sistema');
          success = await VideoIntentService.openVideoWithIntent(streamUrl);
        }
      }

      // Solo mostrar error si realmente falló (no se pudo lanzar ningún Intent)
      if (!success) {
        _showErrorDialog(
          'Error al abrir el reproductor.\n\n'
          'Verifica que Acestream Engine esté corriendo y que tengas '
          'reproductores de video instalados (VLC, MX Player, Ace Stream Player, etc.)'
        );
      }
    } catch (e) {
      _showErrorDialog('Error al abrir reproductor:\n$e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Error',
            style: TextStyle(color: Colors.red),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Información del EPG (pantalla completa)
              _buildEpgInfo(),

              // Barra superior con botón de regreso
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      // Botón atrás con indicador de selección
                      Container(
                        decoration: BoxDecoration(
                          border: _isNavigatingTopBar && _topBarSelectedIndex == 0
                              ? Border.all(color: Colors.blue, width: 3)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.channel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Botón de favoritos con indicador de selección
                      Container(
                        decoration: BoxDecoration(
                          border: _isNavigatingTopBar && _topBarSelectedIndex == 1
                              ? Border.all(color: Colors.blue, width: 3)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: _toggleFavorite,
                          icon: Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.pink : Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Reproductor en pantalla completa cuando está activo
              if (_showWebPlayer && _webViewController != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black,
                    child: WebViewWidget(controller: _webViewController!),
                  ),
                ),

              // Indicador de carga
              if (_isLoadingStream)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),

              // Error
              if (_hasStreamError && _errorMessage != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _hasStreamError = false;
                                _errorMessage = null;
                              });
                            },
                            child: const Text('Cerrar'),
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

  Widget _buildEpgInfo() {
    if (_epgChannel == null || _displayedProgramme == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, color: Colors.grey[600], size: 64),
            const SizedBox(height: 16),
            Text(
              'No hay información EPG disponible',
              style: TextStyle(color: Colors.grey[400], fontSize: 18),
            ),
            const SizedBox(height: 32),
            // Botón de reproducir para canales sin EPG
            Container(
              decoration: BoxDecoration(
                border: _selectedIndex == 0
                    ? Border.all(color: Colors.blue, width: 3)
                    : null,
                borderRadius: BorderRadius.circular(50),
              ),
              child: ElevatedButton(
                onPressed: _showPlayerSelectionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.play_arrow, size: 32, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      'REPRODUCIR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final programme = _displayedProgramme!;
    final timeFormat = DateFormat('HH:mm');

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        
        // Calcular dimensiones basadas en porcentajes
        final topPadding = 70.0; // Espacio para la barra superior
        final bottomPadding = 20.0;
        final availableHeight = screenHeight - topPadding - bottomPadding;
        
        // Poster ocupa el alto disponible menos espacio para el botón
        final buttonHeight = 50.0;
        final spacingBetween = 12.0;
        final posterHeight = availableHeight - buttonHeight - spacingBetween;
        
        // Mantener relación de aspecto 2:3 (poster vertical)
        final posterWidth = posterHeight * (2 / 3);
        
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            topPadding,
            20,
            bottomPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // IZQUIERDA: Poster grande + Botón PLAY (ocupa todo el alto)
              SizedBox(
                width: posterWidth,
                height: availableHeight,
                child: Column(
                  children: [
                    // Poster
                    if (programme.iconUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: programme.iconUrl!,
                          width: posterWidth,
                          height: posterHeight,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: posterWidth,
                            height: posterHeight,
                            color: Colors.grey[800],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: posterWidth,
                            height: posterHeight,
                            color: Colors.grey[800],
                            child: const Icon(Icons.tv, size: 64),
                          ),
                        ),
                      ),

                    SizedBox(height: spacingBetween),

                    // Botón PLAY (estilo EPG)
                    Container(
                      width: posterWidth,
                      height: buttonHeight,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedIndex == 0 
                              ? Colors.blue 
                              : Colors.grey, // Gris cuando no está seleccionado
                          width: _selectedIndex == 0 ? 3 : 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showPlayerSelectionDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.play_arrow,
                                size: 22,
                                color: _selectedIndex == 0 
                                    ? Colors.blue 
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'REPRODUCIR',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedIndex == 0 
                                      ? Colors.blue 
                                      : Colors.grey,
                                  letterSpacing: 0.5,
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

              const SizedBox(width: 20),

              // CENTRO-DERECHA: Información del programa
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Badge EN VIVO + Horario
                Row(
                  children: [
                    // Mostrar badge "EN VIVO" solo si es el programa actual
                    if (programme == _currentProgramme) ...[
                      FadeTransition(
                        opacity: _blinkAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.red,
                              width: 1.5,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.red, size: 8),
                              SizedBox(width: 6),
                              Text(
                                'EN VIVO',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      '${timeFormat.format(programme.start)} - ${timeFormat.format(programme.stop)}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Título
                Text(
                  programme.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 8),

                // Categoría, Rating, Estrellas
                Row(
                  children: [
                    if (programme.category != null) ...[
                      Icon(Icons.category, color: Colors.grey[400], size: 14),
                      const SizedBox(width: 4),
                      Text(
                        programme.category!,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (programme.starRating != null) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        programme.starRating!,
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (programme.rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.orange,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          programme.rating!,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Descripción
                if (programme.description != null)
                  Text(
                    programme.description!,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: 16),

                // Próximos programas (horizontal)
                if (_upcomingProgrammes.isNotEmpty) ...[
                  Text(
                    'PRÓXIMOS PROGRAMAS',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Cards dinámicas que llegan hasta abajo
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cardTotalHeight = constraints.maxHeight;
                        // Sin hora, el poster usa toda la altura
                        final cardHeight = cardTotalHeight;
                        final imageHeight = cardHeight;
                        final cardWidth = imageHeight * 0.60; // Ajustado para llenar mejor el espacio
                        
                        return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (_upcomingProgrammes.length - _programmeStartIndex)
                          .clamp(0, _visibleProgrammesCount),
                      itemBuilder: (context, index) {
                        final actualIndex = _programmeStartIndex + index;
                        final upcomingProgramme = _upcomingProgrammes[actualIndex];
                        final isSelected = _selectedIndex == (actualIndex + 1);

                        return Container(
                          width: cardWidth,
                          height: cardHeight,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(color: Colors.blue, width: 3)
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // Imagen del poster
                                upcomingProgramme.iconUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: upcomingProgramme.iconUrl!,
                                        width: cardWidth,
                                        height: cardHeight,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          width: cardWidth,
                                          height: cardHeight,
                                          color: Colors.grey[800],
                                        ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              width: cardWidth,
                                              height: cardHeight,
                                              color: Colors.grey[800],
                                              child: const Icon(Icons.tv, size: 40),
                                            ),
                                      )
                                    : Container(
                                        width: cardWidth,
                                        height: cardHeight,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.tv, size: 40),
                                      ),
                                // Título con gradiente en la parte inferior
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.8),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      upcomingProgramme.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
        );
      },
    );
  }
}

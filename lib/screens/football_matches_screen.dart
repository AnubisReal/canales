import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../models/epg_programme.dart';
import '../services/epg_service.dart';
import '../services/football_service.dart';
import 'channel_detail_screen.dart';
import 'dart:io' show Platform;

class FootballMatchesScreen extends StatefulWidget {
  final List<Channel> channels;

  const FootballMatchesScreen({super.key, required this.channels});

  @override
  State<FootballMatchesScreen> createState() => _FootballMatchesScreenState();
}

class _FootballMatchesScreenState extends State<FootballMatchesScreen> {
  List<FootballMatch> _matches = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  final FocusNode _focusNode = FocusNode();
  
  // Variables para navegación en grid (similar a main.dart)
  final int tvColumns = 6;
  final int tvRows = 4;
  int startRowIndex = 0;

  bool get isAndroidTV {
    try {
      return Platform.isAndroid;
    } catch (e) {
      return false;
    }
  }

  List<FootballMatch> get visibleMatches {
    if (!isAndroidTV || _matches.isEmpty) return _matches;

    final int totalMatches = _matches.length;
    final int maxVisibleMatches = tvColumns * tvRows;
    final int startIndex = startRowIndex * tvColumns;
    final int endIndex = (startIndex + maxVisibleMatches).clamp(0, totalMatches);

    if (startIndex >= totalMatches) return [];
    return _matches.sublist(startIndex, endIndex);
  }

  @override
  void initState() {
    super.initState();
    _loadFootballMatches();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFootballMatches() async {
    setState(() => _isLoading = true);

    // Intentar usar datos pre-cargados primero
    if (FootballService.isLoaded()) {
      print('⚡ Usando partidos pre-cargados (instantáneo)');
      setState(() {
        _matches = FootballService.getCachedMatches();
        _isLoading = false;
      });
      return;
    }

    // Si no están pre-cargados, cargar ahora
    print('⏳ Partidos no pre-cargados, cargando ahora...');
    final matches = <FootballMatch>[];
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Obtener TODOS los programas de hoy de una vez (mucho más rápido)
    final allProgrammes = await EpgService.getAllProgrammesToday();

    // Crear un mapa de channelId -> Channel para búsqueda rápida
    final channelMap = <String, Channel>{};
    for (final channel in widget.channels) {
      final epgChannel = await EpgService.findMatchingEpgChannel(channel.name);
      if (epgChannel != null) {
        channelMap[epgChannel.id] = channel;
      }
    }

    // Filtrar programas de fútbol usando la categoría
    for (final programme in allProgrammes) {
      // Verificar que sea de hoy
      if (programme.start.isBefore(startOfDay) || programme.start.isAfter(endOfDay)) {
        continue;
      }

      // FILTRO IMPORTANTE: Solo mostrar partidos que NO han terminado
      if (programme.isPast) {
        continue; // Partido ya terminado, saltar
      }

      // Usar la categoría del programa (mucho más preciso)
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

    setState(() {
      _matches = matches;
      _isLoading = false;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_matches.isEmpty) return;

      final crossAxisCount = isAndroidTV ? tvColumns : 4;
      final totalItems = _matches.length;
      final currentRow = _selectedIndex ~/ crossAxisCount;
      final currentCol = _selectedIndex % crossAxisCount;

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() {
          if (currentCol < crossAxisCount - 1) {
            final newIndex = _selectedIndex + 1;
            if (newIndex < totalItems) {
              _selectedIndex = newIndex;
            }
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() {
          if (currentCol > 0) {
            _selectedIndex = _selectedIndex - 1;
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          final newIndex = _selectedIndex + crossAxisCount;
          if (newIndex < totalItems) {
            _selectedIndex = newIndex;
            final newRow = newIndex ~/ crossAxisCount;
            final newVisibleRow = newRow - startRowIndex;

            if (isAndroidTV && newVisibleRow >= tvRows) {
              final maxStartRow = ((totalItems - 1) ~/ crossAxisCount) - tvRows + 1;
              if (startRowIndex < maxStartRow) {
                startRowIndex++;
              }
            }
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (currentRow > 0) {
            final newIndex = _selectedIndex - crossAxisCount;
            final newRow = newIndex ~/ crossAxisCount;
            final newVisibleRow = newRow - startRowIndex;

            if (isAndroidTV && newVisibleRow < 0 && startRowIndex > 0) {
              startRowIndex--;
            }

            _selectedIndex = newIndex;
          }
        });
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _openChannel();
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        Navigator.of(context).pop();
      }
    }
  }

  void _openChannel() {
    if (_matches.isEmpty) return;
    final match = _matches[_selectedIndex];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChannelDetailScreen(channel: match.channel),
      ),
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
              // Grid de partidos
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _matches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sports_soccer,
                                    color: Colors.grey[600], size: 64),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay partidos de fútbol hoy',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.only(top: 100.0, bottom: 16.0),
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isAndroidTV ? tvColumns : 4,
                              crossAxisSpacing: isAndroidTV ? 10.0 : 8.0,
                              mainAxisSpacing: isAndroidTV ? 10.0 : 8.0,
                              childAspectRatio: isAndroidTV ? 0.75 : 0.75, // 3:4 ratio (póster vertical)
                            ),
                            itemCount: isAndroidTV
                                ? visibleMatches.length
                                : _matches.length,
                            itemBuilder: (context, index) {
                              final matchesList = isAndroidTV ? visibleMatches : _matches;
                              final match = matchesList[index];
                              final actualIndex = isAndroidTV
                                  ? (startRowIndex * tvColumns) + index
                                  : index;
                              final isSelected = _selectedIndex == actualIndex;
                              final timeFormat = DateFormat('HH:mm');

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _selectedIndex = actualIndex);
                                  _openChannel();
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[900],
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(color: Colors.blue, width: 3)
                                        : null,
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
                                                          child: Icon(Icons.sports_soccer,
                                                              color: Colors.grey, size: 40),
                                                        ),
                                                      ),
                                                      errorWidget: (context, url, error) =>
                                                          Container(
                                                        color: Colors.grey[800],
                                                        child: const Center(
                                                          child: Icon(Icons.sports_soccer,
                                                              color: Colors.grey, size: 40),
                                                        ),
                                                      ),
                                                    )
                                                  : Container(
                                                      color: Colors.grey[800],
                                                      child: const Center(
                                                        child: Icon(Icons.sports_soccer,
                                                            color: Colors.grey, size: 40),
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
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 9,
                                              ),
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
                            },
                          ),
              ),
              // Barra superior con título
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.black.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PARTIDOS DE FÚTBOL HOY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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

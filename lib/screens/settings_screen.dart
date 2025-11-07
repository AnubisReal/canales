import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/video_player.dart';
import '../services/player_service.dart';
import '../services/settings_service.dart';
import '../services/m3u_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  // Variables para doble pulsación de atrás
  DateTime? _lastBackPress;
  static const _backPressThreshold = Duration(seconds: 2);
  
  // Variables para reproductores
  List<VideoPlayer> _availablePlayers = [];
  int _selectedPlayerIndex = 0;
  bool _isLoading = true;
  
  // Variables para URL M3U
  String? _currentM3uUrl;
  
  // Estados de navegación
  // 0 = botón atrás
  // 1 = botón cambiar M3U
  // 2 = botón eliminar M3U
  // 3 = botón telegram
  // 4+ = reproductores
  int _navigationSection = 0;
  
  int get _firstPlayerIndex => 4;
  bool get _isOnPlayersList => _navigationSection >= _firstPlayerIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPlayers();
    _loadM3uUrl();
  }
  
  Future<void> _loadM3uUrl() async {
    final url = await M3UService.getM3uUrl();
    if (mounted) {
      setState(() {
        _currentM3uUrl = url;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // La app volvió al primer plano - recargar reproductores por si instalaron alguno nuevo
      print('🔄 App resumed - Recargando lista de reproductores...');
      _loadPlayers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPlayers() async {
    setState(() => _isLoading = true);
    
    print('🔄 Buscando reproductores instalados...');
    
    // Cargar reproductor por defecto guardado
    await SettingsService.loadDefaultPlayer();
    
    // Obtener reproductores disponibles
    final players = await PlayerService.getAvailablePlayers();
    
    // Encontrar el índice del reproductor por defecto
    final currentPackage = SettingsService.defaultPlayerPackage;
    int selectedIndex = 0;
    
    for (int i = 0; i < players.length; i++) {
      if (players[i].packageName == currentPackage) {
        selectedIndex = i;
        break;
      }
    }
    
    setState(() {
      _availablePlayers = players;
      _selectedPlayerIndex = selectedIndex;
      _isLoading = false;
    });
    
    // Mostrar mensaje con el número de reproductores encontrados
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${players.length - 1} reproductor(es) encontrado(s)'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  Future<void> _selectPlayer(int index) async {
    if (index < 0 || index >= _availablePlayers.length) return;
    
    final player = _availablePlayers[index];
    
    print('💾 Guardando reproductor: ${player.name} (${player.packageName})');
    await SettingsService.setDefaultPlayer(player.packageName);
    
    // Verificar que se guardó correctamente
    await SettingsService.loadDefaultPlayer();
    final savedPackage = SettingsService.defaultPlayerPackage;
    print('✅ Verificación - Reproductor guardado: $savedPackage');
    
    setState(() {
      _selectedPlayerIndex = index;
    });
    
    // Mostrar confirmación
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Reproductor por defecto: ${player.name}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        _handleBackPress();
        return;
      }
      
      // Navegación con flechas
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          if (_navigationSection == 0) {
            // Desde botón atrás → botón cambiar M3U
            _navigationSection = 1;
          } else if (_navigationSection == 1) {
            // Desde botón cambiar → botón telegram
            _navigationSection = 3;
          } else if (_navigationSection == 2) {
            // Desde botón eliminar → botón telegram
            _navigationSection = 3;
          } else if (_navigationSection == 3) {
            // Desde botón telegram → primer reproductor
            _navigationSection = _firstPlayerIndex;
            _selectedPlayerIndex = 0;
          } else if (_isOnPlayersList) {
            // Navegando en reproductores
            if (_selectedPlayerIndex < _availablePlayers.length - 1) {
              _selectedPlayerIndex++;
              _navigationSection = _firstPlayerIndex + _selectedPlayerIndex;
            }
          }
        });
        _scrollToSelected();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          if (_navigationSection == 1) {
            // Desde botón cambiar → botón atrás
            _navigationSection = 0;
          } else if (_navigationSection == 2) {
            // Desde botón eliminar → botón cambiar
            _navigationSection = 1;
          } else if (_navigationSection == 3) {
            // Desde botón telegram → botón cambiar
            _navigationSection = 1;
          } else if (_isOnPlayersList) {
            if (_selectedPlayerIndex > 0) {
              _selectedPlayerIndex--;
              _navigationSection = _firstPlayerIndex + _selectedPlayerIndex;
            } else {
              // Desde primer reproductor → botón telegram
              _navigationSection = 3;
            }
          }
        });
        _scrollToSelected();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        // Navegar entre botones Cambiar y Eliminar
        if (_navigationSection == 1) {
          setState(() => _navigationSection = 2);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        // Navegar entre botones Eliminar y Cambiar
        if (_navigationSection == 2) {
          setState(() => _navigationSection = 1);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.space) {
        // Ejecutar acción según dónde estemos
        if (_navigationSection == 0) {
          Navigator.of(context).pop();
        } else if (_navigationSection == 1) {
          _showChangeM3uDialog();
        } else if (_navigationSection == 2) {
          _showDeleteM3uDialog();
        } else if (_navigationSection == 3) {
          _showTelegramDialog();
        } else if (_isOnPlayersList) {
          _selectPlayer(_selectedPlayerIndex);
        }
      }
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    
    // Calcular la posición aproximada del elemento seleccionado
    double targetPosition = 0;
    
    if (_navigationSection == 0) {
      targetPosition = 0; // Botón atrás (siempre visible)
    } else if (_navigationSection == 1 || _navigationSection == 2) {
      targetPosition = 0; // Botones M3U (parte superior)
    } else if (_navigationSection == 3) {
      targetPosition = 200; // Botón Telegram
    } else if (_isOnPlayersList) {
      // Reproductores: cada uno ocupa ~80px
      targetPosition = 400 + (_selectedPlayerIndex * 80.0);
    }
    
    _scrollController.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
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

  void _showChangeM3uDialog() {
    final controller = TextEditingController(text: _currentM3uUrl ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Cambiar URL M3U', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nueva URL',
            labelStyle: TextStyle(color: Colors.grey[400]),
            hintText: 'https://ejemplo.com/lista.m3u',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                Navigator.pop(context);
                await M3UService.setM3uUrl(newUrl);
                await _loadM3uUrl();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ URL M3U actualizada. Reinicia la app para aplicar cambios.'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            child: const Text('Guardar', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _showDeleteM3uDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Eliminar URL M3U', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que deseas eliminar la URL M3U?\n\nDeberás configurarla nuevamente la próxima vez que abras la app.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await M3UService.clearM3uUrl();
              await _loadM3uUrl();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🗑️ URL M3U eliminada. Reinicia la app.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showTelegramDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Image.asset(
                'assets/images/telegram.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
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
              // Contenido principal
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.blue),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 100.0, left: 40.0, right: 40.0, bottom: 40.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sección URL M3U
                          Text(
                            '📡 Lista M3U',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.link, color: Colors.grey[400], size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _currentM3uUrl ?? 'No configurada',
                                        style: TextStyle(
                                          color: _currentM3uUrl != null ? Colors.white : Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: _navigationSection == 1
                                              ? Border.all(color: Colors.blue, width: 3)
                                              : null,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: _showChangeM3uDialog,
                                          icon: const Icon(Icons.edit, size: 16),
                                          label: const Text('Cambiar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: _navigationSection == 2
                                              ? Border.all(color: Colors.blue, width: 3)
                                              : null,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: ElevatedButton.icon(
                                          onPressed: _showDeleteM3uDialog,
                                          icon: const Icon(Icons.delete, size: 16),
                                          label: const Text('Eliminar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Sección Telegram
                          Container(
                            decoration: BoxDecoration(
                              border: _navigationSection == 3
                                  ? Border.all(color: Colors.blue, width: 3)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ElevatedButton(
                              onPressed: _showTelegramDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.telegram, size: 20),
                                  SizedBox(width: 12),
                                  Text('Únete a nuestro grupo de Telegram'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // Sección Reproductor
                          Text(
                            '📺 Reproductor por defecto',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Selecciona la aplicación con la que deseas reproducir los canales',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Lista de reproductores
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _availablePlayers.length,
                            itemBuilder: (context, index) {
                                final player = _availablePlayers[index];
                                final isSelected = index == _selectedPlayerIndex && _isOnPlayersList;
                                final isCurrent = player.packageName == SettingsService.defaultPlayerPackage;
                                
                                return GestureDetector(
                                  onTap: () => _selectPlayer(index),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[900],
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(color: Colors.blue, width: 3)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          player.id == 'ask'
                                              ? Icons.help_outline
                                              : Icons.play_circle_outline,
                                          color: isCurrent ? Colors.blue : Colors.grey[600],
                                          size: 32,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                player.name,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                              if (player.packageName.isNotEmpty)
                                                Text(
                                                  player.packageName,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (isCurrent)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'ACTUAL',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
              // Barra superior
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
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: _navigationSection == 0
                                  ? Border.all(color: Colors.blue, width: 3)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.arrow_back,
                                color: _navigationSection == 0 ? Colors.blue : Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Configuraciones',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Botón de actualizar reproductores
                          IconButton(
                            onPressed: _isLoading ? null : _loadPlayers,
                            icon: Icon(
                              Icons.refresh,
                              color: _isLoading ? Colors.grey : Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Buscar reproductores',
                          ),
                        ],
                      ),
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

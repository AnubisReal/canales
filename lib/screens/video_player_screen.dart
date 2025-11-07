import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/channel.dart';
import '../services/acestream_service.dart';
import 'settings_screen.dart';

class VideoPlayerScreen extends StatefulWidget {
  final Channel channel;

  const VideoPlayerScreen({super.key, required this.channel});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _acestreamHash;
  String? _playbackUrl;
  bool _isAcestreamEngineRunning = false;
  WebViewController? _webViewController;
  bool _showWebPlayer = false;

  @override
  void initState() {
    super.initState();
    _checkAcestreamAndInitialize();
  }

  void _checkAcestreamAndInitialize() async {
    try {
      // Extraer hash de Acestream
      _acestreamHash = AcestreamService.extractAcestreamHash(widget.channel.streamUrl);
      
      if (_acestreamHash == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'URL de Acestream no válida';
        });
        return;
      }

      setState(() {
        _errorMessage = 'Verificando motor Acestream...';
      });

      // Verificar si el motor Acestream está corriendo
      _isAcestreamEngineRunning = await AcestreamService.isAcestreamEngineRunning();
      
      if (!_isAcestreamEngineRunning) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Motor Acestream no está corriendo.\n\nPor favor:\n• Inicia Acestream Engine\n• Verifica la configuración de IP\n• Asegúrate que el puerto 6878 esté abierto';
        });
        return;
      }

      setState(() {
        _errorMessage = 'Iniciando stream...\nEsto puede tomar hasta 30 segundos';
      });

      // Iniciar el stream
      _playbackUrl = await AcestreamService.startAcestreamStream(_acestreamHash!);
      
      if (_playbackUrl != null) {
        setState(() {
          _isLoading = false;
          _hasError = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'No se pudo iniciar el stream de Acestream.\n\nPosibles causas:\n• El hash no es válido\n• El contenido no está disponible\n• Problemas de red\n• El motor está ocupado con otro stream';
        });
      }
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Error: $e\n\nIntenta:\n• Verificar la conexión de red\n• Reiniciar Acestream Engine\n• Cambiar la configuración de IP';
      });
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
  }

  void _openInExternalPlayer() async {
    if (_playbackUrl != null) {
      final uri = Uri.parse(_playbackUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _copyUrlToClipboard() {
    if (_playbackUrl != null) {
      Clipboard.setData(ClipboardData(text: _playbackUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL copiada al portapapeles'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _initializeWebPlayer() {
    if (_playbackUrl != null) {
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Progreso de carga del WebView
            },
            onPageStarted: (String url) {
              // Página iniciada
            },
            onPageFinished: (String url) {
              // Página terminada
            },
          ),
        );
      
      // Crear HTML personalizado para el reproductor
      final htmlContent = '''
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Reproductor Acestream</title>
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background-color: #000;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    font-family: Arial, sans-serif;
                }
                video {
                    width: 100%;
                    height: 100%;
                    max-width: 100vw;
                    max-height: 100vh;
                }
                .error {
                    color: white;
                    text-align: center;
                    padding: 20px;
                }
            </style>
        </head>
        <body>
            <video controls autoplay>
                <source src="$_playbackUrl" type="application/x-mpegURL">
                <source src="$_playbackUrl" type="video/mp4">
                <div class="error">
                    Tu navegador no soporta la reproducción de video.<br>
                    <a href="$_playbackUrl" style="color: #4CAF50;">Abrir enlace directo</a>
                </div>
            </video>
        </body>
        </html>
      ''';
      
      _webViewController!.loadHtmlString(htmlContent);
      
      setState(() {
        _showWebPlayer = true;
      });
    }
  }

  @override
  void dispose() {
    // Parar el stream cuando se cierre la pantalla
    if (_acestreamHash != null) {
      AcestreamService.stopAcestreamStream(_acestreamHash!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Contenido principal
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Conectando con Acestream...',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_acestreamHash != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Hash del stream:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_acestreamHash!.substring(0, 8)}...${_acestreamHash!.substring(_acestreamHash!.length - 8)}',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
          else if (_hasError)
            _buildErrorWidget()
          else if (_showWebPlayer && _webViewController != null)
            _buildWebPlayerWidget()
          else
            _buildSuccessWidget(),
          
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
                      IconButton(
                        onPressed: _goBack,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.channel.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.channel.group,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebPlayerWidget() {
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Reproductor web
          Expanded(
            child: WebViewWidget(controller: _webViewController!),
          ),
          
          // Controles inferiores
          Container(
            padding: const EdgeInsets.all(16),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showWebPlayer = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  tooltip: 'Volver a opciones',
                ),
                
                IconButton(
                  onPressed: _openInExternalPlayer,
                  icon: const Icon(Icons.open_in_new, color: Colors.white, size: 28),
                  tooltip: 'Abrir en app externa',
                ),
                
                IconButton(
                  onPressed: _copyUrlToClipboard,
                  icon: const Icon(Icons.copy, color: Colors.white, size: 28),
                  tooltip: 'Copiar URL',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessWidget() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.green,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Stream listo para reproducir',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hash: ${_acestreamHash?.substring(0, 8)}...',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          
          // Botón para reproductor interno
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _initializeWebPlayer,
              icon: const Icon(Icons.play_circle_fill, color: Colors.white),
              label: const Text(
                'Reproducir en la app',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Botón para abrir en reproductor externo
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openInExternalPlayer,
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              label: const Text(
                'Abrir en reproductor externo',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Botón para copiar URL
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _copyUrlToClipboard,
              icon: const Icon(Icons.copy, color: Colors.white),
              label: const Text(
                'Copiar URL del stream',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Información adicional
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Opciones de reproducción:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Reproduce directamente en la app con el reproductor interno\n'
                  '• Abre en VLC, MPC-HC, o cualquier reproductor externo\n'
                  '• Copia la URL para usar en otros dispositivos\n'
                  '• El stream estará disponible mientras Acestream Engine esté corriendo',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error de reproducción',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'No se pudo reproducir el canal',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Botones de acción
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings, color: Colors.white),
                label: const Text(
                  'Configurar',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
              ),
              
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                  _checkAcestreamAndInitialize();
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

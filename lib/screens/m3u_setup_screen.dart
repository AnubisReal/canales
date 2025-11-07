import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/m3u_service.dart';

class M3uSetupScreen extends StatefulWidget {
  final VoidCallback? onConfigured;
  
  const M3uSetupScreen({super.key, this.onConfigured});

  @override
  State<M3uSetupScreen> createState() => _M3uSetupScreenState();
}

class _M3uSetupScreenState extends State<M3uSetupScreen> {
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final FocusNode _buttonFocusNode = FocusNode();
  final FocusNode _screenFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOnTextField = true; // true = TextField, false = Botón

  @override
  void dispose() {
    _urlController.dispose();
    _textFieldFocusNode.dispose();
    _buttonFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_isOnTextField) {
          setState(() {
            _isOnTextField = false;
            _buttonFocusNode.requestFocus();
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (!_isOnTextField) {
          setState(() {
            _isOnTextField = true;
            _textFieldFocusNode.requestFocus();
          });
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select) {
        if (_isOnTextField) {
          // Abrir teclado en el TextField
          _textFieldFocusNode.requestFocus();
        } else {
          // Ejecutar el botón
          if (!_isLoading) {
            _saveAndContinue();
          }
        }
      }
    }
  }

  Future<void> _saveAndContinue() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingresa una URL';
      });
      return;
    }

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() {
        _errorMessage = 'La URL debe comenzar con http:// o https://';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Guardar la URL
      await M3UService.setM3uUrl(url);

      // Intentar descargar la lista para validar
      await M3UService.fetchChannels();

      // Si llegamos aquí, todo salió bien
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Llamar al callback para notificar que se configuró
        widget.onConfigured?.call();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar la lista: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _screenFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo o icono
                Icon(
                  Icons.live_tv,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),

                // Título
                Text(
                  'Bienvenido',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Subtítulo
                Text(
                  'Configura tu lista M3U para comenzar',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Campo de texto para URL
                Container(
                  decoration: BoxDecoration(
                    border: _isOnTextField
                        ? Border.all(color: Colors.blue, width: 3)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _urlController,
                    focusNode: _textFieldFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'URL de la lista M3U',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      hintText: 'https://ejemplo.com/lista.m3u',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue, width: 2),
                      ),
                      prefixIcon: Icon(Icons.link, color: Colors.grey[400]),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saveAndContinue(),
                  ),
                ),
                const SizedBox(height: 16),

                // Mensaje de error
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Botón continuar
                Container(
                  decoration: BoxDecoration(
                    border: !_isOnTextField
                        ? Border.all(color: Colors.blue, width: 3)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    focusNode: _buttonFocusNode,
                    onPressed: _isLoading ? null : _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'CONTINUAR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 32),

                // Nota informativa
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Información',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Esta aplicación no proporciona contenido. Debes tener tu propia lista M3U legal para usar la app.',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                          height: 1.4,
                        ),
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
    );
  }
}

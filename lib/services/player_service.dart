import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import '../models/video_player.dart';
import 'video_intent_service.dart';

class PlayerService {
  /// Obtiene la lista de reproductores disponibles (instalados)
  static Future<List<VideoPlayer>> getAvailablePlayers() async {
    final availablePlayers = <VideoPlayer>[];

    // Siempre agregar "Preguntar siempre" como primera opción
    availablePlayers.add(VideoPlayer.knownPlayers.first);

    // En Android, verificar qué reproductores están realmente instalados
    if (Platform.isAndroid) {
      for (final player in VideoPlayer.knownPlayers.skip(1)) {
        final isInstalled = await isPlayerInstalled(player.packageName);
        if (isInstalled) {
          availablePlayers.add(player.copyWith(isInstalled: true));
          print(
            '✅ Reproductor encontrado: ${player.name} (${player.packageName})',
          );
        } else {
          print(
            '⚠️ Reproductor NO instalado: ${player.name} (${player.packageName})',
          );
        }
      }
    }

    print('📱 Total de reproductores disponibles: ${availablePlayers.length}');
    return availablePlayers;
  }

  /// Verifica si un reproductor específico está instalado
  static Future<bool> isPlayerInstalled(String packageName) async {
    if (packageName.isEmpty) return true; // "Preguntar siempre"

    try {
      if (!Platform.isAndroid) return false;

      // Usar el método nativo a través de VideoIntentService
      return await VideoIntentService.isAppInstalled(packageName);
    } catch (e) {
      print('❌ Error al verificar app $packageName: $e');
      return false;
    }
  }

  /// Abre una URL con un reproductor específico usando Android Intent
  static Future<bool> openWithPlayer(String url, String packageName) async {
    try {
      if (packageName.isEmpty) {
        // "Preguntar siempre" - usar el intent implícito (selector del sistema)
        return false; // Indica que debe usar el método por defecto
      }

      if (!Platform.isAndroid) {
        print('⚠️ Intents solo disponibles en Android');
        return false;
      }

      // Crear intent explícito para abrir la URL con la app específica
      final intent = AndroidIntent(
        action: 'action_view',
        data: url,
        package: packageName,
        type: 'video/*',
      );

      // Lanzar el intent
      await intent.launch();

      print('✅ Intent lanzado para $packageName');
      return true;
    } catch (e) {
      print('❌ Error al abrir con reproductor: $e');
      return false;
    }
  }
}

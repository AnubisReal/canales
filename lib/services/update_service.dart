import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

class UpdateService {
  // CONFIGURA AQUÍ TU USUARIO Y REPOSITORIO DE GITHUB
  static const String githubUser = 'AnubisReal';
  static const String githubRepo = 'canales';

  static final Dio _dio = Dio();

  /// Verifica si hay una nueva versión disponible en GitHub Releases
  static Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // Obtener versión actual de la app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      print('📱 Versión actual: $currentVersion');

      // Consultar última release en GitHub
      final response = await _dio.get(
        'https://api.github.com/repos/$githubUser/$githubRepo/releases/latest',
      );

      if (response.statusCode == 200) {
        final latestRelease = response.data;
        final latestVersion = (latestRelease['tag_name'] as String).replaceAll(
          'v',
          '',
        );

        print('🔄 Última versión en GitHub: $latestVersion');

        // Comparar versiones
        if (_isNewerVersion(currentVersion, latestVersion)) {
          // Buscar el archivo APK en los assets
          final assets = latestRelease['assets'] as List;
          final apkAsset = assets.firstWhere(
            (asset) => (asset['name'] as String).endsWith('.apk'),
            orElse: () => null,
          );

          if (apkAsset != null) {
            return {
              'hasUpdate': true,
              'version': latestVersion,
              'downloadUrl': apkAsset['browser_download_url'],
              'releaseNotes':
                  latestRelease['body'] ?? 'Nueva versión disponible',
              'size': apkAsset['size'],
            };
          }
        }
      }

      return {'hasUpdate': false};
    } catch (e) {
      print('❌ Error al verificar actualizaciones: $e');
      return null;
    }
  }

  /// Compara dos versiones (formato: 1.2.3)
  static bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false;
  }

  /// Descarga e instala la actualización
  static Future<bool> downloadAndInstall({
    required String downloadUrl,
    required Function(double) onProgress,
  }) async {
    try {
      // Solicitar permisos de instalación
      if (Platform.isAndroid) {
        // En Android 8.0+ necesitamos permiso para instalar APKs
        final status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          print('⚠️ Permiso de instalación denegado');
          return false;
        }
      }

      // Obtener directorio de descargas
      final dir = await getExternalStorageDirectory();
      final filePath = '${dir!.path}/canales_update.apk';

      print('📥 Descargando actualización...');

      // Descargar APK
      await _dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            print('📊 Progreso: ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
      );

      print('✅ Descarga completada');

      // Instalar APK usando Android Intent
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'file://$filePath',
          type: 'application/vnd.android.package-archive',
          flags: [
            Flag.FLAG_ACTIVITY_NEW_TASK,
            Flag.FLAG_GRANT_READ_URI_PERMISSION,
          ],
        );

        await intent.launch();
        print('✅ Instalación iniciada');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error al descargar/instalar: $e');
      return false;
    }
  }

  /// Verifica actualizaciones automáticamente al iniciar la app
  static Future<void> checkOnStartup() async {
    // Esperar 3 segundos después del inicio para no interferir con la carga
    await Future.delayed(const Duration(seconds: 3));

    final updateInfo = await checkForUpdate();

    if (updateInfo != null && updateInfo['hasUpdate'] == true) {
      print('🎉 Nueva versión disponible: ${updateInfo['version']}');
      // Aquí puedes mostrar un diálogo al usuario
      // Por ahora solo imprimimos en consola
    }
  }
}

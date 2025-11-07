import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  // CONFIGURA AQUÍ TU USUARIO Y REPOSITORIO DE GITHUB
  static const String githubUser = 'AnubisReal';
  static const String githubRepo = 'canales';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

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
      print('🔗 URL de descarga: $downloadUrl');
      
      // En Android TV, getExternalStorageDirectory() no necesita permisos especiales
      // Obtener directorio de almacenamiento de la app
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        print('❌ No se pudo obtener directorio de almacenamiento');
        return false;
      }
      
      final filePath = '${dir.path}/canales_update.apk';
      print('📁 Guardando en: $filePath');

      // Eliminar archivo anterior si existe
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Archivo anterior eliminado');
      }

      print('📥 Iniciando descarga...');
      final startTime = DateTime.now();

      // Descargar APK con opciones específicas
      final response = await _dio.download(
        downloadUrl,
        filePath,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            final speed = received / DateTime.now().difference(startTime).inSeconds;
            final speedMB = speed / 1024 / 1024;
            print('📊 Progreso: ${(progress * 100).toStringAsFixed(0)}% - ${speedMB.toStringAsFixed(2)} MB/s');
          } else {
            print('📊 Descargados: ${(received / 1024 / 1024).toStringAsFixed(2)} MB');
          }
        },
      );

      if (response.statusCode != 200) {
        print('❌ Error HTTP: ${response.statusCode}');
        return false;
      }

      print('✅ Descarga completada en ${DateTime.now().difference(startTime).inSeconds}s');
      
      // Verificar que el archivo existe y tiene contenido
      if (!await file.exists()) {
        print('❌ El archivo no existe después de descargar');
        return false;
      }
      
      final fileSize = await file.length();
      print('📦 Tamaño del archivo: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      if (fileSize < 1000000) { // Menos de 1MB es sospechoso
        print('⚠️ El archivo parece demasiado pequeño');
        return false;
      }

      // Instalar APK usando OpenFilex (maneja FileProvider automáticamente)
      if (Platform.isAndroid) {
        print('📲 Iniciando instalación...');
        
        final result = await OpenFilex.open(
          filePath,
          type: 'application/vnd.android.package-archive',
        );
        
        print('✅ Resultado de instalación: ${result.type} - ${result.message}');
        
        if (result.type == ResultType.done) {
          return true;
        } else {
          print('⚠️ No se pudo abrir el instalador: ${result.message}');
          return false;
        }
      }

      return false;
    } catch (e, stackTrace) {
      print('❌ Error al descargar/instalar: $e');
      print('Stack trace: $stackTrace');
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

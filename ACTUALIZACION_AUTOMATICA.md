# 🔄 Sistema de Actualización Automática

Este documento explica cómo configurar y usar el sistema de actualización automática de la app usando GitHub Releases.

## 📋 Configuración Inicial

### 1. Configurar el servicio de actualización

Edita el archivo `lib/services/update_service.dart` y cambia estas líneas:

```dart
static const String githubUser = 'TU_USUARIO_GITHUB';
static const String githubRepo = 'TU_REPOSITORIO';
```

Por ejemplo:
```dart
static const String githubUser = 'dopet';
static const String githubRepo = 'canales';
```

### 2. Crear un repositorio en GitHub

1. Ve a https://github.com/new
2. Crea un repositorio (puede ser público o privado)
3. Sube tu código al repositorio

### 3. Publicar una nueva versión

Cada vez que quieras publicar una actualización:

#### Paso 1: Actualizar la versión en `pubspec.yaml`

```yaml
version: 1.0.1+2  # Incrementa el número de versión
```

El formato es: `MAJOR.MINOR.PATCH+BUILD`
- Ejemplo: `1.0.0+1` → `1.0.1+2`

#### Paso 2: Compilar el APK

```bash
flutter build apk --release
```

El APK se generará en: `build/app/outputs/flutter-apk/app-release.apk`

#### Paso 3: Crear un Release en GitHub

1. Ve a tu repositorio en GitHub
2. Click en "Releases" (en el menú derecho)
3. Click en "Create a new release"
4. En "Choose a tag", escribe: `v1.0.1` (la misma versión del pubspec.yaml con "v" delante)
5. En "Release title", escribe: `Versión 1.0.1`
6. En "Describe this release", escribe las notas de la versión:
   ```
   ## 🎉 Novedades
   - Se agregó sistema de actualización automática
   - Corrección de bugs
   - Mejoras de rendimiento
   ```
7. Arrastra el archivo `app-release.apk` al área de "Attach binaries"
8. Click en "Publish release"

## 🚀 Cómo Funciona

1. **Al iniciar la app**: Después de 5 segundos, la app verifica si hay una nueva versión en GitHub
2. **Si hay actualización**: Muestra un diálogo con la información de la nueva versión
3. **Al aceptar**: Descarga el APK automáticamente
4. **Instalación**: Abre el instalador de Android para que el usuario confirme la instalación

## 📱 Experiencia del Usuario

1. Usuario abre la app
2. Después de unos segundos, ve un diálogo: "🎉 Actualización disponible"
3. Puede elegir:
   - **"Más tarde"**: Cierra el diálogo y sigue usando la app
   - **"Actualizar ahora"**: Descarga e instala la actualización

4. Durante la descarga, ve una barra de progreso
5. Al terminar, Android pide confirmar la instalación
6. La app se actualiza automáticamente

## 🔧 Solución de Problemas

### La app no detecta actualizaciones

1. Verifica que `githubUser` y `githubRepo` estén correctos en `update_service.dart`
2. Asegúrate de que el tag del release empiece con "v" (ejemplo: `v1.0.1`)
3. Verifica que el APK esté adjunto al release
4. Revisa los logs en la consola para ver errores

### Error al instalar

1. Asegúrate de que los permisos estén en `AndroidManifest.xml`
2. En Android 8.0+, el usuario debe permitir "Instalar apps de fuentes desconocidas"
3. Verifica que el APK no esté corrupto

## 📝 Ejemplo de Flujo Completo

```bash
# 1. Hacer cambios en el código
# 2. Actualizar versión
# En pubspec.yaml: version: 1.0.1+2

# 3. Compilar
flutter build apk --release

# 4. Crear release en GitHub
# - Tag: v1.0.1
# - Adjuntar: build/app/outputs/flutter-apk/app-release.apk

# 5. Publicar release
# ¡Listo! Los usuarios recibirán la actualización automáticamente
```

## 🎯 Ventajas

✅ **Automático**: Los usuarios no necesitan buscar actualizaciones manualmente
✅ **Gratis**: GitHub Releases es completamente gratuito
✅ **Simple**: Solo necesitas subir el APK a GitHub
✅ **Control total**: Tú decides cuándo publicar actualizaciones
✅ **Notas de versión**: Los usuarios ven qué cambió en cada actualización

## ⚠️ Importante

- Siempre incrementa el número de versión en `pubspec.yaml`
- El tag del release debe coincidir con la versión (con "v" delante)
- El APK debe llamarse `app-release.apk` o terminar en `.apk`
- Prueba la actualización antes de publicarla a todos los usuarios

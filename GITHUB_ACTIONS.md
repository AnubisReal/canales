# 🚀 GitHub Actions - Compilación Automática

Este proyecto usa GitHub Actions para compilar automáticamente el APK de la app.

## 📋 Workflows Configurados

### 1. **Build APK on Push** (`build-apk.yml`)
Se ejecuta automáticamente en cada push a `main` o `master`.

**Qué hace:**
- ✅ Compila el APK de release
- ✅ Ejecuta tests (si existen)
- ✅ Sube el APK como artifact (descargable desde GitHub)

**Cuándo se ejecuta:**
- Cada vez que haces `git push` a la rama principal
- En cada Pull Request

### 2. **Build and Release APK** (`build-release.yml`)
Se ejecuta cuando creas un tag de versión.

**Qué hace:**
- ✅ Compila el APK de release
- ✅ Renombra el APK con la versión (ejemplo: `canales-v1.0.0.apk`)
- ✅ Crea un Release en GitHub automáticamente
- ✅ Adjunta el APK al Release
- ✅ Genera notas de versión

**Cuándo se ejecuta:**
- Cuando creas un tag como `v1.0.0`, `v1.0.1`, etc.
- Manualmente desde la pestaña "Actions" en GitHub

## 🎯 Cómo Usar

### Opción 1: Crear Release Automático (Recomendado)

1. **Actualiza la versión en `pubspec.yaml`:**
   ```yaml
   version: 1.0.1+2
   ```

2. **Haz commit y push:**
   ```bash
   git add .
   git commit -m "Versión 1.0.1 - Nuevas funcionalidades"
   git push
   ```

3. **Crea un tag y súbelo:**
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

4. **¡Listo!** GitHub Actions automáticamente:
   - Compila el APK
   - Crea el Release
   - Adjunta el APK
   - Tus usuarios recibirán la actualización automáticamente

### Opción 2: Ejecutar Manualmente

1. Ve a tu repositorio en GitHub
2. Click en "Actions"
3. Selecciona "Build and Release APK"
4. Click en "Run workflow"
5. Selecciona la rama y click "Run workflow"

## 📱 Descargar APK Compilado

### Desde un Release:
1. Ve a: `https://github.com/AnubisReal/canales/releases`
2. Click en la versión más reciente
3. Descarga el archivo `canales-v1.0.0.apk`

### Desde un Build Normal:
1. Ve a: `https://github.com/AnubisReal/canales/actions`
2. Click en el workflow más reciente
3. Scroll hasta "Artifacts"
4. Descarga `app-release`

## 🔧 Configuración Avanzada

### Cambiar la versión de Flutter

Edita `.github/workflows/build-release.yml` línea 28:
```yaml
flutter-version: '3.24.0'  # Cambia a la versión que uses
```

### Personalizar las Notas del Release

Edita `.github/workflows/build-release.yml` líneas 52-60:
```yaml
body: |
  ## 🎉 Nueva versión de Canales
  
  ### Novedades
  - Tu lista de cambios aquí
```

### Agregar Firma del APK (Opcional)

Para firmar el APK automáticamente:

1. **Crea un keystore:**
   ```bash
   keytool -genkey -v -keystore canales.jks -keyalg RSA -keysize 2048 -validity 10000 -alias canales
   ```

2. **Convierte el keystore a base64:**
   ```bash
   base64 canales.jks > keystore.txt
   ```

3. **Agrega secrets en GitHub:**
   - Ve a Settings → Secrets → Actions
   - Agrega:
     - `KEYSTORE_BASE64`: contenido de `keystore.txt`
     - `KEYSTORE_PASSWORD`: tu contraseña
     - `KEY_ALIAS`: `canales`
     - `KEY_PASSWORD`: tu contraseña de la key

4. **Actualiza el workflow** para usar el keystore

## 📊 Ver el Estado de las Compilaciones

Agrega este badge a tu README.md:

```markdown
![Build Status](https://github.com/AnubisReal/canales/workflows/Build%20and%20Release%20APK/badge.svg)
```

## ⚠️ Solución de Problemas

### Error: "No permission to create release"
- Asegúrate de que el repositorio tenga permisos de escritura
- Ve a Settings → Actions → General → Workflow permissions
- Selecciona "Read and write permissions"

### Error: "Flutter version not found"
- Verifica que la versión de Flutter en el workflow existe
- Usa una versión estable como `3.24.0`

### El APK no se adjunta al Release
- Verifica que el tag empiece con `v` (ejemplo: `v1.0.0`)
- Revisa los logs en la pestaña "Actions"

## 🎉 Ventajas

✅ **Automático**: No necesitas compilar manualmente
✅ **Consistente**: Siempre se compila en el mismo ambiente
✅ **Rápido**: GitHub compila en paralelo
✅ **Gratis**: GitHub Actions es gratis para repositorios públicos
✅ **Historial**: Puedes ver todas las compilaciones anteriores
✅ **Actualización automática**: Tus usuarios reciben updates automáticamente

## 📝 Flujo Completo de Trabajo

```bash
# 1. Hacer cambios en el código
# 2. Actualizar versión en pubspec.yaml
# 3. Commit
git add .
git commit -m "Nueva funcionalidad X"

# 4. Push
git push

# 5. Crear tag para release
git tag v1.0.1
git push origin v1.0.1

# 6. GitHub Actions automáticamente:
#    - Compila el APK
#    - Crea el Release
#    - Adjunta el APK
#    - Los usuarios reciben la actualización

# ¡Listo! 🎉
```

# 🚨 Flutter - Guía de Solución de Errores Comunes

## 📱 **ERRORES DE COMPILACIÓN APK**

### 🔒 **Error: Gradle Lock - "Timeout waiting to lock build logic queue"**

**Síntomas:**
```
FAILURE: Build failed with an exception.
Timeout waiting to lock build logic queue. It is currently in use by another Gradle instance.
Owner PID: XXXX
```

**Causa:** Múltiples procesos de Flutter/Gradle corriendo simultáneamente.

**Solución:**
```bash
# 1. Matar procesos conflictivos
taskkill /F /IM java.exe 
taskkill /F /IM gradle.exe 
taskkill /F /IM flutter.exe

# 2. Limpiar cache
flutter clean

# 3. Intentar nuevamente
flutter build apk --release
```

---

### 💾 **Error: "No space left on device"**

**Síntomas:**
```
FAILURE: Build failed with an exception.
Could not write to file. No space left on device.
```

**Solución:**
```bash
# Limpiar caches de Flutter
flutter clean
flutter pub cache repair

# Limpiar cache de Gradle (Windows)
rmdir /s "%USERPROFILE%\.gradle\caches"
```

---

### 🔧 **Error: "Gradle daemon disappeared unexpectedly"**

**Síntomas:**
```
Gradle build daemon disappeared unexpectedly
```

**Solución:**
```bash
# En el directorio android/ del proyecto:
cd android
./gradlew --stop
./gradlew clean
cd ..
flutter build apk --release
```

---

### ⚠️ **Error: "Android SDK not found"**

**Síntomas:**
```
No Android SDK found. Try setting the ANDROID_SDK_ROOT environment variable.
```

**Solución:**
```bash
# Verificar instalación
flutter doctor

# Si falta SDK, descargar Android Studio
# O configurar variable de entorno:
# ANDROID_SDK_ROOT = C:\Users\[usuario]\AppData\Local\Android\Sdk
```

---

## 🌐 **ERRORES DE WEB**

### 🗄️ **Error: "databaseFactory not initialized" (SQLite en Web)**

**Síntomas:**
```
Bad state: databaseFactory not initialized
databaseFactory is only initialized when using sqflite
```

**Causa:** SQLite no funciona nativamente en navegadores web.

**Solución:** 
- ✅ **Ya implementada en tu proyecto** - detección automática de plataforma
- Para otros proyectos: usar IndexedDB o Hive para web

---

### 🔌 **Error: "XMLHttpRequest error" en Web**

**Síntomas:**
```
Error: XMLHttpRequest error.
Target URL: http://localhost:XXXXX
```

**Solución:**
```bash
# Ejecutar en puerto específico
flutter run -d web-server --web-port 8080 --web-renderer canvaskit

# O usar auto-port
flutter run -d web-server
```

---

## 📦 **ERRORES DE DEPENDENCIAS**

### ⬇️ **Error: "pub get failed"**

**Síntomas:**
```
Running "flutter pub get" in project...
pub get failed
```

**Solución:**
```bash
# Limpiar cache de pub
flutter pub cache repair
flutter clean
flutter pub get

# Si persiste, revisar pubspec.yaml por errores de sintaxis
```

---

### 🔄 **Error: "Version conflict"**

**Síntomas:**
```
Because project depends on X ^1.0.0 and Y ^2.0.0...
version solving failed.
```

**Solución:**
```bash
# Ver conflictos específicos
flutter pub outdated

# Forzar resolución (cuidado)
flutter pub upgrade

# O ajustar versiones manualmente en pubspec.yaml
```

---

## 🖥️ **ERRORES DE DESARROLLO**

### ⚡ **Error: "Hot reload failed"**

**Síntomas:**
```
Hot reload is not supported
```

**Solución:**
```bash
# Reinicio completo
r  # En terminal de flutter run

# O reiniciar aplicación completa
R  # En terminal de flutter run
```

---

### 🎨 **Error: "Widget gris/sin estilos"**

**Síntomas:** Widgets aparecen sin estilos o en gris.

**Causa:** Errores de compilación no resueltos.

**Solución:**
```bash
# Verificar errores
flutter analyze

# Revisar imports faltantes
# Verificar que todos los archivos existan
```

---

### 🔍 **Error: "Target of URI doesn't exist"**

**Síntomas:**
```
Target of URI doesn't exist: 'package:mi_package/archivo.dart'
```

**Solución:**
1. Verificar que el archivo existe
2. Revisar nombre del import (case-sensitive)
3. Ejecutar `flutter pub get` si es package externo

---

## 📱 **ERRORES DE DISPOSITIVOS**

### 🔌 **Error: "No devices found"**

**Síntomas:**
```
No supported devices connected.
```

**Solución:**
```bash
# Ver dispositivos disponibles
flutter devices

# Para Android:
# 1. Habilitar "Opciones de desarrollador"
# 2. Activar "Depuración USB"
# 3. Conectar por USB y autorizar PC

# Para emulador:
# Abrir Android Studio → AVD Manager → Start emulator
```

---

### ⚠️ **Error: "Insufficient storage" en dispositivo**

**Síntomas:**
```
Installation failed due to insufficient storage
```

**Solución:**
1. Liberar espacio en el dispositivo (mín. 100MB)
2. Desinstalar versiones anteriores de la app
3. Usar `flutter install` en lugar de `flutter run`

---

## 🐞 **ERRORES DE RUNTIME**

### ❌ **Error: "setState() called after dispose()"**

**Síntomas:**
```
setState() called after dispose()
```

**Solución:**
```dart
// Verificar si widget aún está montado
if (mounted) {
  setState(() {
    // Actualizar estado
  });
}
```

---

### 🔄 **Error: "RenderFlex overflowed"**

**Síntomas:** Widgets se salen de pantalla con franjas amarillas/negras.

**Solución:**
```dart
// Envolver en Flexible o Expanded
Expanded(
  child: Column(children: [...])
)

// O usar SingleChildScrollView
SingleChildScrollView(
  child: Column(children: [...])
)
```

---

### 🎯 **Error: "Navigator operation requested with a context that does not include a Navigator"**

**Síntomas:**
```
Navigator operation requested with a context that does not include a Navigator
```

**Solución:**
```dart
// Asegurar que context tenga Navigator
// Usar dentro de MaterialApp/CupertinoApp
// O usar GlobalKey<NavigatorState>
```

---

## 🛠️ **COMANDOS DE DIAGNÓSTICO**

### 🩺 **Comando universal de diagnóstico:**
```bash
flutter doctor -v
```

### 📋 **Verificar configuración completa:**
```bash
flutter doctor
flutter devices
flutter analyze
flutter test
```

### 🧹 **Limpiar todo (reset completo):**
```bash
flutter clean
flutter pub cache repair  
rm -rf android/.gradle (Linux/Mac)
rmdir /s android\.gradle (Windows)
flutter pub get
```

---

## 💡 **TIPS DE PREVENCIÓN**

### ✅ **Antes de cada compilación:**
1. Cerrar Android Studio
2. Detener otros procesos Flutter
3. Verificar espacio en disco (>1GB libre)
4. Comprobar conexión a internet

### 📝 **Para desarrollo:**
1. Usar `flutter analyze` regularmente
2. Comitear código funcionando antes de cambios grandes
3. Mantener dependencias actualizadas
4. Usar `flutter clean` si algo se comporta extraño

### 🔄 **Para builds:**
1. Probar en debug antes de release
2. Verificar permisos en AndroidManifest.xml
3. Testear en dispositivo real, no solo emulador
4. Generar APK firmado para distribución

---

## 📞 **RECURSOS ADICIONALES**

- **Flutter Doctor:** `flutter doctor -v`
- **Logs detallados:** `flutter run --verbose`
- **Stack traces:** `flutter run --debug`
- **Documentación oficial:** [docs.flutter.dev](https://docs.flutter.dev)
- **Issues conocidos:** [github.com/flutter/flutter/issues](https://github.com/flutter/flutter/issues)

---

**💡 Regla de oro:** Cuando tengas dudas, `flutter clean` + `flutter pub get` resuelve el 80% de los problemas raros.
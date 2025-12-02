# Configuración de Firebase para Android

## Problema Detectado
El APK no sincroniza porque Firebase para Android no está configurado correctamente.

En `lib/firebase_options.dart`, la configuración para Android tiene placeholders:
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyC4brDdK_zyhopxv4QaNghAgy1GMuvUX6A',
  appId: '1:142497052230:android:TU_ANDROID_APP_ID_AQUI', // ← PLACEHOLDER!
  messagingSenderId: '142497052230',
  projectId: 'fluttergastos-7b824',
);
```

## Solución

1. **Ir a Firebase Console:**
   - https://console.firebase.google.com/
   - Proyecto: `fluttergastos-7b824`

2. **Agregar app Android:**
   - Click en "Agregar app" → Android
   - Package name: `com.example.expense_tracker` (del build.gradle)
   - Descargar `google-services.json`

3. **Copiar el archivo:**
   - Mover `google-services.json` a `android/app/`

4. **Instalar Firebase CLI e configurar:**
   ```bash
   # Instalar Firebase CLI oficial
   npm install -g firebase-tools
   
   # Login a Firebase
   firebase login
   
   # Instalar FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Regenerar configuración automáticamente (usando ruta completa)
   C:\Users\usuario\AppData\Local\Pub\Cache\bin\flutterfire.bat configure
   ```

5. **Verificar build.gradle:**
   - `android/app/build.gradle` debe tener:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

## Resultado Esperado
Después de esto, el APK debería sincronizar correctamente con Firestore.

## Debugging Actual
He agregado logging detallado que mostrará exactamente dónde falla:
- Firebase inicialización ✅
- Usuario autenticado ✅
- Consulta a Firestore ❓
- Resultado de sincronización ❓

## Prueba Rápida
Para verificar si es el problema de configuración:

1. Build APK con logging:
   ```bash
   flutter build apk --debug
   flutter install
   ```

2. Ver logs mientras usas la app:
   ```bash
   flutter logs
   ```

3. Buscar estos mensajes:
   - `❌ Firebase no está inicializado`
   - `❌ syncFromFirestore: No hay usuario autenticado`  
   - `❌ Error en sync from Firestore: [PERMISO_DENEGADO]`
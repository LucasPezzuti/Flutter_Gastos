# 🔥 Firebase Setup Guide - Flutter App

## 📋 **Resumen Completo de Configuración Firebase**

### **Contexto**
Integración de Firebase en app Flutter existente para:
- Auth real (reemplazar usuarios hardcodeados)
- Sync de datos con Firestore
- Funcionalidad offline + online

---

## 🚀 **PASO 1: Crear Proyecto Firebase**

### **1.1 Console Firebase**
1. Ir a: https://console.firebase.google.com/
2. **"Crear proyecto"** → Nombre: `fluttergastos-7b824`
3. **Desactivar Google Analytics** (opcional)
4. **Crear proyecto** ✅

### **1.2 Activar Servicios**
```bash
# En Firebase Console:
1. Authentication → Comenzar → Email/Password ✅
2. Firestore Database → Crear → Modo prueba ✅
3. Reglas por defecto (30 días de prueba)
```

---

## 📱 **PASO 2: Registrar App Web**

### **2.1 Configuración Web**
```javascript
// En Console → Configuración → Agregar app → Web
1. Alias: expense-tracker-web
2. Firebase Hosting: ✅ (opcional)
3. Registrar app

// Resultado:
const firebaseConfig = {
  apiKey: "AIzaSyC4brDdK_zyhopxv4QaNghAgy1GMuvUX6A",
  authDomain: "fluttergastos-7b824.firebaseapp.com", 
  projectId: "fluttergastos-7b824",
  storageBucket: "fluttergastos-7b824.firebasestorage.app",
  messagingSenderId: "142497052230",
  appId: "1:142497052230:web:912769e832cfdd52137c47",
  measurementId: "G-3GD3TDZ1TW"
};
```

---

## 🛠️ **PASO 3: Flutter Dependencies**

### **3.1 pubspec.yaml**
```yaml
dependencies:
  # Firebase Core
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1  
  cloud_firestore: ^5.4.3
  
  # Existing dependencies...
  sqflite: ^2.3.0
  flutter_secure_storage: ^9.0.0
```

### **3.2 Obtener dependencies**
```bash
flutter pub get
```

---

## ⚙️ **PASO 4: Configuración de Flutter**

### **4.1 firebase_options.dart**
```dart
// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    // Agregar Android/iOS según necesites
    throw UnsupportedError('Platform not configured');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC4brDdK_zyhopxv4QaNghAgy1GMuvUX6A',
    appId: '1:142497052230:web:912769e832cfdd52137c47',
    messagingSenderId: '142497052230',
    projectId: 'fluttergastos-7b824',
    authDomain: 'fluttergastos-7b824.firebaseapp.com',
    storageBucket: 'fluttergastos-7b824.firebasestorage.app',
    measurementId: 'G-3GD3TDZ1TW',
  );
}
```

### **4.2 main.dart**
```dart
// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔥 Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(MyApp());
}
```

---

## 🔐 **PASO 5: Servicio Firebase Auth**

### **5.1 firebase_auth_service.dart**
```dart
// lib/services/firebase_auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Login
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
    } catch (e) {
      print('Error login: $e');
      return null;
    }
  }

  // Registro
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
    } catch (e) {
      print('Error registro: $e');
      return null;
    }
  }

  // Usuario actual
  User? get currentUser => _auth.currentUser;
  
  // Logout
  Future<void> signOut() => _auth.signOut();
  
  // Stream de cambios de auth
  Stream<User?> get authChanges => _auth.authStateChanges();
}
```

---

## 💾 **PASO 6: Firestore Service**

### **6.1 firestore_service.dart**
```dart
// lib/services/firestore_service.dart  
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Gastos collection
  CollectionReference get expenses => 
    _db.collection('expenses');

  // Categorías collection  
  CollectionReference get categories => 
    _db.collection('categories');

  // CRUD genérico
  Future<void> create(String collection, Map<String, dynamic> data) {
    return _db.collection(collection).add(data);
  }

  Future<QuerySnapshot> read(String collection) {
    return _db.collection(collection).get();
  }

  Stream<QuerySnapshot> stream(String collection) {
    return _db.collection(collection).snapshots();
  }
}
```

---

## 🔄 **PASO 7: Arquitectura Híbrida**

### **7.1 Estrategia Local + Cloud**
```dart
// Mantener SQLite para offline
// Sync con Firestore cuando hay internet

class HybridDataService {
  final DatabaseHelper _local = DatabaseHelper();
  final FirestoreService _cloud = FirestoreService();

  // Guardar local + sync cloud
  Future<void> saveExpense(Expense expense) async {
    // 1. Guardar local (offline)
    await _local.insertExpense(expense);
    
    // 2. Sync cloud (si hay internet)
    try {
      await _cloud.create('expenses', expense.toMap());
    } catch (e) {
      // Marcar para sync posterior
    }
  }
}
```

---

## 🎯 **PASO 8: Testing & Deployment**

### **8.1 Web Testing**
```bash
flutter run -d chrome
# Verificar console de Firebase para conexión
```

### **8.2 Android Setup (futuro)**
```bash
# Instalar Firebase CLI
npm install -g firebase-tools
firebase login

# FlutterFire CLI
dart pub global activate flutterfire_cli
flutterfire configure --project=fluttergastos-7b824
```

---

## 🔧 **Configuraciones Adicionales**

### **9.1 Firestore Rules (Seguridad)**
```javascript
// En Console → Firestore → Rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Solo usuarios autenticados
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### **9.2 Authentication Settings**
```javascript
// En Console → Authentication → Settings
- Email enumeration protection: ✅
- Email verification: ✅ (opcional)
- Password policy: Default
```

---

## 📝 **Checklist para Replicar**

### **✅ Pasos Esenciales:**
- [ ] Crear proyecto Firebase
- [ ] Activar Auth + Firestore  
- [ ] Registrar app web
- [ ] Copiar claves a firebase_options.dart
- [ ] Agregar dependencies
- [ ] Inicializar en main.dart
- [ ] Crear servicios Auth + Firestore
- [ ] Testing en web

### **🔮 Próximos Pasos:**
- [ ] Migrar login a Firebase Auth
- [ ] Sync data con Firestore
- [ ] Manejar estados offline/online
- [ ] Configurar Android/iOS

---

## 🚨 **Notas Importantes**

1. **Firestore Rules**: Cambiar de "modo prueba" a reglas de producción antes de deploy
2. **API Keys**: Las keys de web son públicas, la seguridad está en las rules
3. **Offline**: Firestore tiene persistencia offline automática  
4. **Costs**: Plan gratuito suficiente para desarrollo, revisar límites antes de producción

---

**Este setup te da una base sólida para cualquier app Flutter + Firebase.** 🔥
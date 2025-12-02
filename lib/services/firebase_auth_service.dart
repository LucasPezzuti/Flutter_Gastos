import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app_user;
import '../models/auth_response.dart';

/// Servicio de autenticación con Firebase
/// 
/// Reemplaza el sistema de usuarios hardcodeados con Firebase Auth
/// y sincroniza datos de usuarios en Firestore
class FirebaseAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registra un nuevo usuario
  Future<AuthResponse> register({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      print('🔥 Firebase: Registrando usuario $email');
      
      // Crear usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return AuthResponse(
          success: false,
          message: 'Error al crear usuario',
          user: app_user.User(
            id: 0, 
            email: email,
            createdAt: DateTime.now(),
          ),
          token: '',
          expiresAt: DateTime.now(),
        );
      }

      // Actualizar nombre de usuario en Firebase
      if (name != null && name.isNotEmpty) {
        await firebaseUser.updateDisplayName(name);
      }

      // Crear documento del usuario en Firestore
      final appUser = app_user.User(
        id: firebaseUser.uid.hashCode, // Convertir UID a int
        email: email,
        name: name ?? email.split('@')[0],
        createdAt: DateTime.now(),
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'id': appUser.id,
        'email': appUser.email,
        'name': appUser.name,
        'created_at': appUser.createdAt.toIso8601String(),
        'firebase_uid': firebaseUser.uid,
      });

      print('✅ Firebase: Usuario registrado exitosamente');

      return AuthResponse(
        success: true,
        message: 'Usuario registrado exitosamente',
        user: appUser,
        token: await firebaseUser.getIdToken() ?? '',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Error de registro';
      
      switch (e.code) {
        case 'weak-password':
          message = 'La contraseña es muy débil';
          break;
        case 'email-already-in-use':
          message = 'Este email ya está registrado';
          break;
        case 'invalid-email':
          message = 'Email inválido';
          break;
        default:
          message = e.message ?? 'Error desconocido';
      }

      print('❌ Firebase: Error de registro: $message');

      return AuthResponse(
        success: false,
        message: message,
        user: app_user.User(
          id: 0, 
          email: email,
          createdAt: DateTime.now(),
        ),
        token: '',
        expiresAt: DateTime.now(),
      );
    } catch (e) {
      print('❌ Firebase: Error inesperado: $e');
      
      return AuthResponse(
        success: false,
        message: 'Error inesperado: $e',
        user: app_user.User(
          id: 0, 
          email: email,
          createdAt: DateTime.now(),
        ),
        token: '',
        expiresAt: DateTime.now(),
      );
    }
  }

  /// Inicia sesión con email y password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔥 Firebase: Iniciando sesión para $email');

      // Autenticar con Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return AuthResponse(
          success: false,
          message: 'Error en autenticación',
          user: app_user.User(
            id: 0, 
            email: email,
            createdAt: DateTime.now(),
          ),
          token: '',
          expiresAt: DateTime.now(),
        );
      }

      // Obtener datos del usuario desde Firestore
      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      
      app_user.User appUser;
      if (userDoc.exists) {
        final data = userDoc.data()!;
        appUser = app_user.User(
          id: data['id'] as int,
          email: data['email'] as String,
          name: data['name'] as String?,
          createdAt: DateTime.parse(data['created_at'] as String),
        );
      } else {
        // Si no existe el documento, crearlo (usuarios migrados)
        appUser = app_user.User(
          id: firebaseUser.uid.hashCode,
          email: firebaseUser.email!,
          name: firebaseUser.displayName ?? firebaseUser.email!.split('@')[0],
          createdAt: DateTime.now(),
        );

        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'id': appUser.id,
          'email': appUser.email,
          'name': appUser.name,
          'created_at': appUser.createdAt.toIso8601String(),
          'firebase_uid': firebaseUser.uid,
        });
      }

      print('✅ Firebase: Login exitoso para ${appUser.name}');

      return AuthResponse(
        success: true,
        message: 'Login exitoso',
        user: appUser,
        token: await firebaseUser.getIdToken() ?? '',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Error de autenticación';
      
      switch (e.code) {
        case 'user-not-found':
          message = 'Usuario no encontrado';
          break;
        case 'wrong-password':
          message = 'Contraseña incorrecta';
          break;
        case 'invalid-email':
          message = 'Email inválido';
          break;
        case 'user-disabled':
          message = 'Usuario deshabilitado';
          break;
        case 'too-many-requests':
          message = 'Demasiados intentos. Intenta más tarde';
          break;
        default:
          message = e.message ?? 'Error desconocido';
      }

      print('❌ Firebase: Error de login: $message');

      return AuthResponse(
        success: false,
        message: message,
        user: app_user.User(
          id: 0, 
          email: email,
          createdAt: DateTime.now(),
        ),
        token: '',
        expiresAt: DateTime.now(),
      );
    } catch (e) {
      print('❌ Firebase: Error inesperado: $e');
      
      return AuthResponse(
        success: false,
        message: 'Error inesperado: $e',
        user: app_user.User(
          id: 0, 
          email: email,
          createdAt: DateTime.now(),
        ),
        token: '',
        expiresAt: DateTime.now(),
      );
    }
  }

  /// Cierra sesión
  Future<void> logout() async {
    try {
      print('🔥 Firebase: Cerrando sesión');
      await _auth.signOut();
      print('✅ Firebase: Sesión cerrada exitosamente');
    } catch (e) {
      print('❌ Firebase: Error al cerrar sesión: $e');
    }
  }

  /// Obtiene el usuario actual autenticado
  User? get currentUser => _auth.currentUser;

  /// Verifica si hay un usuario autenticado
  bool get isAuthenticated => _auth.currentUser != null;

  /// Stream de cambios de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Obtiene el usuario de la aplicación desde Firestore
  Future<app_user.User?> getCurrentAppUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (!userDoc.exists) return null;

      final data = userDoc.data()!;
      return app_user.User(
        id: data['id'] as int,
        email: data['email'] as String,
        name: data['name'] as String?,
        createdAt: DateTime.parse(data['created_at'] as String),
      );
    } catch (e) {
      print('❌ Firebase: Error obteniendo usuario: $e');
      return null;
    }
  }

  /// Envía email de reset de contraseña
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      print('🔥 Firebase: Enviando reset de contraseña a $email');
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Firebase: Email de reset enviado');
      return true;
    } catch (e) {
      print('❌ Firebase: Error enviando reset: $e');
      return false;
    }
  }

  /// Actualiza el perfil del usuario
  Future<bool> updateProfile({String? name, String? photoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.updateDisplayName(name);
      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl);
      }

      // Actualizar también en Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'name': name,
        'updated_at': DateTime.now().toIso8601String(),
      });

      print('✅ Firebase: Perfil actualizado');
      return true;
    } catch (e) {
      print('❌ Firebase: Error actualizando perfil: $e');
      return false;
    }
  }
}
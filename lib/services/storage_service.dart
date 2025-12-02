import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';

/// Servicio para almacenar datos de sesión de forma segura
/// 
/// Usa FlutterSecureStorage para datos sensibles (token)
/// y SharedPreferences para datos no sensibles (preferencias)
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Almacenamiento seguro para tokens
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device, // Acceso después de primer unlock
    ),
  );

  // Keys para almacenamiento
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _syncDoneKey = 'initial_sync_done'; // Flag para sincronización única

  /// Guarda los datos de sesión después de login exitoso
  Future<void> saveSession({
    required String token,
    required User user,
    required DateTime expiresAt,
  }) async {
    try {
      print('🔍 DEBUG saveSession: Guardando usuario ${user.email} con ID: ${user.id}');
      
      // Token en almacenamiento seguro
      await _secureStorage.write(key: _tokenKey, value: token);
      
      // Datos del usuario en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, json.encode(user.toMap()));
      await prefs.setString(_tokenExpiryKey, expiresAt.toIso8601String());
      await prefs.setBool(_isLoggedInKey, true);
      
      print('💾 Sesión guardada para ${user.email}');
      
      // Verificar que se guardó correctamente
      final savedUser = await getCurrentUser();
      print('🔍 DEBUG saveSession: Usuario guardado verificado - ${savedUser?.email}, ID: ${savedUser?.id}');
    } catch (e) {
      print('❌ Error guardando sesión: $e');
      throw Exception('Error al guardar sesión');
    }
  }

  /// Obtiene el token de autenticación
  Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      print('❌ Error obteniendo token: $e');
      return null;
    }
  }

  /// Obtiene el usuario actual guardado
  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      
      print('🔍 DEBUG getCurrentUser: userJson = $userJson');
      
      if (userJson == null) {
        print('🔍 DEBUG getCurrentUser: No hay usuario guardado');
        return null;
      }
      
      final userMap = json.decode(userJson) as Map<String, dynamic>;
      final user = User.fromMap(userMap);
      
      print('🔍 DEBUG getCurrentUser: Usuario cargado - ${user.email}, ID: ${user.id}');
      return user;
    } catch (e) {
      print('❌ Error obteniendo usuario: $e');
      return null;
    }
  }

  /// Verifica si el usuario está logueado
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      
      if (!isLoggedIn) return false;
      
      // Verificar si el token no ha expirado
      final expiryString = prefs.getString(_tokenExpiryKey);
      if (expiryString == null) return false;
      
      final expiry = DateTime.parse(expiryString);
      final isExpired = DateTime.now().isAfter(expiry);
      
      if (isExpired) {
        print('⏰ Token expirado, limpiando sesión');
        await clearSession();
        return false;
      }
      
      return true;
    } catch (e) {
      print('❌ Error verificando login: $e');
      return false;
    }
  }

  /// Obtiene la fecha de expiración del token
  Future<DateTime?> getTokenExpiry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryString = prefs.getString(_tokenExpiryKey);
      
      if (expiryString == null) return null;
      return DateTime.parse(expiryString);
    } catch (e) {
      print('❌ Error obteniendo expiración: $e');
      return null;
    }
  }

  /// Limpia todos los datos de sesión (logout)
  Future<void> clearSession() async {
    try {
      // Limpiar almacenamiento seguro
      await _secureStorage.delete(key: _tokenKey);
      
      // Limpiar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      await prefs.remove(_tokenExpiryKey);
      await prefs.setBool(_isLoggedInKey, false);
      await prefs.remove(_syncDoneKey); // ← Limpiar flag de sync también
      
      print('🧹 Sesión limpiada completamente');
    } catch (e) {
      print('❌ Error limpiando sesión: $e');
    }
  }

  /// Actualiza el token (para refresh)
  Future<void> updateToken({
    required String newToken,
    required DateTime expiresAt,
  }) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: newToken);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenExpiryKey, expiresAt.toIso8601String());
      
      print('🔄 Token actualizado');
    } catch (e) {
      print('❌ Error actualizando token: $e');
      throw Exception('Error al actualizar token');
    }
  }

  /// Debug: Muestra información de la sesión actual
  Future<void> debugSessionInfo() async {
    try {
      final token = await getToken();
      final user = await getCurrentUser();
      final expiry = await getTokenExpiry();
      final isLoggedIn = await this.isLoggedIn();
      
      print('🔍 === DEBUG SESIÓN ===');
      print('Token: ${token?.substring(0, 20) ?? 'null'}...');
      print('Usuario: ${user?.email ?? 'null'}');
      print('Expira: ${expiry?.toLocal() ?? 'null'}');
      print('Logueado: $isLoggedIn');
      print('======================');
    } catch (e) {
      print('❌ Error en debug: $e');
    }
  }

  /// Marca que la sincronización inicial ya se realizó
  Future<void> markSyncDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_syncDoneKey, true);
      print('✅ Sincronización inicial marcada como completada');
    } catch (e) {
      print('❌ Error marcando sync como done: $e');
    }
  }

  /// Verifica si la sincronización inicial ya se realizó
  Future<bool> isSyncDone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDone = prefs.getBool(_syncDoneKey) ?? false;
      print('🔍 isSyncDone: $isDone');
      return isDone;
    } catch (e) {
      print('❌ Error verificando si sync está done: $e');
      return false;
    }
  }

  /// Limpia el flag de sincronización (usado al logout)
  Future<void> clearSyncFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syncDoneKey);
      print('🧹 Flag de sincronización limpiado');
    } catch (e) {
      print('❌ Error limpiando flag de sync: $e');
    }
  }
}
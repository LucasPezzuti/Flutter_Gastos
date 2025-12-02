import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../models/user.dart';
import '../models/auth_response.dart';

/// Servicio de autenticación simulado
/// 
/// Simula una API real con usuarios hardcodeados y tokens JWT falsos
/// En una app real, esto sería llamadas HTTP a un servidor
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Usuarios simulados (como si vinieran de una base de datos del servidor)
  static final List<Map<String, dynamic>> _mockUsers = [
    {
      'id': 1,
      'email': 'admin@test.com',
      'password_hash': _hashPassword('123456'),
      'name': 'Administrador',
      'created_at': '2024-01-01T00:00:00.000Z',
    },
    {
      'id': 2,
      'email': 'user@test.com',
      'password_hash': _hashPassword('password'),
      'name': 'Usuario Demo',
      'created_at': '2024-06-15T10:30:00.000Z',
    },
    {
      'id': 3,
      'email': 'demo@test.com',
      'password_hash': _hashPassword('demo'),
      'name': 'Usuario Prueba',
      'created_at': '2024-11-01T14:20:00.000Z',
    },
  ];

  /// Simula hash de password (en API real sería bcrypt o similar)
  static String _hashPassword(String password) {
    final bytes = utf8.encode(password + 'salt123');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Simula login a API
  /// 
  /// Delay de 1-2 segundos para simular request de red
  Future<AuthResponse> login(String email, String password) async {
    print('🔐 Simulando login para: $email');
    
    // Simular delay de red (como si fuera request HTTP)
    await Future.delayed(Duration(milliseconds: 1000 + Random().nextInt(1000)));
    
    try {
      // Buscar usuario por email
      final userData = _mockUsers.firstWhere(
        (user) => user['email'].toString().toLowerCase() == email.toLowerCase(),
        orElse: () => throw Exception('Usuario no encontrado'),
      );
      
      // Verificar password
      final passwordHash = _hashPassword(password);
      if (userData['password_hash'] != passwordHash) {
        print('❌ Password incorrecto para $email');
        return AuthResponse.error('Email o contraseña incorrectos');
      }
      
      // Crear usuario
      final user = User(
        id: userData['id'] as int,
        email: userData['email'] as String,
        name: userData['name'] as String,
        createdAt: DateTime.parse(userData['created_at'] as String),
      );
      
      // Generar token JWT simulado
      final token = _generateFakeJWT(user);
      final expiresAt = DateTime.now().add(Duration(hours: 24));
      
      print('✅ Login exitoso para ${user.email}');
      
      return AuthResponse(
        token: token,
        user: user,
        expiresAt: expiresAt,
        success: true,
        message: 'Login exitoso',
      );
      
    } catch (e) {
      print('❌ Error en login: $e');
      return AuthResponse.error('Email o contraseña incorrectos');
    }
  }

  /// Genera un token JWT falso pero realista
  String _generateFakeJWT(User user) {
    // Header JWT simulado
    final header = base64Url.encode(utf8.encode(json.encode({
      'typ': 'JWT',
      'alg': 'HS256'
    })));
    
    // Payload JWT simulado
    final payload = base64Url.encode(utf8.encode(json.encode({
      'user_id': user.id,
      'email': user.email,
      'name': user.name,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
    })));
    
    // Signature falsa
    final signature = base64Url.encode(utf8.encode('fake_signature_${Random().nextInt(99999)}'));
    
    return '$header.$payload.$signature';
  }

  /// Valida si un token es válido (simulado)
  Future<bool> validateToken(String token) async {
    print('🔍 Validando token...');
    
    // Simular delay de validación
    await Future.delayed(Duration(milliseconds: 300));
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      
      // Decodificar payload
      final payload = json.decode(utf8.decode(base64Url.decode(parts[1])));
      final exp = payload['exp'] as int;
      
      // Verificar si no ha expirado
      final isValid = DateTime.now().millisecondsSinceEpoch ~/ 1000 < exp;
      
      print(isValid ? '✅ Token válido' : '❌ Token expirado');
      return isValid;
      
    } catch (e) {
      print('❌ Token inválido: $e');
      return false;
    }
  }

  /// Obtiene información del usuario desde el token
  User? getUserFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = json.decode(utf8.decode(base64Url.decode(parts[1])));
      
      return User(
        id: payload['user_id'] as int,
        email: payload['email'] as String,
        name: payload['name'] as String?,
        createdAt: DateTime.now(), // Placeholder, en real vendría del payload
      );
      
    } catch (e) {
      print('❌ Error extrayendo usuario del token: $e');
      return null;
    }
  }

  /// Simula logout (invalida token en servidor real)
  Future<void> logout() async {
    print('👋 Simulando logout...');
    await Future.delayed(Duration(milliseconds: 500));
    print('✅ Logout completado');
  }

  /// Simula refresh de token
  Future<AuthResponse?> refreshToken(String oldToken) async {
    print('🔄 Simulando refresh de token...');
    await Future.delayed(Duration(milliseconds: 800));
    
    final user = getUserFromToken(oldToken);
    if (user == null) return null;
    
    // Generar nuevo token
    final newToken = _generateFakeJWT(user);
    final expiresAt = DateTime.now().add(Duration(hours: 24));
    
    print('✅ Token renovado para ${user.email}');
    
    return AuthResponse(
      token: newToken,
      user: user,
      expiresAt: expiresAt,
      success: true,
      message: 'Token renovado',
    );
  }

  /// Lista usuarios disponibles (solo para debug/demo)
  List<String> getAvailableTestUsers() {
    return _mockUsers.map((user) => 
      '${user['email']} (password: ${_getOriginalPassword(user['email'])})'
    ).toList();
  }

  /// Helper para mostrar passwords en demo
  String _getOriginalPassword(String email) {
    switch (email) {
      case 'admin@test.com': return '123456';
      case 'user@test.com': return 'password';
      case 'demo@test.com': return 'demo';
      default: return '???';
    }
  }
}
import 'user.dart';

/// Respuesta de autenticación simulada
/// 
/// Simula la respuesta que vendría de una API real
class AuthResponse {
  final String token;
  final User user;
  final DateTime expiresAt;
  final bool success;
  final String? message;

  AuthResponse({
    required this.token,
    required this.user,
    required this.expiresAt,
    this.success = true,
    this.message,
  });

  /// Crea una respuesta de error
  AuthResponse.error(this.message)
      : token = '',
        user = User(id: 0, email: '', createdAt: DateTime.now()),
        expiresAt = DateTime.now(),
        success = false;

  /// Convierte de JSON (para simular respuesta de API)
  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: User.fromMap(json['user'] as Map<String, dynamic>),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
    );
  }

  /// Convierte a JSON (para simular respuesta de API)
  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toMap(),
      'expires_at': expiresAt.toIso8601String(),
      'success': success,
      'message': message,
    };
  }

  @override
  String toString() {
    return 'AuthResponse{success: $success, user: ${user.email}, expires: $expiresAt}';
  }
}
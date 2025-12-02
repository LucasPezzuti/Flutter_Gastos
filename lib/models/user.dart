/// Modelo de datos para usuarios
/// 
/// Representa un usuario de la aplicación con información básica
/// Almacenado localmente para evitar requests constantes
class User {
  final int id;
  final String email;
  final String? name;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.name,
    required this.createdAt,
  });

  /// Convierte un Map de la base de datos a un objeto User
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      email: map['email'] as String,
      name: map['name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convierte el objeto User a un Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crea una copia del objeto con algunos valores modificados
  User copyWith({
    int? id,
    String? email,
    String? name,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User{id: $id, email: $email, name: $name, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.name == name &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^ email.hashCode ^ name.hashCode ^ createdAt.hashCode;
  }
}
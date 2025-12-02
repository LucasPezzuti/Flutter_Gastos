/// Modelo de datos para las categorías de gastos
/// 
/// Este modelo representa una categoría que puede ser asignada a los gastos
/// para organizarlos mejor (ej: Comida, Transporte, Entretenimiento, etc.)
class Category {
  final int? id;
  final String name;
  final String icon; // Nombre del icono de Material Icons
  final String color; // Color hexadecimal como String

  Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  /// Convierte un Map de la base de datos a un objeto Category
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
    );
  }

  /// Convierte el objeto Category a un Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
    };
  }

  /// Crea una copia del objeto con algunos valores modificados
  Category copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name, icon: $icon, color: $color}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.color == color;
  }

  @override
  int get hashCode {
    return id.hashCode ^ name.hashCode ^ icon.hashCode ^ color.hashCode;
  }
}
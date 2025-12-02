/// Modelo para representar presupuestos mensuales por categoría
/// 
/// Un presupuesto define un límite de gasto para una categoría específica
/// en un período determinado (mensual)
class Budget {
  final int? id;
  final int categoryId;
  final int userId;
  final double amount; // Monto del presupuesto
  final int month; // 1-12
  final int year;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Budget({
    this.id,
    required this.categoryId,
    required this.userId,
    required this.amount,
    required this.month,
    required this.year,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crea una instancia de Budget desde un Map (base de datos)
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      userId: map['user_id'] as int,
      amount: map['amount'] as double,
      month: map['month'] as int,
      year: map['year'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Convierte la instancia de Budget a un Map (para base de datos)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'user_id': userId,
      'amount': amount,
      'month': month,
      'year': year,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crea una copia de Budget con algunos valores modificados
  Budget copyWith({
    int? id,
    int? categoryId,
    int? userId,
    double? amount,
    int? month,
    int? year,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      month: month ?? this.month,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Budget &&
      other.id == id &&
      other.categoryId == categoryId &&
      other.userId == userId &&
      other.amount == amount &&
      other.month == month &&
      other.year == year &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      categoryId.hashCode ^
      userId.hashCode ^
      amount.hashCode ^
      month.hashCode ^
      year.hashCode ^
      createdAt.hashCode ^
      updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'Budget(id: $id, categoryId: $categoryId, userId: $userId, amount: $amount, month: $month, year: $year, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  /// Obtiene la clave única para este presupuesto (combinando categoría, mes y año)
  String get key => '${categoryId}_${month}_$year';

  /// Verifica si este presupuesto es para el mes/año actual
  bool get isCurrentMonth {
    final now = DateTime.now();
    return month == now.month && year == now.year;
  }

  /// Calcula el porcentaje gastado basado en el monto total gastado
  double getSpentPercentage(double spentAmount) {
    if (amount <= 0) return 0.0;
    return (spentAmount / amount) * 100;
  }

  /// Calcula el monto restante del presupuesto
  double getRemainingAmount(double spentAmount) {
    return amount - spentAmount;
  }

  /// Verifica si el presupuesto ha sido excedido
  bool isExceeded(double spentAmount) {
    return spentAmount > amount;
  }

  /// Obtiene el estado del presupuesto basado en el porcentaje gastado
  BudgetStatus getStatus(double spentAmount) {
    final percentage = getSpentPercentage(spentAmount);
    
    if (percentage >= 100) {
      return BudgetStatus.exceeded;
    } else if (percentage >= 80) {
      return BudgetStatus.warning;
    } else if (percentage >= 50) {
      return BudgetStatus.onTrack;
    } else {
      return BudgetStatus.safe;
    }
  }
}

/// Enum para el estado del presupuesto
enum BudgetStatus {
  safe,     // 0-49% gastado (verde)
  onTrack,  // 50-79% gastado (amarillo)
  warning,  // 80-99% gastado (naranja)
  exceeded, // 100%+ gastado (rojo)
}

extension BudgetStatusExtension on BudgetStatus {
  /// Obtiene el color asociado al estado
  String get colorName {
    switch (this) {
      case BudgetStatus.safe:
        return 'green';
      case BudgetStatus.onTrack:
        return 'yellow';
      case BudgetStatus.warning:
        return 'orange';
      case BudgetStatus.exceeded:
        return 'red';
    }
  }

  /// Obtiene el mensaje descriptivo del estado
  String get message {
    switch (this) {
      case BudgetStatus.safe:
        return 'Presupuesto seguro';
      case BudgetStatus.onTrack:
        return 'En buen camino';
      case BudgetStatus.warning:
        return '¡Cuidado! Cerca del límite';
      case BudgetStatus.exceeded:
        return '¡Presupuesto excedido!';
    }
  }
}
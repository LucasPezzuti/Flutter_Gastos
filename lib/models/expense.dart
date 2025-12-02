/// Modelo de datos para los gastos
/// 
/// Este modelo representa un gasto individual con todos sus detalles:
/// cantidad, descripción, fecha, categoría asociada y usuario propietario
/// También soporta gastos con tarjeta de crédito en cuotas
class Expense {
  final int? id;
  final int userId; // ← NUEVO: ID del usuario propietario
  final double amount;
  final String description;
  final DateTime date;
  final int categoryId; // ID de la categoría asociada
  
  // Campos para tarjeta de crédito
  final bool isCreditCard; // Si es gasto con tarjeta de crédito
  final int? totalInstallments; // Total de cuotas (ej: 12)
  final int? currentInstallment; // Cuota actual (ej: 3 de 12)
  final String? creditCardGroupId; // ID para agrupar todas las cuotas del mismo gasto
  final bool isPaid; // Si esta cuota específica fue pagada

  Expense({
    this.id,
    required this.userId,
    required this.amount,
    required this.description,
    required this.date,
    required this.categoryId,
    this.isCreditCard = false,
    this.totalInstallments,
    this.currentInstallment,
    this.creditCardGroupId,
    this.isPaid = false,
  });

  /// Convierte un Map de la base de datos a un objeto Expense
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      amount: map['amount'] as double,
      description: map['description'] as String,
      date: DateTime.parse(map['date'] as String),
      categoryId: map['category_id'] as int,
      isCreditCard: (map['is_credit_card'] as int?) == 1,
      totalInstallments: map['total_installments'] as int?,
      currentInstallment: map['current_installment'] as int?,
      creditCardGroupId: map['credit_card_group_id'] as String?,
      isPaid: (map['is_paid'] as int?) == 1,
    );
  }

  /// Crea un Expense desde un Map de Firestore (con booleanos reales)
  factory Expense.fromFirestoreMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String,
      date: DateTime.parse(map['date'] as String),
      categoryId: map['category_id'] as int,
      isCreditCard: map['is_credit_card'] as bool? ?? false,
      totalInstallments: map['total_installments'] as int?,
      currentInstallment: map['current_installment'] as int?,
      creditCardGroupId: map['credit_card_group_id'] as String?,
      isPaid: map['is_paid'] as bool? ?? false,
    );
  }

  /// Convierte el objeto Expense a un Map para la base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'category_id': categoryId,
      'is_credit_card': isCreditCard ? 1 : 0,
      'total_installments': totalInstallments,
      'current_installment': currentInstallment,
      'credit_card_group_id': creditCardGroupId,
      'is_paid': isPaid ? 1 : 0,
    };
  }

  /// Convierte el objeto Expense a un Map para Firestore (con booleanos reales)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'category_id': categoryId,
      'is_credit_card': isCreditCard,
      'total_installments': totalInstallments,
      'current_installment': currentInstallment,
      'credit_card_group_id': creditCardGroupId,
      'is_paid': isPaid,
    };
  }

  /// Crea una copia del objeto con algunos valores modificados
  Expense copyWith({
    int? id,
    int? userId,
    double? amount,
    String? description,
    DateTime? date,
    int? categoryId,
    bool? isCreditCard,
    int? totalInstallments,
    int? currentInstallment,
    String? creditCardGroupId,
    bool? isPaid,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      isCreditCard: isCreditCard ?? this.isCreditCard,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      currentInstallment: currentInstallment ?? this.currentInstallment,
      creditCardGroupId: creditCardGroupId ?? this.creditCardGroupId,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  /// Obtiene la descripción formateada para mostrar
  String get displayDescription {
    if (isCreditCard && currentInstallment != null && totalInstallments != null) {
      return '$description (Cuota $currentInstallment/$totalInstallments)';
    }
    return description;
  }

  @override
  String toString() {
    return 'Expense{id: $id, userId: $userId, amount: $amount, description: $description, date: $date, categoryId: $categoryId, isCreditCard: $isCreditCard, installment: $currentInstallment/$totalInstallments, isPaid: $isPaid}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Expense &&
        other.id == id &&
        other.userId == userId &&
        other.amount == amount &&
        other.description == description &&
        other.date == date &&
        other.categoryId == categoryId &&
        other.isCreditCard == isCreditCard &&
        other.totalInstallments == totalInstallments &&
        other.currentInstallment == currentInstallment &&
        other.creditCardGroupId == creditCardGroupId &&
        other.isPaid == isPaid;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        amount.hashCode ^
        description.hashCode ^
        date.hashCode ^
        categoryId.hashCode ^
        isCreditCard.hashCode ^
        totalInstallments.hashCode ^
        currentInstallment.hashCode ^
        creditCardGroupId.hashCode ^
        isPaid.hashCode;
  }
}
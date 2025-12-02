/// Modelo para representar una división de gastos entre personas
class ExpenseDivision {
  final int? id;
  final int userId; // Usuario propietario de la división
  final String name; // Nombre de la división (ej: "Febrero 2025")
  final DateTime createdAt;
  final DateTime? settledAt; // Fecha cuando se liquidó
  final double totalAmount; // Monto total dividido
  final List<int> expenseIds; // IDs de los gastos incluidos
  final List<Participant> participants; // Participantes con sus porcentajes
  final bool isSettled; // Si fue liquidada

  ExpenseDivision({
    this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    this.settledAt,
    required this.totalAmount,
    required this.expenseIds,
    required this.participants,
    this.isSettled = false,
  });

  /// Convierte a Map para guardar en base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'settled_at': settledAt?.toIso8601String(),
      'total_amount': totalAmount,
      'expense_ids': expenseIds.join(','), // Guardar como string separado por comas
      'is_settled': isSettled ? 1 : 0,
    };
  }

  /// Crea desde Map de base de datos
  factory ExpenseDivision.fromMap(Map<String, dynamic> map) {
    final expenseIdsString = map['expense_ids'] as String? ?? '';
    final expenseIds = expenseIdsString.isEmpty
        ? <int>[]
        : expenseIdsString.split(',').map((e) => int.parse(e)).toList();

    return ExpenseDivision(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      settledAt: map['settled_at'] != null
          ? DateTime.parse(map['settled_at'] as String)
          : null,
      totalAmount: (map['total_amount'] as num).toDouble(),
      expenseIds: expenseIds,
      participants: [], // Se cargan aparte
      isSettled: (map['is_settled'] as int?) == 1,
    );
  }

  /// Copia con cambios
  ExpenseDivision copyWith({
    int? id,
    int? userId,
    String? name,
    DateTime? createdAt,
    DateTime? settledAt,
    double? totalAmount,
    List<int>? expenseIds,
    List<Participant>? participants,
    bool? isSettled,
  }) {
    return ExpenseDivision(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      settledAt: settledAt ?? this.settledAt,
      totalAmount: totalAmount ?? this.totalAmount,
      expenseIds: expenseIds ?? this.expenseIds,
      participants: participants ?? this.participants,
      isSettled: isSettled ?? this.isSettled,
    );
  }
}

/// Modelo para representar un participante en una división
class Participant {
  final int? id;
  final int divisionId; // ID de la división
  final String name; // Nombre del participante
  final double percentage; // Porcentaje (0-100)
  final double amountOwed; // Monto que le corresponde (calculado)

  Participant({
    this.id,
    required this.divisionId,
    required this.name,
    required this.percentage,
    required this.amountOwed,
  });

  /// Convierte a Map para guardar en base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'division_id': divisionId,
      'name': name,
      'percentage': percentage,
      'amount_owed': amountOwed,
    };
  }

  /// Crea desde Map de base de datos
  factory Participant.fromMap(Map<String, dynamic> map) {
    return Participant(
      id: map['id'] as int?,
      divisionId: map['division_id'] as int,
      name: map['name'] as String,
      percentage: (map['percentage'] as num).toDouble(),
      amountOwed: (map['amount_owed'] as num).toDouble(),
    );
  }

  /// Copia con cambios
  Participant copyWith({
    int? id,
    int? divisionId,
    String? name,
    double? percentage,
    double? amountOwed,
  }) {
    return Participant(
      id: id ?? this.id,
      divisionId: divisionId ?? this.divisionId,
      name: name ?? this.name,
      percentage: percentage ?? this.percentage,
      amountOwed: amountOwed ?? this.amountOwed,
    );
  }
}

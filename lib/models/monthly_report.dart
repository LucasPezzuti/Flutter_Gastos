/// Modelo de datos para el resumen mensual de gastos
/// 
/// Contiene estadísticas y comparativas de un mes específico
class MonthlyReport {
  final int year;
  final int month;
  final double total;
  final int expenseCount;
  final double averageExpense;
  final Map<int, double> categoryTotals; // categoryId -> total
  final DateTime firstExpenseDate;
  final DateTime lastExpenseDate;
  
  // Comparativas con el mes anterior
  final double? previousMonthTotal;
  final double? changePercentage;
  final int? expenseCountChange;
  
  // Top categoría del mes
  final int? topCategoryId;
  final double? topCategoryAmount;

  MonthlyReport({
    required this.year,
    required this.month,
    required this.total,
    required this.expenseCount,
    required this.averageExpense,
    required this.categoryTotals,
    required this.firstExpenseDate,
    required this.lastExpenseDate,
    this.previousMonthTotal,
    this.changePercentage,
    this.expenseCountChange,
    this.topCategoryId,
    this.topCategoryAmount,
  });

  /// Devuelve el nombre del mes en español
  String get monthName {
    const months = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return months[month];
  }

  /// Devuelve si hubo un incremento en los gastos
  bool get hasIncreased => changePercentage != null && changePercentage! > 0;

  /// Devuelve si hubo una disminución en los gastos
  bool get hasDecreased => changePercentage != null && changePercentage! < 0;

  /// Devuelve el texto del cambio porcentual
  String get changeText {
    if (changePercentage == null || changePercentage == 0) {
      return 'Sin cambios';
    }
    
    final absChange = changePercentage!.abs();
    final direction = hasIncreased ? 'más que' : 'menos que';
    return '${absChange.toStringAsFixed(1)}% $direction el mes anterior';
  }

  /// Devuelve el icono apropiado para el cambio
  String get changeIcon {
    if (changePercentage == null || changePercentage == 0) return '📊';
    return hasIncreased ? '📈' : '📉';
  }

  /// Devuelve true si es el mes actual
  bool get isCurrentMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  @override
  String toString() {
    return 'MonthlyReport{$monthName $year: \$${total.toStringAsFixed(2)}, $expenseCount gastos}';
  }
}
import '../models/expense_division.dart';
import '../models/expense.dart';

/// Servicio para manejar la lógica de cálculos de divisiones de gastos
class DivisionService {
  
  /// Calcula los montos que corresponden a cada participante
  static List<Participant> calculateParticipantAmounts({
    required double totalAmount,
    required List<Participant> participants,
  }) {
    // Validar que los porcentajes sumen 100%
    final totalPercentage = participants.fold<double>(0, (sum, p) => sum + p.percentage);
    
    if ((totalPercentage - 100).abs() > 0.01) {
      print('⚠️ Advertencia: Los porcentajes no suman 100% (suman ${totalPercentage}%)');
    }

    return participants.map((p) {
      final amountOwed = (totalAmount * p.percentage) / 100;
      return p.copyWith(amountOwed: double.parse(amountOwed.toStringAsFixed(2)));
    }).toList();
  }

  /// Calcula el total de gastos seleccionados
  static double calculateTotal(List<Expense> expenses) {
    return expenses.fold<double>(0, (sum, e) => sum + e.amount);
  }

  /// Valida que los porcentajes sean válidos
  static ({bool isValid, String? error}) validatePercentages(List<Participant> participants) {
    // Validar que no hay porcentajes negativos
    for (final p in participants) {
      if (p.percentage < 0) {
        return (isValid: false, error: '${p.name} tiene porcentaje negativo');
      }
    }

    // Validar que la suma sea 100%
    final total = participants.fold<double>(0, (sum, p) => sum + p.percentage);
    final difference = (total - 100).abs();
    
    if (difference > 0.01) {
      return (
        isValid: false,
        error: 'Los porcentajes deben sumar 100% (actualmente suman ${total.toStringAsFixed(2)}%)'
      );
    }

    return (isValid: true, error: null);
  }

  /// Genera un resumen en texto de la división
  static String generateSummary(ExpenseDivision division) {
    final buffer = StringBuffer();
    buffer.writeln('División: ${division.name}');
    buffer.writeln('Fecha: ${division.createdAt.toLocal().toString().split('.')[0]}');
    buffer.writeln('Total: \$${division.totalAmount.toStringAsFixed(2)}');
    buffer.writeln('\nParticipantes:');
    
    for (final p in division.participants) {
      buffer.writeln('  • ${p.name}: \$${p.amountOwed.toStringAsFixed(2)} (${p.percentage.toStringAsFixed(1)}%)');
    }

    return buffer.toString();
  }

  /// Calcula quién debe pagar a quién (simplificado)
  /// Retorna: [{'quien': 'nombre', 'a_quien': 'nombre', 'monto': 50.0}]
  static List<Map<String, dynamic>> calculateWhoOwesBillsAdvanced(
    ExpenseDivision division,
    Map<String, double> initialPayments,
  ) {
    // Este es un algoritmo simplificado
    // En la realidad, podrías usar un algoritmo más sofisticado para minimizar transacciones
    
    final debts = <Map<String, dynamic>>[];
    
    // Calcular saldos netos de cada participante
    final balances = <String, double>{};
    
    for (final p in division.participants) {
      balances[p.name] = (initialPayments[p.name] ?? 0) - p.amountOwed;
    }

    // Buscar quién debe y a quién
    final debtors = balances.entries.where((e) => e.value < 0).toList();
    final creditorsMap = <String, double>{};
    for (final e in balances.entries.where((e) => e.value > 0)) {
      creditorsMap[e.key] = e.value;
    }

    for (final debtor in debtors) {
      var debtAmount = debtor.value.abs();
      
      for (final creditorName in creditorsMap.keys.toList()) {
        if (debtAmount <= 0.01) break;
        
        final creditAmount = creditorsMap[creditorName] ?? 0;
        if (creditAmount <= 0.01) continue;

        final amount = debtAmount > creditAmount ? creditAmount : debtAmount;
        
        debts.add({
          'quien': debtor.key,
          'a_quien': creditorName,
          'monto': double.parse(amount.toStringAsFixed(2)),
        });

        debtAmount -= amount;
        creditorsMap[creditorName] = creditAmount - amount;
      }
    }

    return debts;
  }

  /// Genera un porcentaje automático dividido en partes iguales
  static List<Participant> generateEqualPercentages({
    required List<String> participantNames,
    required int divisionId,
  }) {
    final percentage = 100.0 / participantNames.length;
    
    return participantNames.asMap().entries.map((entry) {
      return Participant(
        divisionId: divisionId,
        name: entry.value,
        percentage: double.parse(percentage.toStringAsFixed(2)),
        amountOwed: 0, // Se calcula después
      );
    }).toList();
  }

  /// Convierte porcentajes a fracciones simples para mostrar
  static String percentageToFraction(double percentage) {
    // Ejemplos: 50% -> "1/2", 33.33% -> "1/3", 25% -> "1/4"
    final fractions = {
      50.0: '1/2',
      33.33: '1/3',
      25.0: '1/4',
      20.0: '1/5',
      16.67: '1/6',
      14.29: '1/7',
      12.5: '1/8',
      11.11: '1/9',
      10.0: '1/10',
    };

    for (final entry in fractions.entries) {
      if ((entry.key - percentage).abs() < 0.5) {
        return entry.value;
      }
    }

    return '${percentage.toStringAsFixed(1)}%';
  }
}

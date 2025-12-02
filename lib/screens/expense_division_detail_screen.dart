import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense_division.dart';
import '../services/division_service.dart';
import '../database/database_helper.dart';

/// Pantalla de detalles de una división de gastos
class ExpenseDivisionDetailScreen extends StatefulWidget {
  final ExpenseDivision division;

  const ExpenseDivisionDetailScreen({
    super.key,
    required this.division,
  });

  @override
  State<ExpenseDivisionDetailScreen> createState() =>
      _ExpenseDivisionDetailScreenState();
}

class _ExpenseDivisionDetailScreenState
    extends State<ExpenseDivisionDetailScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late ExpenseDivision _division;
  bool _isSettling = false;

  @override
  void initState() {
    super.initState();
    _division = widget.division;
  }

  /// Marca la división como liquidada
  Future<void> _settleDivision() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liquidar División'),
        content: const Text(
          '¿Marcar esta división como liquidada? '
          'Los pagos ya fueron realizados entre todos los participantes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Liquidar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isSettling = true);

      try {
        await _databaseHelper.settleDivision(_division.id!);
        setState(() {
          _division = _division.copyWith(
            isSettled: true,
            settledAt: DateTime.now(),
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('División liquidada'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSettling = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles de División'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Encabezado
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _division.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(_division.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _division.isSettled
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                          border: Border.all(
                            color: _division.isSettled
                                ? Colors.green
                                : Colors.orange,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _division.isSettled ? 'Liquidada' : 'Pendiente',
                          style: TextStyle(
                            color: _division.isSettled
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '\$${_division.totalAmount.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Gastos Incluidos',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _division.expenseIds.length.toString(),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Participantes
          Text(
            'Participantes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ..._division.participants.asMap().entries.map((entry) {
            final index = entry.key;
            final participant = entry.value;
            final colors = [
              Colors.blue,
              Colors.green,
              Colors.orange,
              Colors.red,
              Colors.purple,
              Colors.teal,
            ];
            final color = colors[index % colors.length];

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color.withOpacity(0.2),
                                border: Border.all(color: color),
                              ),
                              child: Center(
                                child: Text(
                                  participant.name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  participant.name,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${participant.percentage.toStringAsFixed(1)}%',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${participant.amountOwed.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                            Text(
                              'A pagar',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: participant.percentage / 100,
                      color: color,
                      backgroundColor: color.withOpacity(0.1),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 24),

          // Botón de liquidar
          if (!_division.isSettled)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSettling ? null : _settleDivision,
                icon: const Icon(Icons.check_circle),
                label: const Text('Marcar como Liquidada'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

          // Información de liquidación
          if (_division.isSettled && _division.settledAt != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✅ División Liquidada'),
                  Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(_division.settledAt!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/expense_division.dart';
import '../services/storage_service.dart';
import 'expense_division_detail_screen.dart';
import 'create_division_screen.dart';

/// Pantalla principal del Divisor de Gastos
/// 
/// Muestra:
/// - Listado de divisiones guardadas
/// - Botón para crear nueva división
/// - Estadísticas generales
class ExpenseDividerScreen extends StatefulWidget {
  const ExpenseDividerScreen({super.key});

  @override
  State<ExpenseDividerScreen> createState() => _ExpenseDividerScreenState();
}

class _ExpenseDividerScreenState extends State<ExpenseDividerScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();
  
  List<ExpenseDivision> _divisions = [];
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadDivisions();
  }

  /// Carga las divisiones del usuario
  Future<void> _loadDivisions() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario no encontrado');
      }

      _userId = currentUser.id;

      try {
        final divisions = await _databaseHelper.getDivisions(userId: currentUser.id);
        setState(() {
          _divisions = divisions;
        });
      } catch (e) {
        // En web, esto lanzará una excepción. Es normal.
        print('ℹ️ Divisiones no disponibles en web: $e');
        setState(() {
          _divisions = [];
        });
      }
    } catch (e) {
      print('Error cargando divisiones: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Navega a la pantalla de crear nueva división
  Future<void> _navigateToCreate() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateDivisionScreen(),
      ),
    );

    // Si se creó una nueva división, recargar
    if (result == true && mounted) {
      _loadDivisions();
    }
  }

  /// Navega a los detalles de una división
  void _navigateToDetail(ExpenseDivision division) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExpenseDivisionDetailScreen(division: division),
      ),
    ).then((_) {
      _loadDivisions(); // Recargar al volver
    });
  }

  /// Calcula el total de todas las divisiones no liquidadas
  double _getTotalPending() {
    return _divisions
        .where((d) => !d.isSettled)
        .fold<double>(0, (sum, d) => sum + d.totalAmount);
  }

  /// Elimina una división
  Future<void> _deleteDivision(ExpenseDivision division) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar División'),
        content: Text('¿Eliminar "${division.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _databaseHelper.deleteDivision(division.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('División eliminada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDivisions();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Divisor de Gastos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _divisions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_balance,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay divisiones aún',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea una nueva división para comenzar',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _navigateToCreate,
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva División'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Tarjeta de resumen
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Resumen',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Divisiones Totales',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      _divisions.length.toString(),
                                      style: Theme.of(context).textTheme.headlineMedium,
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pendiente de Liquidar',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      '\$${_getTotalPending().toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Listado de divisiones
                    Text(
                      'Mis Divisiones',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._divisions.map((division) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _navigateToDetail(division),
                          leading: Icon(
                            division.isSettled ? Icons.check_circle : Icons.pending_actions,
                            color: division.isSettled ? Colors.green : Colors.orange,
                          ),
                          title: Text(division.name),
                          subtitle: Text(
                            'Total: \$${division.totalAmount.toStringAsFixed(2)} • '
                            '${division.participants.length} participantes',
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: const Text('Ver Detalles'),
                                onTap: () => _navigateToDetail(division),
                              ),
                              PopupMenuItem(
                                child: const Text('Eliminar'),
                                onTap: () => _deleteDivision(division),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreate,
        tooltip: 'Nueva División',
        child: const Icon(Icons.add),
      ),
    );
  }
}

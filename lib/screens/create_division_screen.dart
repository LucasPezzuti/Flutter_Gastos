import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/expense_division.dart';
import '../services/storage_service.dart';
import '../services/division_service.dart';

/// Pantalla para crear una nueva división de gastos
/// Implementa un wizard de 3 pasos
class CreateDivisionScreen extends StatefulWidget {
  const CreateDivisionScreen({super.key});

  @override
  State<CreateDivisionScreen> createState() => _CreateDivisionScreenState();
}

class _CreateDivisionScreenState extends State<CreateDivisionScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();

  // Pasos del wizard
  int _currentStep = 0; // 0: Seleccionar gastos, 1: Agregar participantes, 2: Confirmar

  // Paso 1: Seleccionar gastos
  List<Expense> _allExpenses = [];
  Set<int> _selectedExpenseIds = {};
  bool _isLoadingExpenses = true;

  // Paso 2: Agregar participantes
  List<Participant> _participants = [];
  final TextEditingController _participantNameController = TextEditingController();
  double _participantPercentage = 50.0;
  bool _autoDistribute = false;

  // Paso 3: Revisión
  final TextEditingController _divisionNameController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  @override
  void dispose() {
    _participantNameController.dispose();
    _divisionNameController.dispose();
    super.dispose();
  }

  /// Carga los gastos del usuario
  Future<void> _loadExpenses() async {
    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) return;

      try {
        final expenses = await _databaseHelper.getExpenses(userId: currentUser.id);
        setState(() {
          _allExpenses = expenses.where((e) => !e.isPaid).toList(); // Solo gastos pendientes
          _isLoadingExpenses = false;
        });
      } catch (e) {
        // En web, no hay gastos
        setState(() {
          _allExpenses = [];
          _isLoadingExpenses = false;
        });
      }
    } catch (e) {
      print('Error cargando gastos: $e');
      setState(() => _isLoadingExpenses = false);
    }
  }

  /// Cambia la selección de un gasto
  void _toggleExpense(int expenseId) {
    setState(() {
      if (_selectedExpenseIds.contains(expenseId)) {
        _selectedExpenseIds.remove(expenseId);
      } else {
        _selectedExpenseIds.add(expenseId);
      }
    });
  }

  /// Calcula el total de gastos seleccionados
  double _getSelectedTotal() {
    return _allExpenses
        .where((e) => _selectedExpenseIds.contains(e.id))
        .fold<double>(0, (sum, e) => sum + e.amount);
  }

  /// Agrega un participante
  void _addParticipant() {
    if (_participantNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre')),
      );
      return;
    }

    setState(() {
      _participants.add(
        Participant(
          divisionId: 0, // Se asigna después
          name: _participantNameController.text,
          percentage: _participantPercentage,
          amountOwed: 0,
        ),
      );
      _participantNameController.clear();
      _participantPercentage = 50.0;
    });

    // Actualizar porcentajes automáticos si está habilitado
    if (_autoDistribute) {
      _updateAutoDistribution();
    }
  }

  /// Elimina un participante
  void _removeParticipant(int index) {
    setState(() {
      _participants.removeAt(index);
    });

    if (_autoDistribute) {
      _updateAutoDistribution();
    }
  }

  /// Actualiza la distribución automática de porcentajes
  void _updateAutoDistribution() {
    if (_participants.isEmpty) return;

    final percentage = 100.0 / _participants.length;
    setState(() {
      _participants = _participants
          .map((p) => p.copyWith(percentage: double.parse(percentage.toStringAsFixed(2))))
          .toList();
    });
  }

  /// Actualiza el porcentaje de un participante
  void _updateParticipantPercentage(int index, double newPercentage) {
    setState(() {
      _participants[index] = _participants[index].copyWith(percentage: newPercentage);
    });
  }

  /// Valida antes de continuar al siguiente paso
  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_selectedExpenseIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona al menos un gasto')),
        );
        return false;
      }
    } else if (_currentStep == 1) {
      if (_participants.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agrega al menos 2 participantes')),
        );
        return false;
      }

      final validation = DivisionService.validatePercentages(_participants);
      if (!validation.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validation.error!)),
        );
        return false;
      }
    } else if (_currentStep == 2) {
      if (_divisionNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un nombre para la división')),
        );
        return false;
      }
    }

    return true;
  }

  /// Crea la división y la guarda
  Future<void> _createDivision() async {
    setState(() => _isCreating = true);

    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) throw Exception('Usuario no encontrado');

      final selectedExpenses = _allExpenses
          .where((e) => _selectedExpenseIds.contains(e.id))
          .toList();
      final totalAmount = DivisionService.calculateTotal(selectedExpenses);

      // Calcular montos adeudados
      final participantsWithAmounts =
          DivisionService.calculateParticipantAmounts(
        totalAmount: totalAmount,
        participants: _participants,
      );

      // Crear división
      final division = ExpenseDivision(
        userId: currentUser.id,
        name: _divisionNameController.text,
        createdAt: DateTime.now(),
        totalAmount: totalAmount,
        expenseIds: selectedExpenses.map((e) => e.id!).toList(),
        participants: participantsWithAmounts,
      );

      // Guardar en base de datos
      await _databaseHelper.insertDivision(division);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('División creada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true); // Retornar true para indicar que se creó
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
        setState(() => _isCreating = false);
      }
    }
  }

  /// Construye el contenido del paso actual
  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return _buildStep1SelectExpenses();
    } else if (_currentStep == 1) {
      return _buildStep2AddParticipants();
    } else {
      return _buildStep3Review();
    }
  }

  /// Paso 1: Seleccionar gastos
  Widget _buildStep1SelectExpenses() {
    if (_isLoadingExpenses) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No hay gastos disponibles',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega gastos primero para crear una división',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selecciona los gastos a dividir',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Total seleccionado: \$${_getSelectedTotal().toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: _allExpenses.length,
            itemBuilder: (context, index) {
              final expense = _allExpenses[index];
              final isSelected = _selectedExpenseIds.contains(expense.id);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleExpense(expense.id!),
                  ),
                  title: Text(expense.description),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy').format(expense.date),
                  ),
                  trailing: Text(
                    '\$${expense.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Paso 2: Agregar participantes
  Widget _buildStep2AddParticipants() {
    final selectedTotal = _getSelectedTotal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Agrega participantes y define porcentajes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: _autoDistribute,
                    onChanged: (value) {
                      setState(() => _autoDistribute = value ?? false);
                      if (_autoDistribute) {
                        _updateAutoDistribution();
                      }
                    },
                  ),
                  const Text('Distribuir automáticamente en partes iguales'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_participants.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _participants.length,
              itemBuilder: (context, index) {
                final p = _participants[index];
                final amount = (selectedTotal * p.percentage) / 100;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
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
                                  p.name,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '\$${amount.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeParticipant(index),
                            ),
                          ],
                        ),
                        Slider(
                          value: p.percentage,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: '${p.percentage.toStringAsFixed(1)}%',
                          onChanged: _autoDistribute
                              ? null
                              : (value) => _updateParticipantPercentage(index, value),
                        ),
                        if (!_autoDistribute)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${p.percentage.toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        else
          Expanded(
            child: Center(
              child: Text(
                'Agrega participantes para comenzar',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nuevo Participante',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _participantNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_autoDistribute)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Porcentaje: ${_participantPercentage.toStringAsFixed(1)}%'),
                        Slider(
                          value: _participantPercentage,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (value) {
                            setState(() => _participantPercentage = value);
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _addParticipant,
                      child: const Text('Agregar Participante'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Paso 3: Revisar y confirmar
  Widget _buildStep3Review() {
    final selectedTotal = _getSelectedTotal();
    final validation = DivisionService.validatePercentages(_participants);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nombre de la División',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _divisionNameController,
              decoration: InputDecoration(
                hintText: 'Ej: Febrero 2025',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Resumen
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
                        const Text('Total a dividir:'),
                        Text(
                          '\$${selectedTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Participantes:'),
                        Text(
                          _participants.length.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Porcentajes válidos:'),
                        Text(
                          validation.isValid ? '✓ Sí' : '✗ No',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: validation.isValid ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Detalle de participantes
            Text(
              'Desglose por Participante',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._participants.map((p) {
              final amount = (selectedTotal * p.percentage) / 100;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${p.percentage.toStringAsFixed(1)}%'),
                        ],
                      ),
                      Text(
                        '\$${amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva División'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Indicador de pasos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStepIndicator(0, 'Gastos'),
                _buildStepIndicator(1, 'Participantes'),
                _buildStepIndicator(2, 'Confirmar'),
              ],
            ),
          ),
          const Divider(),

          // Contenido del paso
          Expanded(
            child: _buildStepContent(),
          ),

          // Botones de navegación
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  ElevatedButton(
                    onPressed: () => setState(() => _currentStep--),
                    child: const Text('Atrás'),
                  )
                else
                  const SizedBox.shrink(),
                if (_currentStep < 2)
                  ElevatedButton(
                    onPressed: () {
                      if (_validateCurrentStep()) {
                        setState(() => _currentStep++);
                      }
                    },
                    child: const Text('Siguiente'),
                  )
                else
                  ElevatedButton(
                    onPressed: _isCreating ? null : _createDivision,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Crear División'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int stepNum, String label) {
    final isActive = _currentStep >= stepNum;
    final isCurrentStep = _currentStep == stepNum;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? (isCurrentStep ? Theme.of(context).primaryColor : Colors.green)
                : Colors.grey.shade300,
          ),
          child: Center(
            child: isActive
                ? Icon(isCurrentStep ? Icons.edit : Icons.check,
                    color: Colors.white)
                : Text(
                    (stepNum + 1).toString(),
                    style: const TextStyle(color: Colors.grey),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isCurrentStep ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.black : Colors.grey,
          ),
        ),
      ],
    );
  }
}

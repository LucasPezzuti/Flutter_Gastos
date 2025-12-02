import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/firebase_sync_service.dart';
import 'add_expense_screen.dart';

/// Pantalla que muestra la lista completa de gastos
/// 
/// Permite:
/// - Ver todos los gastos ordenados por fecha
/// - Buscar gastos por descripción
/// - Filtrar por categoría
/// - Editar o eliminar gastos
class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Expense> _allExpenses = [];
  List<Expense> _filteredExpenses = [];
  Map<int, Category> _categories = {};
  Category? _selectedCategoryFilter;
  bool _isLoading = true;

  // Subscription para escuchar actualizaciones del sync
  StreamSubscription<bool>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Escuchar actualizaciones de datos del sync
    _syncSubscription = FirebaseSyncService.dataUpdatedStream.listen((_) {
      print('🔄 ExpensesList: Datos actualizados desde sync, recargando...');
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _syncSubscription?.cancel();
    super.dispose();
  }

  /// Carga gastos y categorías desde la base de datos
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener usuario local del StorageService para obtener el userId correcto
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario local no encontrado');
      }

      // USAR EL MISMO userId QUE EN SYNC: currentUser.id (1, 2, 3)
      final userId = currentUser.id;
      
      print('🔍 DEBUG ExpensesList: Usuario local ID: ${currentUser.id}');
      print('🔍 DEBUG ExpensesList: UserId para consultas: $userId');

      // Cargar categorías
      final categories = await _databaseHelper.getCategories();
      _categories = {for (var category in categories) category.id!: category};

      // Cargar gastos del usuario actual usando Firebase UID
      _allExpenses = await _databaseHelper.getExpenses(userId: userId);
      _filteredExpenses = List.from(_allExpenses);
      
      print('🔍 DEBUG ExpensesList: Total gastos cargados: ${_allExpenses.length}');
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Filtra los gastos según el texto de búsqueda y categoría seleccionada
  void _filterExpenses() {
    final searchText = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredExpenses = _allExpenses.where((expense) {
        // Filtro por texto de búsqueda
        final matchesSearch = searchText.isEmpty ||
            expense.description.toLowerCase().contains(searchText) ||
            expense.displayDescription.toLowerCase().contains(searchText);

        // Filtro por categoría
        final matchesCategory = _selectedCategoryFilter == null ||
            expense.categoryId == _selectedCategoryFilter!.id;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  /// Elimina un gasto después de confirmar con el usuario
  Future<void> _deleteExpense(Expense expense) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Eliminar Gasto'),
          content: Text(
            '¿Estás seguro de que quieres eliminar el gasto "${expense.description}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.deleteExpense(expense.id!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gasto eliminado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Recargar la lista
      } catch (e) {
        print('Error deleting expense: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar el gasto'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Navega a la pantalla de agregar gasto y recarga datos al regresar
  Future<void> _navigateToAddExpense() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos los Gastos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildExpensesList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddExpense,
        tooltip: 'Agregar Gasto',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Construye la sección de búsqueda y filtros
  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Campo de búsqueda
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Buscar gastos...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _filterExpenses(),
          ),
          const SizedBox(height: 12),
          
          // Filtro por categoría
          Row(
            children: [
              const Text(
                'Categoría: ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              Expanded(
                child: DropdownButton<Category?>(
                  isExpanded: true,
                  value: _selectedCategoryFilter,
                  hint: const Text('Todas las categorías'),
                  items: [
                    const DropdownMenuItem<Category?>(
                      value: null,
                      child: Text('Todas las categorías'),
                    ),
                    ..._categories.values.map((Category category) {
                      return DropdownMenuItem<Category?>(
                        value: category,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: Color(
                                int.parse(category.color.replaceFirst('#', '0xFF'))
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      );
                    }),
                  ],
                  onChanged: (Category? value) {
                    setState(() {
                      _selectedCategoryFilter = value;
                    });
                    _filterExpenses();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Construye la lista de gastos
  Widget _buildExpensesList() {
    if (_filteredExpenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _allExpenses.isEmpty 
                  ? 'No hay gastos registrados'
                  : 'No se encontraron gastos con los filtros aplicados',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _filteredExpenses.length,
        itemBuilder: (context, index) {
          final expense = _filteredExpenses[index];
          return _buildExpenseItem(expense);
        },
      ),
    );
  }

  /// Construye un elemento individual de la lista de gastos
  Widget _buildExpenseItem(Expense expense) {
    final category = _categories[expense.categoryId];
    final formattedDate = DateFormat('dd/MM/yyyy').format(expense.date);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category != null 
              ? Color(int.parse(category.color.replaceFirst('#', '0xFF')))
              : Colors.grey,
          child: Icon(
            _getIconData(category?.icon ?? 'help'),
            color: Colors.white,
          ),
        ),
        title: Text(
          expense.displayDescription,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('$formattedDate • ${category?.name ?? 'Sin categoría'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteExpense(expense);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Eliminar'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Convierte el nombre del icono a IconData
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'restaurant':
        return Icons.restaurant;
      case 'directions_car':
        return Icons.directions_car;
      case 'movie':
        return Icons.movie;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'build':
        return Icons.build;
      default:
        return Icons.help;
    }
  }
}
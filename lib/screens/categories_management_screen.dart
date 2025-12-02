import 'dart:async';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/category.dart';
import '../services/firebase_sync_service.dart';
import 'add_category_screen.dart';

/// Pantalla de gestión de categorías personalizadas
/// 
/// Permite:
/// - Ver todas las categorías disponibles
/// - Crear nuevas categorías
/// - Editar categorías existentes
/// - Eliminar categorías (con validaciones)
class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends State<CategoriesManagementScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Category> _categories = [];
  bool _isLoading = true;
  
  // Subscription para escuchar actualizaciones del sync
  StreamSubscription<bool>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    
    // Forzar sincronización al abrir la pantalla
    _forceSyncAndLoadCategories();
    
    // Escuchar actualizaciones de datos del sync
    _syncSubscription = FirebaseSyncService.dataUpdatedStream.listen((_) {
      if (mounted) {
        _loadCategories();
      }
    });
  }

  /// Fuerza sincronización y luego carga las categorías
  Future<void> _forceSyncAndLoadCategories() async {
    try {
      print('🔄 Categorías: Forzando sincronización inicial...');
      await FirebaseSyncService.fullSync();
      print('✅ Categorías: Sincronización completada');
      
      if (mounted) {
        await _loadCategories();
      }
    } catch (e) {
      print('❌ Error en sincronización de categorías: $e');
      if (mounted) {
        await _loadCategories();
      }
    }
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  /// Carga todas las categorías disponibles
  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _databaseHelper.getCategories();
      setState(() {
        _categories = categories;
      });
      print('📂 Categorías cargadas: ${categories.length}');
    } catch (e) {
      print('Error loading categories: $e');
      _showErrorSnackBar('Error al cargar las categorías');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Navega a la pantalla de agregar categoría
  Future<void> _navigateToAddCategory() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddCategoryScreen(),
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  /// Navega a la pantalla de editar categoría
  Future<void> _navigateToEditCategory(Category category) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddCategoryScreen(categoryToEdit: category),
      ),
    );

    if (result == true) {
      _loadCategories();
    }
  }

  /// Elimina una categoría con confirmación
  Future<void> _deleteCategory(Category category) async {
    // Verificar si la categoría está siendo usada
    final expensesUsingCategory = await _databaseHelper.getExpensesByCategory(category.id!);
    
    if (expensesUsingCategory.isNotEmpty) {
      _showErrorDialog(
        'No se puede eliminar',
        'Esta categoría está siendo usada por ${expensesUsingCategory.length} gasto(s). '
        'Elimina o cambia la categoría de esos gastos primero.',
      );
      return;
    }

    // Mostrar confirmación
    final confirmed = await _showDeleteConfirmation(category);
    if (!confirmed) return;

    try {
      await _databaseHelper.deleteCategory(category.id!);
      _loadCategories();
      _showSuccessSnackBar('Categoría "${category.name}" eliminada');
    } catch (e) {
      print('Error deleting category: $e');
      _showErrorSnackBar('Error al eliminar la categoría');
    }
  }

  /// Muestra un diálogo de confirmación para eliminar
  Future<bool> _showDeleteConfirmation(Category category) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text('¿Estás seguro de que quieres eliminar la categoría "${category.name}"?'),
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
      ),
    ) ?? false;
  }

  /// Muestra un SnackBar de éxito
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Muestra un SnackBar de error
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Muestra un diálogo de error
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Categorías'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: _buildCategoriesList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCategory,
        tooltip: 'Agregar Categoría',
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Construye la lista de categorías
  Widget _buildCategoriesList() {
    if (_categories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No hay categorías disponibles',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Toca el botón + para agregar una nueva categoría',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _buildCategoryItem(category);
      },
    );
  }

  /// Construye un elemento individual de categoría
  Widget _buildCategoryItem(Category category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
          child: Icon(
            _getIconData(category.icon),
            color: Colors.white,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text('ID: ${category.id}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _navigateToEditCategory(category);
                break;
              case 'delete':
                _deleteCategory(category);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Editar'),
                ],
              ),
            ),
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
      case 'home':
        return Icons.home;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'movie':
        return Icons.movie;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'pets':
        return Icons.pets;
      case 'work':
        return Icons.work;
      case 'phone':
        return Icons.phone;
      case 'local_gas_station':
        return Icons.local_gas_station;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'attach_money':
        return Icons.attach_money;
      case 'travel_explore':
        return Icons.travel_explore;
      default:
        return Icons.help;
    }
  }
}
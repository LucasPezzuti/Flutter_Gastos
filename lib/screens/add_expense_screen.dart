import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/firebase_sync_service.dart';

/// Pantalla para agregar un nuevo gasto
/// 
/// Permite al usuario ingresar:
/// - Monto del gasto
/// - Descripción
/// - Categoría
/// - Fecha (por defecto la actual)
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _installmentsController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();
  
  List<Category> _categories = [];
  Category? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _isCreditCard = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  /// Carga las categorías disponibles desde la base de datos
  Future<void> _loadCategories() async {
    try {
      final categories = await _databaseHelper.getCategories();
      setState(() {
        _categories = categories;
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
      _showErrorSnackBar('Error al cargar las categorías');
    }
  }

  /// Guarda el nuevo gasto en la base de datos
  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      return;
    }

    // Validación específica para tarjeta de crédito
    if (_isCreditCard) {
      if (_installmentsController.text.isEmpty) {
        _showErrorSnackBar('Ingresa el número de cuotas');
        return;
      }
      final installments = int.tryParse(_installmentsController.text);
      if (installments == null || installments < 1 || installments > 60) {
        _showErrorSnackBar('Las cuotas deben ser entre 1 y 60');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener el usuario actual
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario no encontrado. Inicia sesión nuevamente.');
      }

      print('🔍 DEBUG: Usuario actual: ${currentUser.email}, ID: ${currentUser.id}');

      final amount = double.parse(_amountController.text);
      final description = _descriptionController.text.trim();

      if (_isCreditCard) {
        // Gasto con tarjeta de crédito - generar cuotas
        final installments = int.parse(_installmentsController.text);
        
        await _databaseHelper.insertCreditCardExpense(
          userId: currentUser.id,
          totalAmount: amount,
          description: description,
          startDate: _selectedDate,
          categoryId: _selectedCategory!.id!,
          installments: installments,
        );
        
        print('💳 Gasto con tarjeta creado: $installments cuotas de \$${(amount / installments).toStringAsFixed(2)}');
      } else {
        // Gasto normal
        final expense = Expense(
          amount: amount,
          description: description,
          date: _selectedDate,
          categoryId: _selectedCategory!.id!,
          userId: currentUser.id,
        );

        final success = await FirebaseSyncService.saveExpense(expense);
        
        if (success) {
          print('🔍 DEBUG: Gasto normal guardado exitosamente');
        } else {
          print('❌ ERROR: Fallo al guardar el gasto');
        }
      }
      
      if (mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isCreditCard ? 
              'Gastos con tarjeta creados exitosamente' : 
              'Gasto agregado exitosamente'
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Regresar a la pantalla anterior con resultado exitoso
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error saving expense: $e');
      _showErrorSnackBar('Error al guardar el gasto');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  /// Muestra el selector de fecha
  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Seleccionar fecha del gasto',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Gasto'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveExpense,
            child: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'GUARDAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              _buildDateSelector(),
              const SizedBox(height: 16),
              _buildCreditCardToggle(),
              if (_isCreditCard) ...[
                const SizedBox(height: 16),
                _buildInstallmentsField(),
              ],
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Campo para el monto del gasto
  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Monto *',
        prefixText: '\$ ',
        border: OutlineInputBorder(),
        helperText: 'Ingresa el monto del gasto',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa el monto';
        }
        
        final amount = double.tryParse(value);
        if (amount == null) {
          return 'Por favor ingresa un número válido';
        }
        
        if (amount <= 0) {
          return 'El monto debe ser mayor a cero';
        }
        
        return null;
      },
    );
  }

  /// Campo para la descripción del gasto
  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Descripción *',
        border: OutlineInputBorder(),
        helperText: 'Describe en qué gastaste (ej: Almuerzo, Gasolina)',
      ),
      maxLines: 2,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Por favor ingresa una descripción';
        }
        
        if (value.trim().length < 3) {
          return 'La descripción debe tener al menos 3 caracteres';
        }
        
        return null;
      },
    );
  }

  /// Dropdown para seleccionar la categoría
  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<Category>(
      value: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Categoría *',
        border: OutlineInputBorder(),
        helperText: 'Selecciona la categoría del gasto',
      ),
      items: _categories.map((Category category) {
        return DropdownMenuItem<Category>(
          value: category,
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Color(
                  int.parse(category.color.replaceFirst('#', '0xFF'))
                ),
                child: Icon(
                  _getIconData(category.icon),
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(category.name),
            ],
          ),
        );
      }).toList(),
      onChanged: (Category? value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Por favor selecciona una categoría';
        }
        return null;
      },
    );
  }

  /// Selector de fecha
  Widget _buildDateSelector() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fecha del gasto',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Botón para guardar el gasto
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _saveExpense,
        icon: _isLoading 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isLoading ? 'Guardando...' : 'Guardar Gasto'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  /// Toggle para seleccionar pago con tarjeta de crédito
  Widget _buildCreditCardToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pago con tarjeta de crédito',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _isCreditCard ? 'Pago en cuotas' : 'Pago contado',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isCreditCard,
            onChanged: (value) {
              setState(() {
                _isCreditCard = value;
                if (!value) {
                  _installmentsController.clear();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  /// Campo para número de cuotas
  Widget _buildInstallmentsField() {
    return TextFormField(
      controller: _installmentsController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Número de cuotas *',
        prefixIcon: Icon(Icons.payments),
        border: OutlineInputBorder(),
        helperText: 'Entre 2 y 60 cuotas',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Por favor ingresa el número de cuotas';
        }
        
        final installments = int.tryParse(value);
        if (installments == null) {
          return 'Por favor ingresa un número válido';
        }
        
        if (installments < 2 || installments > 60) {
          return 'Las cuotas deben ser entre 2 y 60';
        }
        
        return null;
      },
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
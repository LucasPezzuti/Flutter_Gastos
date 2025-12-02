import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/category.dart';

/// Pantalla para agregar o editar una categoría
/// 
/// Permite:
/// - Crear nuevas categorías personalizadas
/// - Editar categorías existentes
/// - Seleccionar icono y color
/// - Validar nombres únicos
class AddCategoryScreen extends StatefulWidget {
  final Category? categoryToEdit;
  
  const AddCategoryScreen({super.key, this.categoryToEdit});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  String _selectedIcon = 'help';
  String _selectedColor = '#2196F3';
  bool _isLoading = false;
  bool get _isEditing => widget.categoryToEdit != null;

  // Lista de iconos disponibles
  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'restaurant', 'icon': Icons.restaurant, 'label': 'Restaurante'},
    {'name': 'directions_car', 'icon': Icons.directions_car, 'label': 'Transporte'},
    {'name': 'home', 'icon': Icons.home, 'label': 'Hogar'},
    {'name': 'local_hospital', 'icon': Icons.local_hospital, 'label': 'Salud'},
    {'name': 'school', 'icon': Icons.school, 'label': 'Educación'},
    {'name': 'movie', 'icon': Icons.movie, 'label': 'Entretenimiento'},
    {'name': 'shopping_cart', 'icon': Icons.shopping_cart, 'label': 'Compras'},
    {'name': 'fitness_center', 'icon': Icons.fitness_center, 'label': 'Deporte'},
    {'name': 'pets', 'icon': Icons.pets, 'label': 'Mascotas'},
    {'name': 'work', 'icon': Icons.work, 'label': 'Trabajo'},
    {'name': 'phone', 'icon': Icons.phone, 'label': 'Teléfono'},
    {'name': 'local_gas_station', 'icon': Icons.local_gas_station, 'label': 'Combustible'},
    {'name': 'card_giftcard', 'icon': Icons.card_giftcard, 'label': 'Regalos'},
    {'name': 'attach_money', 'icon': Icons.attach_money, 'label': 'Dinero'},
    {'name': 'travel_explore', 'icon': Icons.travel_explore, 'label': 'Viajes'},
    {'name': 'coffee', 'icon': Icons.coffee, 'label': 'Café'},
    {'name': 'local_pharmacy', 'icon': Icons.local_pharmacy, 'label': 'Farmacia'},
    {'name': 'laptop', 'icon': Icons.laptop, 'label': 'Tecnología'},
    {'name': 'brush', 'icon': Icons.brush, 'label': 'Belleza'},
    {'name': 'library_books', 'icon': Icons.library_books, 'label': 'Libros'},
  ];

  // Lista de colores disponibles
  final List<Map<String, dynamic>> _availableColors = [
    {'name': 'Azul', 'value': '#2196F3'},
    {'name': 'Verde', 'value': '#4CAF50'},
    {'name': 'Rojo', 'value': '#F44336'},
    {'name': 'Naranja', 'value': '#FF9800'},
    {'name': 'Púrpura', 'value': '#9C27B0'},
    {'name': 'Índigo', 'value': '#3F51B5'},
    {'name': 'Teal', 'value': '#009688'},
    {'name': 'Rosa', 'value': '#E91E63'},
    {'name': 'Café', 'value': '#795548'},
    {'name': 'Gris', 'value': '#607D8B'},
    {'name': 'Amarillo', 'value': '#FFEB3B'},
    {'name': 'Lima', 'value': '#CDDC39'},
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadCategoryData();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Carga los datos de la categoría a editar
  void _loadCategoryData() {
    final category = widget.categoryToEdit!;
    _nameController.text = category.name;
    _selectedIcon = category.icon;
    _selectedColor = category.color;
  }

  /// Guarda la categoría (nueva o editada)
  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar que el nombre no esté en uso (excepto para la categoría actual)
      final existingCategories = await _databaseHelper.getCategories();
      final nameExists = existingCategories.any((cat) => 
        cat.name.toLowerCase() == _nameController.text.trim().toLowerCase() &&
        (_isEditing ? cat.id != widget.categoryToEdit!.id : true)
      );

      if (nameExists) {
        _showErrorSnackBar('Ya existe una categoría con ese nombre');
        return;
      }

      final category = Category(
        id: _isEditing ? widget.categoryToEdit!.id : null,
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        color: _selectedColor,
      );

      if (_isEditing) {
        await _databaseHelper.updateCategory(category);
        print('✏️ Categoría actualizada: ${category.name}');
      } else {
        await _databaseHelper.insertCategory(category);
        print('➕ Nueva categoría creada: ${category.name}');
      }

      // TODO: Agregar sync con Firebase cuando implementemos categorías en Firestore

      if (mounted) {
        _showSuccessSnackBar(_isEditing ? 'Categoría actualizada' : 'Categoría creada');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error saving category: $e');
      _showErrorSnackBar('Error al guardar la categoría');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Categoría' : 'Nueva Categoría'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveCategory,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreviewCard(),
              const SizedBox(height: 24),
              _buildNameField(),
              const SizedBox(height: 24),
              _buildIconSelection(),
              const SizedBox(height: 24),
              _buildColorSelection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye la tarjeta de preview de la categoría
  Widget _buildPreviewCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Color(int.parse(_selectedColor.replaceFirst('#', '0xFF'))),
              child: Icon(
                _getIconData(_selectedIcon),
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vista Previa',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nameController.text.isEmpty ? 'Nombre de la categoría' : _nameController.text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye el campo de nombre
  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nombre de la Categoría',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: 'Ej: Gastos médicos, Suscripciones, etc.',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.label),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre es obligatorio';
            }
            if (value.trim().length < 2) {
              return 'El nombre debe tener al menos 2 caracteres';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              // Trigger rebuild para actualizar preview
            });
          },
        ),
      ],
    );
  }

  /// Construye la selección de iconos
  Widget _buildIconSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona un Icono',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _availableIcons.length,
            itemBuilder: (context, index) {
              final iconData = _availableIcons[index];
              final isSelected = _selectedIcon == iconData['name'];
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIcon = iconData['name'];
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade100 : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    iconData['icon'],
                    color: isSelected ? Colors.blue : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Construye la selección de colores
  Widget _buildColorSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona un Color',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _availableColors.map((colorData) {
            final isSelected = _selectedColor == colorData['value'];
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = colorData['value'];
                });
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(int.parse(colorData['value'].replaceFirst('#', '0xFF'))),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? Colors.black : Colors.grey.shade300,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Convierte el nombre del icono a IconData
  IconData _getIconData(String iconName) {
    final iconData = _availableIcons.firstWhere(
      (icon) => icon['name'] == iconName,
      orElse: () => {'icon': Icons.help},
    );
    return iconData['icon'];
  }
}
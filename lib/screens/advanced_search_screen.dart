import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';

/// Pantalla de búsqueda avanzada con filtros
class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();
  final SpeechService _speechService = SpeechService();
  
  // Filtros
  DateTime? _startDate;
  DateTime? _endDate;
  double? _minAmount;
  double? _maxAmount;
  Set<int> _selectedCategories = {};
  bool _showCreditCardOnly = false;
  bool _showPaidOnly = false;
  
  // Datos
  List<Category> _allCategories = [];
  List<Expense> _filteredExpenses = [];
  bool _isLoading = false;
  String _voiceSearchText = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeSpeech();
    _applyFilters();
  }

  /// Inicializa el servicio de speech-to-text
  Future<void> _initializeSpeech() async {
    try {
      await _speechService.initialize();
    } catch (e) {
      print('Error initializing speech: $e');
    }
  }

  /// Carga todas las categorías
  Future<void> _loadCategories() async {
    try {
      final categories = await _databaseHelper.getCategories();
      setState(() {
        _allCategories = categories;
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  /// Aplica los filtros a los gastos
  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) return;

      final allExpenses = await _databaseHelper.getExpenses(userId: currentUser.id);
      
      var filtered = allExpenses.where((expense) {
        // Filtro por rango de fechas
        if (_startDate != null && expense.date.isBefore(_startDate!)) return false;
        if (_endDate != null) {
          final endOfDay = _endDate!.add(const Duration(days: 1));
          if (expense.date.isAfter(endOfDay)) return false;
        }
        
        // Filtro por rango de monto
        if (_minAmount != null && expense.amount < _minAmount!) return false;
        if (_maxAmount != null && expense.amount > _maxAmount!) return false;
        
        // Filtro por categorías
        if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(expense.categoryId)) {
          return false;
        }
        
        // Filtro por tarjeta de crédito
        if (_showCreditCardOnly && !expense.isCreditCard) return false;
        
        // Filtro por pagado (solo para tarjeta de crédito)
        if (_showPaidOnly && (!expense.isCreditCard || !expense.isPaid)) return false;
        
        return true;
      }).toList();

      // Ordenar por fecha descendente
      filtered.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _filteredExpenses = filtered;
        _isLoading = false;
      });
    } catch (e) {
      print('Error applying filters: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Resetea todos los filtros
  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _minAmount = null;
      _maxAmount = null;
      _selectedCategories.clear();
      _showCreditCardOnly = false;
      _showPaidOnly = false;
    });
    _applyFilters();
  }

  /// Selecciona rango de fechas
  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _applyFilters();
    }
  }

  /// Inicia búsqueda por voz
  Future<void> _startVoiceSearch() async {
    // Si ya está escuchando, detener en lugar de iniciar de nuevo
    if (_speechService.isListening) {
      await _stopVoiceSearch();
      return;
    }

    setState(() {
      _voiceSearchText = 'Escuchando...';
    });

    try {
      await _speechService.startListening(
        onResult: (result) {
          setState(() {
            _voiceSearchText = result;
          });
        },
        onDone: () {
          print('🎤 Búsqueda por voz finalizada');
          _processVoiceSearch();
        },
      );
    } catch (e) {
      print('Error starting voice search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al iniciar búsqueda por voz')),
      );
    }
  }

  /// Detiene la búsqueda por voz
  Future<void> _stopVoiceSearch() async {
    print('🛑 Usuario presionó detener búsqueda');
    await _speechService.stopListening();
    setState(() {
      // UI se actualiza automáticamente porque isListening cambió
    });
  }

  /// Procesa la búsqueda por voz
  void _processVoiceSearch() async {
    final text = _speechService.lastWords.toLowerCase().trim();
    print('🎤 Búsqueda por voz: $text');

    await _speechService.cancelListening();

    if (text.isEmpty) {
      setState(() => _voiceSearchText = '');
      return;
    }

    setState(() {
      _voiceSearchText = text;
    });

    // Buscar gastos que coincidan con el texto
    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) return;

      final allExpenses = await _databaseHelper.getExpenses(userId: currentUser.id);

      // Filtrar por descripción
      var filtered = allExpenses
          .where((e) => e.description.toLowerCase().contains(text) ||
              e.displayDescription.toLowerCase().contains(text))
          .toList();

      filtered.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _filteredExpenses = filtered;
      });

      // Mostrar resultado
      if (filtered.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Se encontraron ${filtered.length} gasto(s)'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se encontraron gastos que coincidan'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error processing voice search: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _filteredExpenses.fold<double>(0, (sum, e) => sum + e.amount);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Búsqueda Avanzada'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetFilters,
            tooltip: 'Resetear filtros',
          ),
        ],
      ),
      body: Column(
        children: [
          // Panel de búsqueda por voz
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blue.withOpacity(0.1),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: _voiceSearchText),
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar por voz...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _startVoiceSearch,
                  backgroundColor: _speechService.isListening ? Colors.red : Colors.blue,
                  child: Icon(
                    _speechService.isListening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Panel de filtros
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rango de fechas
                Text(
                  'Período',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _startDate != null && _endDate != null
                                ? '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                                : 'Seleccionar período',
                            style: TextStyle(
                              color: _startDate != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Rango de montos
                Text(
                  'Monto',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Mínimo',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _minAmount = double.tryParse(value);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Máximo',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _maxAmount = double.tryParse(value);
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Categorías
                Text(
                  'Categorías',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allCategories.map((category) {
                    final isSelected = _selectedCategories.contains(category.id);
                    return FilterChip(
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories.add(category.id!);
                          } else {
                            _selectedCategories.remove(category.id);
                          }
                        });
                        _applyFilters();
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Filtros especiales
                CheckboxListTile(
                  title: const Text('Solo tarjeta de crédito'),
                  value: _showCreditCardOnly,
                  onChanged: (value) {
                    setState(() => _showCreditCardOnly = value ?? false);
                    _applyFilters();
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (_showCreditCardOnly)
                  CheckboxListTile(
                    title: const Text('Solo cuotas pagadas'),
                    value: _showPaidOnly,
                    onChanged: (value) {
                      setState(() => _showPaidOnly = value ?? false);
                      _applyFilters();
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const Divider(),
          
          // Resumen
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredExpenses.length} resultado${_filteredExpenses.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Total: \$${NumberFormat('#,##0.00').format(totalAmount)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // Lista de resultados
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredExpenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay gastos que coincidan\ncon los filtros',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredExpenses.length,
                        itemBuilder: (context, index) {
                          final expense = _filteredExpenses[index];
                          final category = _allCategories.firstWhere(
                            (c) => c.id == expense.categoryId,
                            orElse: () => Category(
                              id: -1,
                              name: 'Sin categoría',
                              icon: 'help',
                              color: '#808080',
                            ),
                          );

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
                                expense.displayDescription,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                '${DateFormat('dd/MM/yyyy').format(expense.date)} • ${category.name}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                '\$${NumberFormat('#,##0.00').format(expense.amount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
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

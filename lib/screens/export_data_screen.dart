import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/export_service.dart';

/// Pantalla para exportar datos de gastos a CSV y PDF
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();
  
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  List<Category> _selectedCategories = [];
  List<Category> _allCategories = [];
  bool _includeRegularExpenses = true;
  bool _includeCreditCardExpenses = true;
  bool _onlyPaidInstallments = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
  }
  
  Future<void> _loadCategories() async {
    try {
      final categories = await _databaseHelper.getCategories();
      setState(() {
        _allCategories = categories;
        _selectedCategories = List.from(categories); // Seleccionar todas por defecto
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exportar Datos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 24),
            _buildDateRangeSection(),
            const SizedBox(height: 24),
            _buildCategoriesSection(),
            const SizedBox(height: 24),
            _buildOptionsSection(),
            const SizedBox(height: 32),
            _buildExportButtons(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeaderSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.file_download,
                  color: Colors.blue,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: const Text(
                    'Exportar Datos de Gastos',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Genera reportes de tus gastos en formato CSV para análisis en Excel o PDF para presentaciones.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateRangeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rango de Fechas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, isStartDate: true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fecha inicial',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_startDate),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, isStartDate: false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Fecha final',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_endDate),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _setThisMonth,
                    icon: const Icon(Icons.today),
                    label: const Text('Este mes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _setLastMonth,
                    icon: const Icon(Icons.last_page),
                    label: const Text('Mes anterior'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoriesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Categorías',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: _selectAllCategories,
                      child: const Text('Todas'),
                    ),
                    TextButton(
                      onPressed: _deselectAllCategories,
                      child: const Text('Ninguna'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_allCategories.isEmpty)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allCategories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  return FilterChip(
                    label: Text(category.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                    avatar: isSelected ? null : Icon(
                      _getIconData(category.icon),
                      size: 16,
                      color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Opciones de Exportación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Incluir gastos regulares'),
              subtitle: const Text('Gastos normales sin cuotas'),
              value: _includeRegularExpenses,
              onChanged: (value) {
                setState(() {
                  _includeRegularExpenses = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Incluir gastos con tarjeta de crédito'),
              subtitle: const Text('Cuotas de tarjeta de crédito'),
              value: _includeCreditCardExpenses,
              onChanged: (value) {
                setState(() {
                  _includeCreditCardExpenses = value;
                  if (!value) _onlyPaidInstallments = false;
                });
              },
            ),
            if (_includeCreditCardExpenses)
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: SwitchListTile(
                  title: const Text('Solo cuotas pagadas'),
                  subtitle: const Text('Excluir cuotas pendientes de pago'),
                  value: _onlyPaidInstallments,
                  onChanged: (value) {
                    setState(() {
                      _onlyPaidInstallments = value;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildExportButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _exportData('csv'),
            icon: _isLoading ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ) : const Icon(Icons.table_chart),
            label: const Text('Exportar a CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _exportData('pdf'),
            icon: _isLoading ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ) : const Icon(Icons.picture_as_pdf),
            label: const Text('Exportar a PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
              textStyle: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _selectDate(BuildContext context, {required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }
  
  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0);
    });
  }
  
  void _setLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    setState(() {
      _startDate = lastMonth;
      _endDate = DateTime(lastMonth.year, lastMonth.month + 1, 0);
    });
  }
  
  void _selectAllCategories() {
    setState(() {
      _selectedCategories = List.from(_allCategories);
    });
  }
  
  void _deselectAllCategories() {
    setState(() {
      _selectedCategories.clear();
    });
  }
  
  Future<void> _exportData(String format) async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona al menos una categoría'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Obtener usuario actual
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No hay usuario autenticado');
      }
      
      // Obtener gastos filtrados
      final expenses = await _databaseHelper.getExpensesByDateRange(
        _startDate,
        _endDate,
        userId: currentUser.id,
      );
      
      // Aplicar filtros
      final filteredExpenses = expenses.where((expense) {
        // Filtrar por categorías seleccionadas
        final categoryIds = _selectedCategories.map((c) => c.id).toSet();
        if (!categoryIds.contains(expense.categoryId)) return false;
        
        // Filtrar por tipo de gasto
        if (expense.isCreditCard) {
          if (!_includeCreditCardExpenses) return false;
          if (_onlyPaidInstallments && !expense.isPaid) return false;
        } else {
          if (!_includeRegularExpenses) return false;
        }
        
        return true;
      }).toList();
      
      if (filteredExpenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay gastos que coincidan con los filtros seleccionados'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Crear mapa de categorías
      final categoriesMap = <int, Category>{};
      for (final category in _allCategories) {
        categoriesMap[category.id!] = category;
      }
      
      // Generar archivo
      final dateRange = '${DateFormat('dd-MM-yyyy').format(_startDate)}_${DateFormat('dd-MM-yyyy').format(_endDate)}';
      final fileName = 'gastos_$dateRange.$format';
      
      bool success = false;
      
      if (format == 'csv') {
        final csvData = ExportService.exportToCSV(filteredExpenses, categoriesMap);
        final bytes = Uint8List.fromList(csvData.codeUnits);
        success = await ExportService.downloadFile(
          bytes: bytes,
          fileName: fileName,
          mimeType: 'text/csv',
        );
      } else if (format == 'pdf') {
        final pdfBytes = await ExportService.generatePDFReport(
          expenses: filteredExpenses,
          categories: categoriesMap,
          title: 'Reporte de Gastos',
          startDate: _startDate,
          endDate: _endDate,
        );
        success = await ExportService.downloadFile(
          bytes: pdfBytes,
          fileName: fileName,
          mimeType: 'application/pdf',
        );
      }
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo $fileName exportado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Error al exportar el archivo');
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
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
      case 'home':
        return Icons.home;
      case 'school':
        return Icons.school;
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
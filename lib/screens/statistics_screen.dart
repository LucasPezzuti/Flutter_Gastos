import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/storage_service.dart';

/// Pantalla de estadísticas con gráficos
/// 
/// Muestra:
/// - Gráfico de torta por categorías
/// - Total gastado este mes
/// - Comparativa mes anterior
/// - Top 5 categorías más costosas
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();

  List<Expense> _monthlyExpenses = [];
  Map<int, Category> _categories = {};
  Map<Category, double> _categoryTotals = {};
  double _currentMonthTotal = 0.0;
  double _previousMonthTotal = 0.0;
  bool _isLoading = true;
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  /// Carga todas las estadísticas
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Obtener usuario actual
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('Usuario no encontrado');
      }

      // Cargar categorías
      final categories = await _databaseHelper.getCategories();
      _categories = {for (var category in categories) category.id!: category};

      // Calcular fechas del mes actual y anterior
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
      final previousMonthStart = DateTime(now.year, now.month - 1, 1);
      final previousMonthEnd = DateTime(now.year, now.month, 0);

      // Obtener gastos del mes actual
      _monthlyExpenses = await _databaseHelper.getExpensesByDateRange(
        currentMonthStart,
        currentMonthEnd,
        userId: currentUser.id,
      );

      // Obtener gastos del mes anterior para comparación
      final previousMonthExpenses = await _databaseHelper.getExpensesByDateRange(
        previousMonthStart,
        previousMonthEnd,
        userId: currentUser.id,
      );

      // Calcular totales
      _currentMonthTotal = _monthlyExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
      _previousMonthTotal = previousMonthExpenses.fold(0.0, (sum, expense) => sum + expense.amount);

      // Calcular totales por categoría
      _calculateCategoryTotals();
    } catch (e) {
      print('Error loading statistics: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Calcula el total gastado por categoría
  void _calculateCategoryTotals() {
    _categoryTotals.clear();
    
    for (final expense in _monthlyExpenses) {
      final category = _categories[expense.categoryId];
      if (category != null) {
        _categoryTotals[category] = (_categoryTotals[category] ?? 0.0) + expense.amount;
      }
    }

    // Ordenar por total descendente
    final sortedEntries = _categoryTotals.entries.toList();
    sortedEntries.sort((a, b) => b.value.compareTo(a.value));
    _categoryTotals = Map.fromEntries(sortedEntries);
  }

  /// Genera colores para el gráfico de torta
  List<Color> get _pieColors => [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.cyan,
    Colors.pink,
    Colors.brown,
    Colors.indigo,
    Colors.lime,
  ];

  /// Genera las secciones para el gráfico de torta
  List<PieChartSectionData> _generatePieSections() {
    if (_categoryTotals.isEmpty) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: 'Sin datos',
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
      ];
    }

    final List<PieChartSectionData> sections = [];
    int index = 0;

    for (final entry in _categoryTotals.entries) {
      final percentage = (entry.value / _currentMonthTotal) * 100;
      final isTouched = index == _touchedIndex;
      
      sections.add(
        PieChartSectionData(
          color: _pieColors[index % _pieColors.length],
          value: entry.value,
          title: isTouched ? '${entry.key.name}\n\$${entry.value.toStringAsFixed(0)}' : '${percentage.toStringAsFixed(1)}%',
          radius: isTouched ? 90 : 80,
          titleStyle: TextStyle(
            fontSize: isTouched ? 12 : 11,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          badgeWidget: isTouched ? _buildCategoryIcon(entry.key) : null,
          badgePositionPercentageOffset: 1.2,
        ),
      );
      index++;
    }

    return sections;
  }

  /// Construye el icono de la categoría para el badge
  Widget _buildCategoryIcon(Category category) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(
        _getCategoryIcon(category.name),
        size: 16,
        color: Colors.grey.shade700,
      ),
    );
  }

  /// Obtiene el icono según el nombre de la categoría
  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'comida':
      case 'alimentación':
        return Icons.restaurant;
      case 'transporte':
        return Icons.directions_car;
      case 'entretenimiento':
        return Icons.movie;
      case 'salud':
        return Icons.medical_services;
      case 'educación':
        return Icons.school;
      case 'compras':
        return Icons.shopping_bag;
      case 'servicios':
        return Icons.build;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMonthlyComparisonCard(),
                    const SizedBox(height: 20),
                    _buildPieChartCard(),
                    const SizedBox(height: 20),
                    _buildTop5CategoriesCard(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Tarjeta de comparación mensual
  Widget _buildMonthlyComparisonCard() {
    final difference = _currentMonthTotal - _previousMonthTotal;
    final percentageChange = _previousMonthTotal > 0 
        ? (difference / _previousMonthTotal) * 100 
        : 0.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text(
                  'Resumen Mensual',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  'Este Mes',
                  '\$${_currentMonthTotal.toStringAsFixed(0)}',
                  Colors.blue,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _buildStatColumn(
                  'Mes Anterior',
                  '\$${_previousMonthTotal.toStringAsFixed(0)}',
                  Colors.grey.shade600,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                _buildStatColumn(
                  'Diferencia',
                  '${difference >= 0 ? '+' : ''}\$${difference.toStringAsFixed(0)}',
                  difference >= 0 ? Colors.red : Colors.green,
                ),
              ],
            ),
            
            if (percentageChange != 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: percentageChange >= 0 ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: percentageChange >= 0 ? Colors.red.shade200 : Colors.green.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      percentageChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: percentageChange >= 0 ? Colors.red.shade600 : Colors.green.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${percentageChange.abs().toStringAsFixed(1)}% vs mes anterior',
                      style: TextStyle(
                        color: percentageChange >= 0 ? Colors.red.shade600 : Colors.green.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Widget para columna de estadísticas
  Widget _buildStatColumn(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Tarjeta con gráfico de torta
  Widget _buildPieChartCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Gastos por Categoría',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 0,
                  sections: _generatePieSections(),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  /// Construye la leyenda del gráfico
  Widget _buildLegend() {
    if (_categoryTotals.isEmpty) {
      return const Text('No hay datos para mostrar');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categoryTotals.entries.map((entry) {
        final index = _categoryTotals.keys.toList().indexOf(entry.key);
        final color = _pieColors[index % _pieColors.length];
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              entry.key.name,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }

  /// Tarjeta de top 5 categorías
  Widget _buildTop5CategoriesCard() {
    final top5 = _categoryTotals.entries.take(5).toList();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.leaderboard, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Text(
                  'Top 5 Categorías',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (top5.isEmpty)
              const Text('No hay gastos registrados este mes')
            else
              ...top5.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final category = entry.value.key;
                final amount = entry.value.value;
                final percentage = (amount / _currentMonthTotal) * 100;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _pieColors[entry.key % _pieColors.length].withOpacity(0.1),
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            color: _pieColors[entry.key % _pieColors.length],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        _getCategoryIcon(category.name),
                        color: _pieColors[entry.key % _pieColors.length],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${percentage.toStringAsFixed(1)}% del total',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '\$${amount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _pieColors[entry.key % _pieColors.length],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}
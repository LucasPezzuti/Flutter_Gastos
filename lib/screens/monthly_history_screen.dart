import 'dart:async';
import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/monthly_report.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/firebase_sync_service.dart';

/// Pantalla de historial mensual con comparativas y analytics
/// 
/// Muestra:
/// - Lista de meses navegables
/// - Comparativas entre meses
/// - Estadísticas detalladas
/// - Tendencias y insights
class MonthlyHistoryScreen extends StatefulWidget {
  const MonthlyHistoryScreen({super.key});

  @override
  State<MonthlyHistoryScreen> createState() => _MonthlyHistoryScreenState();
}

class _MonthlyHistoryScreenState extends State<MonthlyHistoryScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();
  
  List<Map<String, int>> _monthsWithData = [];
  Map<String, dynamic> _generalStats = {};
  Map<int, Category> _categories = {};
  bool _isLoading = true;
  
  // Subscription para escuchar actualizaciones del sync
  StreamSubscription<bool>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
    
    // Escuchar actualizaciones de datos del sync
    _syncSubscription = FirebaseSyncService.dataUpdatedStream.listen((_) {
      if (mounted) {
        _loadHistoryData();
      }
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  /// Carga los datos del historial
  Future<void> _loadHistoryData() async {
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

      // Obtener meses con datos
      _monthsWithData = await _databaseHelper.getMonthsWithExpenses(userId: currentUser.id);
      
      // Obtener estadísticas generales
      _generalStats = await _databaseHelper.getGeneralStats(userId: currentUser.id);
      
      print('📊 Meses con datos: ${_monthsWithData.length}');
      print('📊 Stats generales: ${_generalStats.keys}');
      
    } catch (e) {
      print('Error loading history data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Navega al detalle de un mes específico
  Future<void> _navigateToMonthDetail(int year, int month) async {
    try {
      final currentUser = await _storageService.getCurrentUser();
      final report = await _databaseHelper.getMonthlyReport(year, month, userId: currentUser?.id);
      
      if (report != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MonthDetailScreen(
              report: report,
              categories: _categories,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to month detail: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Mensual'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistoryData,
              child: _buildHistoryContent(),
            ),
    );
  }

  /// Construye el contenido del historial
  Widget _buildHistoryContent() {
    if (_monthsWithData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No hay historial disponible',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Agrega algunos gastos para ver el historial mensual',
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGeneralStatsCard(),
          const SizedBox(height: 20),
          _buildMonthsTitle(),
          const SizedBox(height: 12),
          _buildMonthsList(),
        ],
      ),
    );
  }

  /// Construye la tarjeta de estadísticas generales
  Widget _buildGeneralStatsCard() {
    if (_generalStats.isEmpty) return const SizedBox.shrink();
    
    final totalMonths = _generalStats['totalMonths'] ?? 0;
    final totalSpent = _generalStats['totalSpent'] ?? 0.0;
    final averageMonthly = _generalStats['averageMonthly'] ?? 0.0;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Resumen General',
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
                _buildStatItem(
                  icon: Icons.calendar_month,
                  label: 'Meses\nActivos',
                  value: totalMonths.toString(),
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.attach_money,
                  label: 'Total\nGastado',
                  value: '\$${totalSpent.toStringAsFixed(0)}',
                  color: Colors.red,
                ),
                _buildStatItem(
                  icon: Icons.trending_up,
                  label: 'Promedio\nMensual',
                  value: '\$${averageMonthly.toStringAsFixed(0)}',
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construye un elemento de estadística
  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Construye el título de la sección de meses
  Widget _buildMonthsTitle() {
    return Row(
      children: [
        const Icon(Icons.history, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          'Historial por Meses',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '${_monthsWithData.length} meses',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Construye la lista de meses
  Widget _buildMonthsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _monthsWithData.length,
      itemBuilder: (context, index) {
        final monthData = _monthsWithData[index];
        return FutureBuilder<MonthlyReport?>(
          future: () async {
            final currentUser = await _storageService.getCurrentUser();
            return _databaseHelper.getMonthlyReport(
              monthData['year']!,
              monthData['month']!,
              userId: currentUser?.id,
            );
          }(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Card(
                child: ListTile(
                  leading: CircularProgressIndicator(),
                  title: Text('Cargando...'),
                ),
              );
            }

            final report = snapshot.data!;
            return _buildMonthItem(report);
          },
        );
      },
    );
  }

  /// Construye un elemento de mes
  Widget _buildMonthItem(MonthlyReport report) {
    final isCurrentMonth = report.isCurrentMonth;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentMonth ? 4 : 1,
      color: isCurrentMonth ? Colors.blue.shade50 : null,
      child: ListTile(
        onTap: () => _navigateToMonthDetail(report.year, report.month),
        leading: CircleAvatar(
          backgroundColor: isCurrentMonth ? Colors.blue : Colors.grey.shade600,
          child: Text(
            report.month.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              '${report.monthName} ${report.year}',
              style: TextStyle(
                fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (isCurrentMonth) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ACTUAL',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$${report.total.toStringAsFixed(2)} • ${report.expenseCount} gastos'),
            if (report.changePercentage != null)
              Text(
                '${report.changeIcon} ${report.changeText}',
                style: TextStyle(
                  color: report.hasIncreased ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Pantalla de detalle de un mes específico
class MonthDetailScreen extends StatefulWidget {
  final MonthlyReport report;
  final Map<int, Category> categories;

  const MonthDetailScreen({
    super.key,
    required this.report,
    required this.categories,
  });

  @override
  State<MonthDetailScreen> createState() => _MonthDetailScreenState();
}

class _MonthDetailScreenState extends State<MonthDetailScreen> {
  List<dynamic>? _monthExpenses;
  bool _isLoadingExpenses = false;

  @override
  void initState() {
    super.initState();
    _loadMonthExpenses();
  }

  /// Carga los gastos del mes
  Future<void> _loadMonthExpenses() async {
    setState(() => _isLoadingExpenses = true);
    
    try {
      final databaseHelper = DatabaseHelper();
      final storageService = StorageService();
      final currentUser = await storageService.getCurrentUser();
      final userId = currentUser?.id;
      
      final expenses = await databaseHelper.getExpensesByMonth(widget.report.year, widget.report.month, userId: userId);
      setState(() {
        _monthExpenses = expenses;
        _isLoadingExpenses = false;
      });
    } catch (e) {
      print('Error loading month expenses: $e');
      setState(() {
        _monthExpenses = [];
        _isLoadingExpenses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.report.monthName} ${widget.report.year}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            _buildComparativeCard(),
            const SizedBox(height: 20),
            _buildCategoriesCard(),
            const SizedBox(height: 20),
            _buildExpensesListCard(),
          ],
        ),
      ),
    );
  }

  /// Construye la tarjeta de resumen
  Widget _buildSummaryCard() {
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
                  widget.report.isCurrentMonth ? Icons.today : Icons.calendar_month,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Resumen del Mes',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  icon: Icons.attach_money,
                  label: 'Total Gastado',
                  value: '\$${widget.report.total.toStringAsFixed(2)}',
                  color: Colors.red,
                ),
                _buildSummaryItem(
                  icon: Icons.receipt,
                  label: 'Gastos',
                  value: widget.report.expenseCount.toString(),
                  color: Colors.blue,
                ),
                _buildSummaryItem(
                  icon: Icons.timeline,
                  label: 'Promedio',
                  value: '\$${widget.report.averageExpense.toStringAsFixed(2)}',
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Construye un elemento de resumen
  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Construye la tarjeta comparativa
  Widget _buildComparativeCard() {
    if (widget.report.changePercentage == null) {
      return const SizedBox.shrink();
    }

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
                  widget.report.hasIncreased ? Icons.trending_up : Icons.trending_down,
                  color: widget.report.hasIncreased ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Comparativa',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (widget.report.hasIncreased ? Colors.red : Colors.green).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '${widget.report.changeIcon} ${widget.report.changeText}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.report.hasIncreased ? Colors.red : Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mes anterior: \$${widget.report.previousMonthTotal?.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
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

  /// Construye la tarjeta de categorías
  Widget _buildCategoriesCard() {
    if (widget.report.categoryTotals.isEmpty) {
      return const SizedBox.shrink();
    }

    // Ordenar categorías por gasto total
    final sortedCategories = widget.report.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.category, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Gastos por Categoría',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedCategories.take(5).map((entry) {
              final category = widget.categories[entry.key];
              final percentage = (entry.value / widget.report.total) * 100;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: category != null
                          ? Color(int.parse(category.color.replaceFirst('#', '0xFF')))
                          : Colors.grey,
                      child: Icon(
                        _getIconData(category?.icon ?? 'help'),
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category?.name ?? 'Sin categoría',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              category != null
                                  ? Color(int.parse(category.color.replaceFirst('#', '0xFF')))
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${entry.value.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
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

  /// Construye la tarjeta con la lista de gastos del mes
  Widget _buildExpensesListCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: Colors.purple,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Gastos del Mes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingExpenses)
              const Center(child: CircularProgressIndicator())
            else if (_monthExpenses == null || _monthExpenses!.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'No hay gastos en este mes',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _monthExpenses!.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final expense = _monthExpenses![index];
                  return _buildExpenseItem(expense);
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Construye un item de gasto
  Widget _buildExpenseItem(dynamic expense) {
    final category = widget.categories[expense.categoryId];
    final isCreditCard = expense.isCreditCard == true;
    final isPaid = expense.isPaid == true;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: category != null 
            ? Color(int.parse(category.color.replaceFirst('#', '0xFF')))
            : Colors.grey,
        child: Icon(
          _getIconData(category?.icon ?? 'help'),
          color: Colors.white,
          size: 18,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              expense.displayDescription,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: isCreditCard && isPaid ? Colors.green.shade700 : Colors.black87,
              ),
            ),
          ),
          if (isCreditCard) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isPaid ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isPaid ? 'PAGADA' : 'PENDIENTE',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${expense.date.day}/${expense.date.month} • ${category?.name ?? 'Sin categoría'}',
        style: TextStyle(
          fontSize: 12,
          color: isCreditCard && isPaid ? Colors.green.shade600 : Colors.grey.shade600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCreditCard && isPaid ? Colors.green.shade50 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isCreditCard && isPaid 
                ? Border.all(color: Colors.green.shade200, width: 1)
                : null,
            ),
            child: Text(
              '\$${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isCreditCard && isPaid ? Colors.green.shade700 : Colors.black87,
              ),
            ),
          ),
          if (isCreditCard) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _toggleInstallmentPayment(expense),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isPaid ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isPaid ? Colors.green : Colors.grey,
                  size: 24,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Cambia el estado de pago de una cuota de tarjeta de crédito
  Future<void> _toggleInstallmentPayment(dynamic expense) async {
    try {
      final databaseHelper = DatabaseHelper();
      final newPaidStatus = !(expense.isPaid == true);
      
      await databaseHelper.updateInstallmentPaymentStatus(
        expense.id!,
        newPaidStatus,
      );
      
      if (mounted) {
        // Mostrar snackbar con feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPaidStatus 
                ? 'Cuota marcada como pagada' 
                : 'Cuota marcada como pendiente',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        
        // Recargar los datos para mostrar el cambio
        await _loadMonthExpenses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
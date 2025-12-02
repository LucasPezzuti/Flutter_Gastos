import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/storage_service.dart';
import '../services/firebase_sync_service.dart';
import '../widgets/sync_progress_bar.dart';
import 'add_expense_screen.dart';
import 'expenses_list_screen.dart';
import 'login_screen.dart';
import 'statistics_screen.dart';
import 'categories_management_screen.dart';
import 'installments_payment_screen.dart';
import 'monthly_history_screen.dart';
import 'export_data_screen.dart';
import 'advanced_search_screen.dart';
import 'theme_settings_screen.dart';
import 'voice_expense_screen.dart';
import 'ai_analysis_screen.dart';
import 'expense_divider_screen.dart';

/// Pantalla principal de la aplicación - Dashboard
/// 
/// Muestra un resumen de los gastos del mes actual, incluyendo:
/// - Total gastado
/// - Gastos recientes
/// - Navegación a otras pantallas
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();
  double _monthlyTotal = 0.0;
  List<Expense> _recentExpenses = [];
  Map<int, Category> _categories = {};
  bool _isLoading = true;

  // Subscription para escuchar actualizaciones del sync
  StreamSubscription<bool>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    
    // Forzar sincronización al abrir el dashboard
    _forceSyncAndLoadData();
    
    // Escuchar actualizaciones de datos del sync
    _syncSubscription = FirebaseSyncService.dataUpdatedStream.listen((_) {
      print('🔄 Dashboard: Datos actualizados desde Firebase sync, recargando UI...');
      if (mounted) {
        _loadDashboardData();
      }
    });
  }

  /// Fuerza sincronización y luego carga datos
  Future<void> _forceSyncAndLoadData() async {
    try {
      print('🔄 Dashboard: Forzando sincronización inicial...');
      await FirebaseSyncService.fullSync();
      print('✅ Dashboard: Sincronización completada');
      
      if (mounted) {
        await _loadDashboardData();
      }
    } catch (e) {
      print('❌ Error en sincronización: $e');
      if (mounted) {
        await _loadDashboardData();
      }
    }
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  /// Carga los datos necesarios para el dashboard
  Future<void> _loadDashboardData() async {
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
      
      print('🔍 DEBUG Dashboard: Usuario local ID: ${currentUser.id}');
      print('🔍 DEBUG Dashboard: UserId para consultas: $userId');

      // Cargar categorías
      final categories = await _databaseHelper.getCategories();
      _categories = {for (var category in categories) category.id!: category};

      // Calcular el primer y último día del mes actual
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      // Obtener total del mes para el usuario actual (usando Firebase UID)
      final monthlyExpenses = await _databaseHelper.getExpensesByDateRange(
        firstDayOfMonth,
        lastDayOfMonth,
        userId: userId,
      );
      _monthlyTotal = monthlyExpenses.fold(0.0, (sum, expense) => sum + expense.amount);

      print('🔍 DEBUG Dashboard: Gastos del mes encontrados: ${monthlyExpenses.length}');
      for (var expense in monthlyExpenses) {
        print('  - ${expense.description}: \$${expense.amount} (userId: ${expense.userId})');
      }

      // Obtener gastos recientes del usuario (últimos gastos, agrupando cuotas)
      final allUserExpenses = await _databaseHelper.getExpenses(userId: userId);
      _recentExpenses = _getFilteredRecentExpenses(allUserExpenses, 5);

      print('🔍 DEBUG Dashboard: Total gastos del usuario: ${allUserExpenses.length}');
      print('🔍 DEBUG Dashboard: Gastos recientes: ${_recentExpenses.length}');
      
      // Log de los gastos recientes para debug
      for (var expense in _recentExpenses) {
        print('  📄 Reciente: ${expense.description} - \$${expense.amount}');
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Filtra gastos recientes agrupando cuotas de tarjeta de crédito
  List<Expense> _getFilteredRecentExpenses(List<Expense> allExpenses, int limit) {
    final Map<String, List<Expense>> creditCardGroups = {};
    final List<Expense> regularExpenses = [];
    final List<Expense> result = [];

    // Separar gastos normales de cuotas de tarjeta
    for (final expense in allExpenses) {
      if (expense.isCreditCard == true && expense.creditCardGroupId != null) {
        final groupId = expense.creditCardGroupId!;
        creditCardGroups[groupId] = (creditCardGroups[groupId] ?? [])..add(expense);
      } else {
        regularExpenses.add(expense);
      }
    }

    // Para cada grupo de cuotas, tomar solo la más reciente
    for (final group in creditCardGroups.values) {
      group.sort((a, b) => b.date.compareTo(a.date));
      result.add(group.first);
    }

    // Agregar gastos regulares
    result.addAll(regularExpenses);

    // Ordenar por fecha y tomar los más recientes
    result.sort((a, b) => b.date.compareTo(a.date));
    return result.take(limit).toList();
  }

  /// Navega a la pantalla de agregar gasto y recarga datos al regresar
  Future<void> _navigateToAddExpense() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddExpenseScreen(),
      ),
    );

    // Si se agregó un gasto, recargar los datos
    if (result == true) {
      _loadDashboardData();
    }
  }

  /// Navega a la pantalla de lista de gastos
  void _navigateToExpensesList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ExpensesListScreen(),
      ),
    );
  }

  /// Navega a la pantalla de estadísticas
  void _navigateToStatistics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StatisticsScreen(),
      ),
    );
  }

  /// Navega a la pantalla de historial mensual
  void _navigateToMonthlyHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MonthlyHistoryScreen(),
      ),
    );
  }

  /// Navega a la pantalla de exportar datos
  void _navigateToExportData() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ExportDataScreen(),
      ),
    );
  }

  /// Construye el drawer menu lateral
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.inversePrimary,
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.blue,
              ),
            ),
            accountName: const Text(
              'GastoTorta',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: FutureBuilder<String?>(
              future: _getUserEmail(),
              builder: (context, snapshot) {
                return Text(snapshot.data ?? 'Cargando...');
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: true,
            onTap: () {
              Navigator.pop(context); // Cerrar drawer
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_circle),
            title: const Text('Agregar Gasto'),
            onTap: () {
              Navigator.pop(context);
              _navigateToAddExpense();
            },
          ),
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Ver Todos los Gastos'),
            onTap: () {
              Navigator.pop(context);
              _navigateToExpensesList();
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Estadísticas'),
            onTap: () {
              Navigator.pop(context);
              _navigateToStatistics();
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Historial Mensual'),
            onTap: () {
              Navigator.pop(context);
              _navigateToMonthlyHistory();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Gestionar Categorías'),
            onTap: () {
              Navigator.pop(context);
              _navigateToCategoriesManagement();
            },
          ),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('Pagos de Cuotas'),
            onTap: () {
              Navigator.pop(context);
              _navigateToInstallmentsPayment();
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Exportar Datos'),
            onTap: () {
              Navigator.pop(context);
              _navigateToExportData();
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Búsqueda Avanzada'),
            onTap: () {
              Navigator.pop(context);
              _navigateToAdvancedSearch();
            },
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Gasto por Voz'),
            onTap: () {
              Navigator.pop(context);
              _navigateToVoiceExpense();
            },
          ),
          ListTile(
            leading: const Icon(Icons.smart_toy),
            title: const Text('Análisis con IA'),
            onTap: () {
              Navigator.pop(context);
              _navigateToAIAnalysis();
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Divisor de Gastos'),
            onTap: () {
              Navigator.pop(context);
              _navigateToDivider();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configuración'),
            onTap: () {
              Navigator.pop(context);
              _navigateToThemeSettings();
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Ayuda'),
            onTap: () {
              Navigator.pop(context);
              _showHelpDialog();
            },
          ),
        ],
      ),
    );
  }

  /// Navega a la pantalla de configuración de tema
  void _navigateToThemeSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ThemeSettingsScreen(),
      ),
    );
  }

  /// Obtiene el email del usuario actual
  Future<String?> _getUserEmail() async {
    try {
      final user = await _storageService.getCurrentUser();
      return user?.email;
    } catch (e) {
      return 'Usuario';
    }
  }

  /// Muestra el diálogo de ayuda
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayuda'),
        content: const Text(
          '📱 Esta es tu app de gestión de gastos.\n\n'
          '• Agrega gastos con categorías personalizadas\n'
          '• Ve estadísticas y tendencias\n'
          '• Gestiona tus categorías\n'
          '• Los datos se sincronizan automáticamente\n\n'
          '¿Necesitas más ayuda? Contacta al desarrollador.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Navega a la pantalla de gestión de categorías
  void _navigateToCategoriesManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CategoriesManagementScreen(),
      ),
    );
  }

  /// Navega a la pantalla de pagos de cuotas
  void _navigateToInstallmentsPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const InstallmentsPaymentScreen(),
      ),
    );
  }

  /// Navega a la pantalla de búsqueda avanzada
  void _navigateToAdvancedSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AdvancedSearchScreen(),
      ),
    );
  }

  /// Navega a la pantalla de capturar gasto por voz
  Future<void> _navigateToVoiceExpense() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const VoiceExpenseScreen(),
      ),
    );

    // Si se agregó un gasto, recargar los datos
    if (result == true) {
      _loadDashboardData();
    }
  }

  /// Navega a la pantalla de análisis con IA
  void _navigateToAIAnalysis() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AIAnalysisScreen(),
      ),
    );
  }

  /// Navega a la pantalla del Divisor de Gastos
  void _navigateToDivider() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ExpenseDividerScreen(),
      ),
    );
  }

  /// Navega a la pantalla de configuración de tema
  void _showUserMenu() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Opciones de Cuenta',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              FutureBuilder<String?>(
                future: _getUserEmail(),
                builder: (context, snapshot) {
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(snapshot.data ?? 'Cargando...'),
                    subtitle: const Text('Usuario actual'),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión'),
                onTap: _logout,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  /// Cierra la sesión del usuario
  Future<void> _logout() async {
    // Cerrar el bottom sheet
    Navigator.of(context).pop();

    // Mostrar diálogo de confirmación
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      try {
        // Limpiar sesión
        await _storageService.clearSession();

        if (mounted) {
          // Navegar al login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesión: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GastoTorta'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: _showUserMenu,
            tooltip: 'Opciones de usuario',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          // Barra de progreso de sincronización
          SyncProgressBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMonthlyTotalCard(),
                          const SizedBox(height: 20),
                          _buildQuickActionsRow(),
                          const SizedBox(height: 20),
                          _buildRecentExpensesSection(),
                        ],
                      ),
                    ),
                  ),
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

  /// Construye la tarjeta con el total del mes
  Widget _buildMonthlyTotalCard() {
    final currentMonth = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    final isEmptyMonth = _monthlyTotal == 0.0;
    
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
                  isEmptyMonth ? Icons.calendar_month : Icons.monetization_on,
                  color: isEmptyMonth ? Colors.grey[600] : Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total de $currentMonth',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '\$${_monthlyTotal.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _monthlyTotal > 0 ? Colors.red[700] : Colors.green[700],
              ),
            ),
            if (isEmptyMonth) ...[
              const SizedBox(height: 8),
              Text(
                '¡Perfecto! Aún no hay gastos este mes.',
                style: TextStyle(
                  color: Colors.green[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construye la fila de acciones rápidas
  Widget _buildQuickActionsRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToAddExpense,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Gasto'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _navigateToExpensesList,
                icon: const Icon(Icons.list),
                label: const Text('Ver Todos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _navigateToStatistics,
                icon: const Icon(Icons.analytics),
                label: const Text('Estadísticas'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(color: Colors.blue.shade300),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _navigateToExportData,
                icon: const Icon(Icons.file_download),
                label: const Text('Exportar'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  side: BorderSide(color: Colors.green.shade300),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Construye la sección de gastos recientes
  Widget _buildRecentExpensesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Actividad Reciente',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_recentExpenses.isNotEmpty)
              TextButton(
                onPressed: _navigateToExpensesList,
                child: const Text('Ver todos'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Últimos 5 gastos registrados',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        if (_recentExpenses.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay gastos registrados',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...(_recentExpenses.map((expense) => _buildExpenseItem(expense))),
      ],
    );
  }

  /// Construye un elemento individual de gasto
  Widget _buildExpenseItem(Expense expense) {
    final category = _categories[expense.categoryId];
    final formattedDate = DateFormat('dd/MM/yyyy').format(expense.date);
    final isThisMonth = expense.date.month == DateTime.now().month && 
                       expense.date.year == DateTime.now().year;

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
        subtitle: Row(
          children: [
            Text('$formattedDate • ${category?.name ?? 'Sin categoría'}'),
            if (!isThisMonth) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  DateFormat('MMM', 'es').format(expense.date),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Text(
          '\$${expense.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isThisMonth ? Colors.red[700] : Colors.grey[600],
          ),
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
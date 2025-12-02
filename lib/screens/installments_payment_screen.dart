import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../database/database_helper.dart';

/// Pantalla para gestionar los pagos de cuotas de tarjeta de crédito
class InstallmentsPaymentScreen extends StatefulWidget {
  const InstallmentsPaymentScreen({super.key});

  @override
  State<InstallmentsPaymentScreen> createState() => _InstallmentsPaymentScreenState();
}

class _InstallmentsPaymentScreenState extends State<InstallmentsPaymentScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Map<String, List<Expense>> _groupedInstallments = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstallmentExpenses();
  }

  /// Carga todas las cuotas de tarjeta de crédito
  Future<void> _loadInstallmentExpenses() async {
    setState(() => _isLoading = true);
    
    try {
      final expenses = await _databaseHelper.getExpenses();
      final installments = expenses.where((expense) => 
        expense.isCreditCard == true && expense.creditCardGroupId != null
      ).toList();

      // Agrupar por creditCardGroupId
      final grouped = <String, List<Expense>>{};
      for (final expense in installments) {
        final groupId = expense.creditCardGroupId!;
        grouped[groupId] = (grouped[groupId] ?? [])..add(expense);
      }

      // Ordenar cada grupo por cuota
      for (final group in grouped.values) {
        group.sort((a, b) => (a.currentInstallment ?? 0).compareTo(b.currentInstallment ?? 0));
      }

      setState(() {
        _groupedInstallments = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar las cuotas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Marca una cuota como pagada o no pagada
  Future<void> _togglePaymentStatus(Expense expense) async {
    try {
      await _databaseHelper.updateInstallmentPaymentStatus(
        expense.id!,
        !expense.isPaid,
      );
      
      // Recargar datos
      await _loadInstallmentExpenses();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              expense.isPaid 
                ? 'Cuota marcada como pendiente' 
                : 'Cuota marcada como pagada',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
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

  /// Calcula el total de cuotas pagadas y pendientes para un grupo
  Map<String, dynamic> _getGroupSummary(List<Expense> group) {
    final total = group.length;
    final paid = group.where((e) => e.isPaid == true).length;
    final pending = total - paid;
    final totalAmount = group.isNotEmpty ? group.first.amount * total : 0.0;
    final paidAmount = group.where((e) => e.isPaid == true).fold<double>(0, (sum, e) => sum + e.amount);
    
    return {
      'total': total,
      'paid': paid,
      'pending': pending,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': totalAmount - paidAmount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos de Cuotas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInstallmentExpenses,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_groupedInstallments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No tienes gastos en cuotas',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Los gastos con tarjeta de crédito aparecerán aquí',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groupedInstallments.length,
      itemBuilder: (context, index) {
        final groupId = _groupedInstallments.keys.elementAt(index);
        final group = _groupedInstallments[groupId]!;
        final summary = _getGroupSummary(group);
        
        return _buildInstallmentGroup(groupId, group, summary);
      },
    );
  }

  Widget _buildInstallmentGroup(String groupId, List<Expense> group, Map<String, dynamic> summary) {
    final firstExpense = group.first;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              firstExpense.description,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${summary['paid']}/${summary['total']} cuotas pagadas',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Total: \$${NumberFormat('#,##0').format(summary['totalAmount'])}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Row(
              children: [
                Text(
                  'Pagado: \$${NumberFormat('#,##0').format(summary['paidAmount'])}',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Text(
                  'Pendiente: \$${NumberFormat('#,##0').format(summary['pendingAmount'])}',
                  style: const TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        children: [
          const Divider(),
          ...group.map((expense) => _buildInstallmentItem(expense)),
        ],
      ),
    );
  }

  Widget _buildInstallmentItem(Expense expense) {
    final isPaid = expense.isPaid;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Checkbox(
        value: isPaid,
        onChanged: (_) => _togglePaymentStatus(expense),
        activeColor: Colors.green,
      ),
      title: Text(
        expense.displayDescription,
        style: TextStyle(
          color: isPaid ? Colors.green.shade700 : Colors.black87,
          fontWeight: isPaid ? FontWeight.w500 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        DateFormat('dd/MM/yyyy').format(expense.date),
        style: TextStyle(
          fontSize: 12,
          color: isPaid ? Colors.green.shade600 : Colors.grey.shade600,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPaid ? Colors.green.shade200 : Colors.orange.shade200,
            width: 1,
          ),
        ),
        child: Text(
          '\$${NumberFormat('#,##0').format(expense.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
          ),
        ),
      ),
      onTap: () => _togglePaymentStatus(expense),
    );
  }
}
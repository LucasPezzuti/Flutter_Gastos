import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';

/// Pantalla de análisis de gastos con IA
class AIAnalysisScreen extends StatefulWidget {
  const AIAnalysisScreen({super.key});

  @override
  State<AIAnalysisScreen> createState() => _AIAnalysisScreenState();
}

class _AIAnalysisScreenState extends State<AIAnalysisScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();

  final TextEditingController _questionController = TextEditingController();
  List<AIMessage> _messages = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialAnalysis();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  /// Carga el análisis inicial con recomendaciones
  Future<void> _loadInitialAnalysis() async {
    setState(() => _isLoading = true);

    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) return;

      // Obtener datos de los últimos 3 meses
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 2, now.day);

      final expenses = await _databaseHelper.getExpensesByDateRange(
        threeMonthsAgo,
        now,
        userId: currentUser.id,
      );

      if (expenses.isEmpty) {
        setState(() {
          _messages.add(
            AIMessage(
              text:
                  'No hay suficientes datos de gastos para analizar. Por favor, agrega algunos gastos primero.',
              isAI: true,
            ),
          );
          _isLoading = false;
        });
        return;
      }

      // Calcular datos por categoría
      final categories = await _databaseHelper.getCategories();
      final categoryMap = {for (var cat in categories) cat.id: cat.name};

      final byCategory = <String, double>{};
      for (final expense in expenses) {
        final catName = categoryMap[expense.categoryId] ?? 'Otro';
        byCategory[catName] = (byCategory[catName] ?? 0) + expense.amount;
      }

      // Calcular total y tendencias
      final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

      // Comparar con mes anterior
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0);
      final lastMonthExpenses =
          await _databaseHelper.getExpensesByDateRange(
        lastMonthStart,
        lastMonthEnd,
        userId: currentUser.id,
      );

      final trends = <String, String>{};
      for (final category in byCategory.keys) {
        final currentCatTotal = byCategory[category] ?? 0;

        // Calcular categoría del mes anterior
        final lastMonthCatExpenses = lastMonthExpenses
            .where((e) =>
                categoryMap[e.categoryId] == category)
            .toList();
        final lastMonthCatTotal =
            lastMonthCatExpenses.fold<double>(0, (sum, e) => sum + e.amount);

        if (lastMonthCatTotal > 0) {
          final percentChange =
              ((currentCatTotal - lastMonthCatTotal) / lastMonthCatTotal) * 100;
          trends[category] =
              '${percentChange > 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%';
        }
      }

      // Obtener deuda en tarjeta
      final creditCardExpenses =
          expenses.where((e) => e.isCreditCard && !e.isPaid).toList();
      final creditCardDebt = creditCardExpenses.fold<double>(
        0,
        (sum, e) => sum + e.amount,
      );

      // Llamar a IA para análisis
      print('📊 Iniciando análisis con IA...');
      print('Total: $total, Categorías: ${byCategory.length}, Deuda: $creditCardDebt');
      
      final analysis = await AIService.analyzeExpenses(
        totalSpent: total,
        byCategory: byCategory,
        trends: trends,
        creditCardDebt: creditCardDebt,
      );
      
      print('✅ Análisis completado: ${analysis.substring(0, 50)}...');

      setState(() {
        _messages.add(
          AIMessage(
            text: analysis,
            isAI: true,
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analysis: $e');
      setState(() {
        _errorMessage = 'Error al cargar el análisis: $e';
        _isLoading = false;
      });
    }
  }

  /// Envía una pregunta a la IA
  Future<void> _sendQuestion() async {
    if (_questionController.text.isEmpty) return;

    final question = _questionController.text;
    _questionController.clear();

    // Agregar mensaje del usuario
    setState(() {
      _messages.add(AIMessage(text: question, isAI: false));
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) return;

      // Obtener contexto de gastos
      final now = DateTime.now();
      final threeMonthsAgo = DateTime(now.year, now.month - 2, now.day);

      final expenses = await _databaseHelper.getExpensesByDateRange(
        threeMonthsAgo,
        now,
        userId: currentUser.id,
      );

      final categories = await _databaseHelper.getCategories();
      final categoryMap = {for (var cat in categories) cat.id: cat.name};

      final byCategory = <String, double>{};
      for (final expense in expenses) {
        final catName = categoryMap[expense.categoryId] ?? 'Otro';
        byCategory[catName] = (byCategory[catName] ?? 0) + expense.amount;
      }

      final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);

      final context = {
        'total_gastado': total,
        'por_categoria': byCategory,
        'gastos_recientes': expenses.take(5).map((e) {
          return {
            'descripcion': e.description,
            'monto': e.amount,
            'fecha': DateFormat('dd/MM/yyyy').format(e.date),
            'categoria': categoryMap[e.categoryId] ?? 'Otro',
          };
        }).toList(),
      };

      // Enviar pregunta a IA
      final response = await AIService.askAboutExpenses(
        question: question,
        context: context,
      );

      setState(() {
        _messages.add(AIMessage(text: response, isAI: true));
        _isLoading = false;
      });
    } catch (e) {
      print('Error sending question: $e');
      setState(() {
        _errorMessage = 'Error al procesar la pregunta: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis con IA'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Mensajes
          Expanded(
            child: _messages.isEmpty && _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Analizando tus gastos...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Sin mensajes',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Si es el último índice y está cargando, mostrar loader
                          if (index == _messages.length && _isLoading) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                border: Border.all(color: Colors.blue),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'La IA está escribiendo...',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final message = _messages[index];
                          return Align(
                            alignment: message.isAI
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.8,
                              ),
                              decoration: BoxDecoration(
                                color: message.isAI
                                    ? Colors.blue.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                border: Border.all(
                                  color: message.isAI ? Colors.blue : Colors.green,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (message.isAI)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.smart_toy,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'IA',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ],
                                    ),
                                  if (message.isAI) const SizedBox(height: 8),
                                  Text(
                                    message.text,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Error
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ),

          // Input de pregunta
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionController,
                    decoration: InputDecoration(
                      hintText: 'Hazle una pregunta a la IA...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    enabled: !_isLoading,
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _isLoading ? null : _sendQuestion,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modelo de mensaje
class AIMessage {
  final String text;
  final bool isAI;
  final DateTime timestamp;

  AIMessage({
    required this.text,
    required this.isAI,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

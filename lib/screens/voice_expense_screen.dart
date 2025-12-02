import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/speech_service.dart';
import '../services/storage_service.dart';

/// Pantalla para capturar gastos por voz
class VoiceExpenseScreen extends StatefulWidget {
  const VoiceExpenseScreen({super.key});

  @override
  State<VoiceExpenseScreen> createState() => _VoiceExpenseScreenState();
}

class _VoiceExpenseScreenState extends State<VoiceExpenseScreen> {
  final SpeechService _speechService = SpeechService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final StorageService _storageService = StorageService();

  List<Category> _categories = [];
  Category? _selectedCategory;
  String _recognizedText = '';
  double? _amount;
  String _description = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _initializeSpeech();
  }

  /// Carga las categorías disponibles
  Future<void> _loadCategories() async {
    try {
      final categories = await _databaseHelper.getCategories();
      setState(() {
        _categories = categories;
        if (categories.isNotEmpty) {
          _selectedCategory = categories.first;
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  /// Inicializa el servicio de speech-to-text
  Future<void> _initializeSpeech() async {
    try {
      final available = await _speechService.initialize();
      if (!available) {
        _showErrorDialog('Speech to text no disponible en tu dispositivo');
      }
    } catch (e) {
      print('Error initializing speech: $e');
    }
  }

  /// Inicia la captura de voz
  Future<void> _startListening() async {
    if (_speechService.isListening) return;

    setState(() {
      _recognizedText = 'Escuchando...';
      _isProcessing = true;
    });

    try {
      await _speechService.startListening(
        onResult: (result) {
          setState(() {
            _recognizedText = result;
          });
        },
        onDone: () {
          print('🎤 Grabación finalizada, procesando...');
          _processVoiceInput();
        },
      );
    } catch (e) {
      print('Error starting listening: $e');
      _showErrorDialog('Error al iniciar la captura de voz');
      setState(() => _isProcessing = false);
    }
  }

  /// Detiene la captura de voz
  Future<void> _stopListening() async {
    print('🛑 Usuario presionó detener');
    await _speechService.stopListening();
    setState(() {
      _isProcessing = false;
    });
  }

  /// Procesa el texto capturado por voz
  void _processVoiceInput() async {
    final text = _speechService.lastWords.toLowerCase().trim();
    print('🎤 Procesando: $text');

    // Reiniciar
    await _speechService.cancelListening();

    setState(() {
      _recognizedText = text;
    });

    // Intenta extraer: "monto nombre" o "nombre monto"
    // Ejemplo: "50 pesos comida" o "comida 50 pesos"
    final regex = RegExp(r'(\d+(?:\.\d{2})?)\s+(\D+)|(\D+)\s+(\d+(?:\.\d{2})?)');
    final match = regex.firstMatch(text);

    if (match != null) {
      // Extraer monto y descripción
      String? amount;
      String? desc;

      if (match.group(1) != null) {
        // Formato: "50 comida"
        amount = match.group(1);
        desc = match.group(2)?.trim();
      } else {
        // Formato: "comida 50"
        desc = match.group(3)?.trim();
        amount = match.group(4);
      }

      _amount = double.tryParse(amount ?? '0') ?? 0;
      _description = desc ?? '';

      // Intentar detectar categoría
      _detectCategory(_description);

      setState(() {
        _isProcessing = false;
      });

      // Mostrar preview del gasto capturado
      _showVoicePreview();
    } else {
      _showErrorDialog('No pude entender el monto. Por favor, intenta de nuevo.\n\nEjemplo: "50 pesos en comida"');
      setState(() => _isProcessing = false);
    }
  }

  /// Detecta la categoría basada en la descripción
  void _detectCategory(String description) {
    description = description.toLowerCase();

    final categoryKeywords = {
      'comida': ['comida', 'comer', 'almuerzo', 'desayuno', 'cena', 'restaurante', 'pizza', 'hamburgesa'],
      'transporte': ['uber', 'taxi', 'transporte', 'gasolina', 'auto', 'carro'],
      'compras': ['compra', 'tienda', 'shopping', 'supermercado', 'mercado'],
      'salud': ['farmacia', 'doctor', 'salud', 'medicina', 'hospital'],
      'entretenimiento': ['cine', 'película', 'música', 'juego', 'diversión', 'bar'],
    };

    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (description.contains(keyword)) {
          if (_categories.isNotEmpty) {
            _selectedCategory = _categories.firstWhere(
              (c) => c.name.toLowerCase() == entry.key,
              orElse: () => _categories.first,
            );
          }
          return;
        }
      }
    }
  }

  /// Muestra un preview del gasto capturado
  void _showVoicePreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gasto Capturado por Voz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Texto reconocido: "$_recognizedText"'),
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Monto: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: '\$${_amount?.toStringAsFixed(2) ?? '0.00'}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Descripción: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: _description),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Categoría: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: _selectedCategory?.name ?? 'Sin categoría'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '¿Deseas guardar este gasto?',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isProcessing = false);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _saveExpense();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Guarda el gasto capturado
  Future<void> _saveExpense() async {
    if (_amount == null || _amount! <= 0) {
      _showErrorDialog('El monto debe ser mayor a 0');
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) {
        _showErrorDialog('Usuario no encontrado');
        return;
      }

      final expense = Expense(
        description: _description,
        amount: _amount!,
        date: DateTime.now(),
        categoryId: _selectedCategory?.id != null 
          ? _selectedCategory!.id! 
          : (_categories.isNotEmpty ? _categories.first.id! : 1),
        userId: currentUser.id,
        isCreditCard: false,
        isPaid: true,
      );

      await _databaseHelper.insertExpense(expense);

      setState(() {
        _recognizedText = '';
        _amount = null;
        _description = '';
        _isProcessing = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Gasto guardado exitosamente'),
          duration: Duration(seconds: 2),
        ),
      );

      // Cerrar la pantalla después de guardar
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    } catch (e) {
      print('Error saving expense: $e');
      _showErrorDialog('Error al guardar el gasto');
      setState(() => _isProcessing = false);
    }
  }

  /// Muestra un diálogo de error
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
        title: const Text('Capturar Gasto por Voz'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono de micrófono animado
            AnimatedScale(
              scale: _speechService.isListening ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _speechService.isListening ? Colors.red : Colors.blue,
                  boxShadow: [
                    BoxShadow(
                      color: (_speechService.isListening ? Colors.red : Colors.blue)
                          .withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mic,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Texto reconocido
            if (_recognizedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      'Texto Reconocido:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Text(
                        _recognizedText,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

            // Información del gasto capturado
            if (_amount != null && _amount! > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detalles del Gasto:',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Monto:'),
                                Text(
                                  '\$${_amount?.toStringAsFixed(2) ?? '0.00'}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Descripción:'),
                                Text(_description),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Categoría:'),
                                Text(_selectedCategory?.name ?? 'Sin categoría'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),

            // Botones
            Column(
              children: [
                if (_speechService.isListening)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ElevatedButton.icon(
                      onPressed: _stopListening,
                      icon: const Icon(Icons.stop),
                      label: const Text('Detener Grabación'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _startListening,
                      icon: const Icon(Icons.mic),
                      label: const Text('Iniciar Grabación'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_amount != null && _amount! > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ElevatedButton.icon(
                      onPressed: _saveExpense,
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar Gasto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Información
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                color: Colors.blue.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 Ejemplos de entrada:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('• "50 pesos en comida"'),
                      const Text('• "100 para uber"'),
                      const Text('• "compras 250"'),
                      const Text('• "farmacia 30 pesos"'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

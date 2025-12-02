import 'package:http/http.dart' as http;
import 'dart:convert';

/// Servicio para interactuar con OpenRouter API
class AIService {
  static const String _apiKey = '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';
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  // Modelos en orden de preferencia (con fallback automático)
  static const List<String> _models = [
    'tngtech/deepseek-r1t-chimera:free',
    'mistralai/mistral-small-3.1-24b-instruct:free',
    'qwen/qwen3-4b:free',
  ];

  /// Envía una consulta a OpenRouter y obtiene una respuesta
  static Future<String> sendMessage({
    required String userMessage,
    required String systemPrompt,
    int modelIndex = 0,
  }) async {
    // Validar índice de modelo
    if (modelIndex >= _models.length) {
      return 'Error: No hay más modelos disponibles para intentar.';
    }

    final model = _models[modelIndex];
    print('🤖 Intentando con modelo: $model');

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'http://localhost:8080',
              'X-Title': 'Flutter App',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'system',
                  'content': systemPrompt,
                },
                {
                  'role': 'user',
                  'content': userMessage,
                },
              ],
            }),
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw TimeoutException(
              'Timeout al conectar con OpenRouter',
            ),
          );

      print('📡 Respuesta de OpenRouter: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final body = response.body.trim();
          if (body.isEmpty) {
            print('❌ Respuesta vacía de OpenRouter');
            if (modelIndex < _models.length - 1) {
              return await sendMessage(
                userMessage: userMessage,
                systemPrompt: systemPrompt,
                modelIndex: modelIndex + 1,
              );
            }
            return 'Error: Respuesta vacía del servidor';
          }

          // Parsing más robusto del JSON
          final jsonResponse = jsonDecode(body);
          print('📄 JSON Response recibido correctamente');
          
          // Verificar estructura de respuesta
          if (jsonResponse['choices'] == null || (jsonResponse['choices'] as List).isEmpty) {
            print('❌ Estructura de respuesta inválida: sin choices');
            if (modelIndex < _models.length - 1) {
              return await sendMessage(
                userMessage: userMessage,
                systemPrompt: systemPrompt,
                modelIndex: modelIndex + 1,
              );
            }
            return 'Error: Respuesta del servidor sin contenido válido';
          }
          
          final choice = (jsonResponse['choices'] as List)[0];
          final messageData = choice['message'];
          
          if (messageData == null || messageData['content'] == null) {
            print('❌ Mensaje sin contenido válido');
            if (modelIndex < _models.length - 1) {
              return await sendMessage(
                userMessage: userMessage,
                systemPrompt: systemPrompt,
                modelIndex: modelIndex + 1,
              );
            }
            return 'Error: Respuesta del servidor sin contenido';
          }
          
          final message = messageData['content'] as String;
          print('✅ Respuesta obtenida exitosamente');
          return message;
        } catch (parseError) {
          print('❌ Error parseando JSON: $parseError');
          print('📄 Body: ${response.body}');
          if (modelIndex < _models.length - 1) {
            return await sendMessage(
              userMessage: userMessage,
              systemPrompt: systemPrompt,
              modelIndex: modelIndex + 1,
            );
          }
          return 'Error al procesar la respuesta: $parseError';
        }
      } else if (response.statusCode == 429 || response.statusCode == 503) {
        // Modelo saturado o no disponible, intentar siguiente
        print('⚠️ Modelo $model no disponible, intentando siguiente...');
        return await sendMessage(
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          modelIndex: modelIndex + 1,
        );
      } else {
        final error = jsonDecode(response.body);
        final errorMsg = error['error']?['message'] ?? 'Error desconocido';
        print('❌ Error: $errorMsg');

        // Si falla por cualquier razón, intentar siguiente modelo
        if (modelIndex < _models.length - 1) {
          print('⚠️ Error con $model, intentando siguiente...');
          return await sendMessage(
            userMessage: userMessage,
            systemPrompt: systemPrompt,
            modelIndex: modelIndex + 1,
          );
        }
        return 'Error: $errorMsg';
      }
    } catch (e) {
      print('❌ Excepción: $e');
      print('❌ Stack trace: ${e is Error ? e.stackTrace : StackTrace.current}');

      // Si hay excepción, intentar siguiente modelo
      if (modelIndex < _models.length - 1) {
        print('⚠️ Excepción con $model, intentando siguiente...');
        return await sendMessage(
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          modelIndex: modelIndex + 1,
        );
      }
      return 'Error de conexión: $e';
    }
  }

  /// Analiza gastos y proporciona recomendaciones
  static Future<String> analyzeExpenses({
    required double totalSpent,
    required Map<String, double> byCategory,
    required Map<String, String> trends,
    required double creditCardDebt,
  }) async {
    final systemPrompt = '''Eres un experto en finanzas personales y análisis de gastos muy amigable y empático.
Tu tarea es analizar los gastos del usuario y proporcionar recomendaciones claras, concisas y amigables en español.

INSTRUCCIONES CRÍTICAS:
- Dirige al usuario directamente (tú/tu/tus, NO "el usuario" o "se encontró")
- Sé cálido y positivo, no crítico ni alarmista
- Entiende que estás hablando con una persona real, no con datos
- Sé conciso y directo
- Proporciona números específicos
- Sugiere acciones prácticas
- Usa un tono conversacional y amigable

EJEMPLO DE TONO CORRECTO:
❌ "Se detectó un incremento del 25% en gastos de categoría X"
✅ "Veo que tus gastos en X aumentaron un 25% este mes - ¿pasó algo especial?"

EJEMPLO DE TONO CORRECTO:
❌ "El usuario debería reducir sus compras"
✅ "Podrías ahorrar bastante si reduces tus gastos en X"''';

    final userMessage = '''Analiza mis gastos del último período y dame recomendaciones amigables:

Total que gasté: \$${totalSpent.toStringAsFixed(2)}
Mi deuda en tarjeta de crédito: \$${creditCardDebt.toStringAsFixed(2)}

Cómo gasté mi dinero:
${byCategory.entries.map((e) => '- ${e.key}: \$${e.value.toStringAsFixed(2)}').join('\n')}

Cómo cambió esto vs el mes anterior:
${trends.isEmpty ? '(Este es mi primer mes de datos)' : trends.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

Por favor:
1. Resumen amigable de mis gastos principales (qué es lo más importante)
2. Qué está bien en mis finanzas (sé positivo)
3. 1-2 cosas realistas en las que pueda mejorar
4. Si tengo deuda, un consejo práctico para pagarla
5. Una reflexión positiva sobre mis hábitos de gasto

Habla directamente conmigo (usar "tú/tu"). Sé amable y comprensivo, no crítico. ¡Hazlo conversacional!''';

    return await sendMessage(
      userMessage: userMessage,
      systemPrompt: systemPrompt,
    );
  }

  /// Responde preguntas generales sobre gastos
  static Future<String> askAboutExpenses({
    required String question,
    required Map<String, dynamic> context,
  }) async {
    final systemPrompt = '''Eres un asistente financiero personal amigable y empático.
Responde preguntas sobre gastos de forma clara, concisa y útil en español.
Basa tus respuestas en el contexto de datos proporcionado.
Usa números específicos cuando sea posible.

INSTRUCCIONES CRÍTICAS:
- Dirige al usuario directamente (tú/tu/tus, NO "el usuario")
- Sé cálido, positivo y comprensivo
- Tono conversacional, como hablando con un amigo
- Sé conciso
- Proporciona números específicos
- Sugiere acciones prácticas''';

    final contextStr = jsonEncode(context);
    final userMessage = '''Mi información de gastos:
$contextStr

Mi pregunta: $question

Por favor responde directamente a mí (usando "tú"), de forma amigable y útil. Sé conciso.''';

    return await sendMessage(
      userMessage: userMessage,
      systemPrompt: systemPrompt,
    );
  }

  /// Genera un pronóstico de gastos
  static Future<String> forecastExpenses({
    required List<double> last3MonthsTotal,
    required Map<String, List<double>> categoriesTrend,
  }) async {
    final systemPrompt = '''Eres un experto en análisis de datos y proyecciones financieras.
Tu tarea es analizar tendencias de gastos e identificar proyecciones realistas en español.
Sé específico con números y porcentajes.''';

    final avgTotal = last3MonthsTotal.isNotEmpty
        ? last3MonthsTotal.reduce((a, b) => a + b) / last3MonthsTotal.length
        : 0;

    final userMessage = '''Basándome en el siguiente histórico de gastos, proyecta mis gastos para el próximo mes:

Últimos 3 meses (totales): ${last3MonthsTotal.map((v) => '\$${v.toStringAsFixed(2)}').join(', ')}
Promedio: \$${avgTotal.toStringAsFixed(2)}

Tendencias por categoría:
${categoriesTrend.entries.map((e) => '- ${e.key}: ${e.value.map((v) => '\$${v.toStringAsFixed(2)}').join(', ')}').join('\n')}

Por favor:
1. Proyecta el gasto total del próximo mes
2. Proyecta gasto por categoría principal
3. Identifica categorías con mayor variabilidad
4. Sugiere un presupuesto realista''';

    return await sendMessage(
      userMessage: userMessage,
      systemPrompt: systemPrompt,
    );
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
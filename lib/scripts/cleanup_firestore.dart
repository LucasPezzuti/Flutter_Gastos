import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// Script para limpiar registros duplicados en Firestore
/// EJECUTAR SOLO EN DESARROLLO
Future<void> main() async {
  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  print('🧹 Iniciando limpieza de Firestore...');
  print('⚠️  ESTE SCRIPT ELIMINARÁ TODOS LOS GASTOS DUPLICADOS');
  print('¿Continuar? (y/N): ');
  
  final input = stdin.readLineSync();
  if (input?.toLowerCase() != 'y') {
    print('❌ Operación cancelada');
    return;
  }

  try {
    // Obtener todos los gastos
    final expensesSnapshot = await firestore.collection('expenses').get();
    print('📊 Total registros encontrados: ${expensesSnapshot.docs.length}');

    // Agrupar por descripción + monto + fecha para identificar duplicados
    final Map<String, List<DocumentSnapshot>> groups = {};
    
    for (final doc in expensesSnapshot.docs) {
      final data = doc.data();
      final key = '${data['description']}_${data['amount']}_${data['date']}';
      
      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(doc);
    }

    // Eliminar duplicados (mantener solo el primero de cada grupo)
    int deletedCount = 0;
    
    for (final entry in groups.entries) {
      final duplicates = entry.value;
      if (duplicates.length > 1) {
        print('🔍 Encontrados ${duplicates.length} duplicados para: ${entry.key}');
        
        // Mantener el primero, eliminar el resto
        for (int i = 1; i < duplicates.length; i++) {
          await duplicates[i].reference.delete();
          deletedCount++;
        }
      }
    }

    print('✅ Limpieza completada');
    print('🗑️  Registros eliminados: $deletedCount');
    print('📊 Registros restantes: ${expensesSnapshot.docs.length - deletedCount}');

  } catch (e) {
    print('❌ Error durante la limpieza: $e');
  }
}
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../database/database_helper.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';

/// Servicio de sincronización híbrida entre SQLite local y Firestore
/// 
/// Estrategia:
/// 1. Siempre guardar local primero (offline-first)
/// 2. Sync con Firebase cuando hay conexión
/// 3. Resolver conflictos por timestamp (más reciente gana)
class FirebaseSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final DatabaseHelper _localDb = DatabaseHelper();
  static final StorageService _storageService = StorageService();
  
  /// Obtiene el userId correcto del usuario actual
  /// Usa el ID del StorageService para mantener consistencia
  static Future<int?> _getCurrentUserId() async {
    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser != null) {
        print('🔍 DEBUG: Usando userId de StorageService: ${currentUser.id}');
        return currentUser.id;
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo userId: $e');
      return null;
    }
  }
  
  // Control de sincronización para evitar bucles
  static final Set<String> _syncingExpenses = <String>{};
  
  // Stream para notificar cuando hay nuevos datos sincronizados
  static final StreamController<bool> _dataUpdatedController = StreamController<bool>.broadcast();
  static Stream<bool> get dataUpdatedStream => _dataUpdatedController.stream;
  
  // Stream para reportar progreso de sincronización (0-100)
  static final StreamController<int> _syncProgressController = StreamController<int>.broadcast();
  static Stream<int> get syncProgressStream => _syncProgressController.stream;
  
  /// Setter para reportar progreso (0-100)
  static void _reportProgress(int progress) {
    print('📊 Progreso de sync: $progress%');
    if (!_syncProgressController.isClosed) {
      _syncProgressController.add(progress);
    }
  }
  
  static StreamSubscription<User?>? _authSubscription;
  static Timer? _syncTimer;

  /// Inicializa el servicio de sincronización
  static Future<void> initialize() async {
    print('🔄 FirebaseSync: Inicializando...');
    
    // Verificar que Firebase esté inicializado
    try {
      final app = Firebase.app();
      print('🔥 Firebase app inicializada: ${app.name}');
    } catch (e) {
      print('❌ Firebase no está inicializado: $e');
      // Intentar inicializar Firebase nuevamente
      try {
        print('🔄 Reintentando inicialización de Firebase...');
        await Firebase.initializeApp();
        print('✅ Firebase inicializado en segundo intento');
      } catch (e2) {
        print('❌ No se pudo inicializar Firebase: $e2');
        return;
      }
    }
    
    // Verificar conectividad antes de proceder
    bool hasUser = false;
    int attempts = 0;
    const maxAttempts = 5;
    
    // Esperar hasta que haya un usuario autenticado (máximo 10 segundos)
    while (!hasUser && attempts < maxAttempts) {
      final user = _auth.currentUser;
      if (user != null) {
        hasUser = true;
        print('👤 Usuario autenticado: ${user.email} (UID: ${user.uid})');
        
        // Agregar delay para permitir que la conexión se establezca
        await Future.delayed(const Duration(milliseconds: 1000));
        
        // 1. SINCRONIZACIÓN INICIAL COMPLETA desde Firestore
        await _performInitialSync();
        
        // 2. Configurar sync periódico (cada 2 minutos)
        _startPeriodicSync();
      } else {
        attempts++;
        print('❌ Intento $attempts/$maxAttempts: No hay usuario autenticado, esperando...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    
    if (!hasUser) {
      print('⚠️ No se encontró usuario autenticado después de $maxAttempts intentos');
    }
    
    // Escuchar cambios de autenticación
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        print('🔐 Usuario autenticado (listener): ${user.email}');
        // No hacer sync automático aquí - solo se hace en initialize()
      } else {
        print('🔓 Usuario desautenticado');
        _stopPeriodicSync();
      }
    });
    
    print('✅ FirebaseSync: Inicializado correctamente');
  }

  /// Realiza sincronización inicial completa desde Firestore
  static Future<void> _performInitialSync() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ No hay usuario para sincronizar');
      return;
    }
    
    // Obtener el userId correcto desde StorageService
    final userId = await _getCurrentUserId();
    if (userId == null) {
      print('❌ No se pudo obtener userId de StorageService');
      return;
    }
    
    try {
      print('🔄 Iniciando sincronización inicial desde Firestore...');
      print('🔍 Usando userId: $userId');
      _reportProgress(10);
      
      // Verificar conectividad con Firestore con timeout
      try {
        await _firestore
            .collection('expenses')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
        print('✅ Conectividad con Firestore confirmada');
      } catch (e) {
        print('❌ Sin conectividad con Firestore: $e');
        return;
      }
      
      _reportProgress(30);
      
      // 1. Obtener todos los gastos del usuario desde Firestore
      final firestoreExpenses = await _firestore
          .collection('expenses')
          .where('user_id', isEqualTo: user.uid)
          .get()
          .timeout(const Duration(seconds: 15));
      
      print('📊 Gastos en Firestore: ${firestoreExpenses.docs.length}');
      _reportProgress(50);
      
      // 2. Obtener gastos locales (usando el userId correcto)
      final localExpenses = await _localDb.getExpenses(userId: userId);
      print('📱 Gastos locales: ${localExpenses.length}');
      _reportProgress(60);
      
      // 3. Sincronizar desde Firestore (solo los que no existan localmente)
      int syncedCount = 0;
      final totalDocs = firestoreExpenses.docs.length;
      
      for (int i = 0; i < totalDocs; i++) {
        final doc = firestoreExpenses.docs[i];
        
        // Reportar progreso
        final progress = 60 + ((i / totalDocs) * 30).round();
        _reportProgress(progress);
        
        try {
          final data = doc.data();
          
          // Validar datos esenciales
          if (data['description'] == null || data['amount'] == null) {
            print('⚠️ Documento ${doc.id} con datos incompletos, saltando');
            continue;
          }
          
          // Convertir fecha de Firestore de forma segura
          DateTime firestoreDate;
          try {
            if (data['date'] is Timestamp) {
              firestoreDate = (data['date'] as Timestamp).toDate();
            } else if (data['date'] is String) {
              try {
                firestoreDate = DateTime.parse(data['date'] as String);
              } catch (e) {
                print('⚠️ Fecha en formato no estándar, usando timestamp actual');
                firestoreDate = DateTime.now();
              }
            } else {
              print('⚠️ Tipo de fecha desconocido: ${data['date'].runtimeType}');
              firestoreDate = DateTime.now();
            }
          } catch (e) {
            print('⚠️ Error procesando fecha, usando timestamp actual: $e');
            firestoreDate = DateTime.now();
          }
          
          // Verificar si ya existe localmente usando el ID coordinado primero
          final coordinatedId = int.tryParse(data['firebase_id']?.toString() ?? data['id']?.toString() ?? '0') ?? 0;
          final existsLocally = coordinatedId > 0 
            ? localExpenses.any((local) => local.id == coordinatedId)
            : localExpenses.any((local) =>
                local.description == data['description'] &&
                local.amount == (data['amount'] as num).toDouble() &&
                local.date.difference(firestoreDate).abs().inMinutes < 1 // Tolerancia de 1 minuto
              );
          
          if (!existsLocally) {
            try {
              // Preparar los datos para el constructor de Expense
              final expenseData = Map<String, dynamic>.from(data);
              // Usar el ID del documento Firestore como firebase_id si no existe
              expenseData['id'] = int.tryParse(data['firebase_id']?.toString() ?? data['id']?.toString() ?? '0') ?? 0;
              expenseData['user_id'] = userId; // ✅ USAR EL userId CORRECTO
              expenseData['date'] = firestoreDate.toIso8601String();
              
              final expense = Expense.fromFirestoreMap(expenseData);
              
              // Insertar con el ID existente sin pasar por getNextCoordinatedId()
              await _localDb.insertExpense(expense);
              syncedCount++;
              print('✅ Sincronizado: ${expense.description} - \$${expense.amount}');
            } catch (expenseError) {
              print('❌ Error creando expense de documento: $expenseError');
              print('📄 Datos problemáticos: ${doc.id} - ${data['description']}');
            }
          }
        } catch (docError) {
          print('❌ Error procesando documento ${doc.id}: $docError');
        }
      }
      
      _reportProgress(100);
      print('✅ Sincronización inicial completada: $syncedCount gastos sincronizados');
      
      // Si se sincronizó algo nuevo, notificar a la UI
      if (syncedCount > 0) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_dataUpdatedController.isClosed) {
            _dataUpdatedController.add(true);
          }
        });
      }
      
    } catch (e) {
      print('❌ Error en sincronización inicial: $e');
      print('🔍 Stack trace: ${StackTrace.current}');
      _reportProgress(0); // Reset progress on error
    }
  }
  
  /// Obtiene el próximo ID coordinado entre local y Firestore (método público)
  static Future<int> getNextCoordinatedId() async {
    return await _getNextCoordinatedId();
  }
  
  /// Obtiene el próximo ID disponible coordinado con Firestore (método privado)
  static Future<int> _getNextCoordinatedId() async {
    final user = _auth.currentUser;
    if (user == null) return 1;
    
    try {
      // Obtener el ID más alto de Firestore
      final firestoreQuery = await _firestore
          .collection('expenses')
          .where('user_id', isEqualTo: user.uid)
          .get();
      
      int maxFirestoreId = 0;
      for (final doc in firestoreQuery.docs) {
        final data = doc.data();
        final id = int.tryParse(data['firebase_id']?.toString() ?? '0') ?? 0;
        if (id > maxFirestoreId) maxFirestoreId = id;
      }
      
      // Obtener el ID más alto local usando userId correcto
      final userId = await _getCurrentUserId();
      if (userId == null) {
        print('❌ No se pudo obtener userId para _getNextCoordinatedId');
        return DateTime.now().millisecondsSinceEpoch;
      }
      
      final localExpenses = await _localDb.getExpenses(userId: userId); // ✅ USAR userId CORRECTO
      int maxLocalId = 0;
      for (final expense in localExpenses) {
        if (expense.id != null && expense.id! > maxLocalId) {
          maxLocalId = expense.id!;
        }
      }
      
      // Retornar el mayor + 1
      final nextId = (maxFirestoreId > maxLocalId ? maxFirestoreId : maxLocalId) + 1;
      print('🔢 Próximo ID coordinado: $nextId (Firestore: $maxFirestoreId, Local: $maxLocalId)');
      return nextId;
      
    } catch (e) {
      print('❌ Error obteniendo próximo ID: $e');
      return DateTime.now().millisecondsSinceEpoch; // Fallback
    }
  }

  /// Inicia sincronización periódica cada 2 minutos
  static void _startPeriodicSync() {
    _syncTimer?.cancel();
    print('⏰ Iniciando timer de sincronización periódica (cada 2 minutos)');
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      print('⏰ Ejecutando sincronización periódica (${DateTime.now()})');
      _performIncrementalSync();
    });
    print('✅ Sincronización periódica configurada');
  }

  /// Detiene la sincronización periódica
  static void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    print('❌ Sincronización periódica detenida');
  }

  /// Reinicia manualmente la sincronización periódica (usado después de login)
  static Future<void> restartPeriodicSync() async {
    print('🔄 Reiniciando sincronización periódica...');
    _stopPeriodicSync();
    
    // Hacer un sync inmediato
    await _performIncrementalSync();
    
    // Reiniciar el timer
    _startPeriodicSync();
  }

  /// Realiza sincronización incremental (solo cambios nuevos)
  static Future<void> _performIncrementalSync() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Obtener el userId correcto desde StorageService
    final userId = await _getCurrentUserId();
    if (userId == null) {
      print('❌ No se pudo obtener userId para sync incremental');
      return;
    }
    
    try {
      print('🔄 Verificando cambios en Firestore (sync periódico)...');
      
      QuerySnapshot<Map<String, dynamic>> recentChanges;
      
      try {
        // Intentar consulta optimizada con índice compuesto (últimos 5 minutos)
        final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
        
        recentChanges = await _firestore
            .collection('expenses')
            .where('user_id', isEqualTo: user.uid)
            .where('last_updated', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
            .get();
            
      } catch (indexError) {
        print('⚠️ Índice no disponible, saltando sync incremental...');
        // No hacer fallback a consulta completa aquí, solo en fullSync
        return;
      }
      
      if (recentChanges.docs.isEmpty) {
        print('✅ No hay cambios recientes en Firestore');
        return;
      }
      
      print('📥 ${recentChanges.docs.length} documentos modificados recientemente en Firestore');
      
      // OPTIMIZACIÓN: Cargar gastos locales UNA SOLA VEZ
      final localExpenses = await _localDb.getExpenses(userId: userId); // ✅ USAR userId CORRECTO
      print('📋 SQLite: ${localExpenses.length} expenses locales cargados para verificación');
      
      int syncedCount = 0;
      for (final doc in recentChanges.docs) {
        final data = doc.data();
        final syncKey = '${data['description']}_${data['amount']}_${data['date']}';
        
        // Verificar si ya existe localmente usando la lista cargada
        final exists = _checkExpenseExistsLocallyInMemory(data, localExpenses);
        
        if (!exists && !_syncingExpenses.contains(syncKey)) {
          await _syncExpenseFromFirestore(doc, userId); // ✅ PASAR userId
          syncedCount++;
        }
      }
      
      if (syncedCount > 0) {
        print('✅ Sincronización incremental: $syncedCount gastos sincronizados');
        // Notificar que hay nuevos datos solo si realmente sincronizamos algo
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!_dataUpdatedController.isClosed) {
            _dataUpdatedController.add(true);
          }
        });
      } else {
        print('✅ No hay gastos nuevos para sincronizar');
      }
      
    } catch (e) {
      print('❌ Error en sincronización incremental: $e');
    }
  }

  /// Verifica si un gasto de Firestore ya existe en una lista local (sin consulta SQLite adicional)
  static bool _checkExpenseExistsLocallyInMemory(Map<String, dynamic> firestoreData, List<Expense> localExpenses) {
    try {
      // Convertir fecha de Firestore - puede ser String o Timestamp
      DateTime firestoreDate;
      if (firestoreData['date'] is Timestamp) {
        firestoreDate = (firestoreData['date'] as Timestamp).toDate();
      } else {
        try {
          // Intentar formato ISO primero
          firestoreDate = DateTime.parse(firestoreData['date'] as String);
        } catch (e) {
          // Si falla, usar timestamp actual como fallback
          print('⚠️ Fecha en formato no estándar en verificación: ${firestoreData['date']}');
          firestoreDate = DateTime.now();
        }
      }
      
      // Buscar por descripción, monto y fecha
      final exists = localExpenses.any((expense) => 
        expense.description == firestoreData['description'] &&
        expense.amount == (firestoreData['amount'] as num).toDouble() &&
        expense.date.isAtSameMomentAs(firestoreDate)
      );
      
      return exists;
    } catch (e) {
      print('❌ Error verificando existencia en memoria: $e');
      return false;
    }
  }

  /// Obtiene el usuario actual
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Sincroniza gastos hacia Firestore
  static Future<bool> syncExpenseToFirestore(Expense expense) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final expenseData = expense.toFirestoreMap(); // ← Usando método específico para Firestore
      expenseData['user_id'] = user.uid;
      expenseData['firebase_id'] = expense.id?.toString();
      expenseData['last_updated'] = FieldValue.serverTimestamp(); // Timestamp real
      expenseData['date'] = expense.date.toIso8601String(); // Fecha como string ISO

      if (expense.id != null) {
        // Siempre usar ID determinístico para evitar duplicados
        await _firestore
            .collection('expenses')
            .doc('${user.uid}_${expense.id}')
            .set(expenseData, SetOptions(merge: true));
        print('✅ Gasto sincronizado a Firestore con ID: ${user.uid}_${expense.id}');
      } else {
        // Si no hay ID, generar uno usando timestamp
        final generatedId = DateTime.now().millisecondsSinceEpoch;
        expenseData['firebase_id'] = generatedId.toString();
        await _firestore
            .collection('expenses')
            .doc('${user.uid}_$generatedId')
            .set(expenseData);
        print('✅ Gasto creado en Firestore con ID generado: ${user.uid}_$generatedId');
      }

      print('✅ Expense synced to Firestore: ${expense.description}');
      return true;
    } catch (e) {
      print('❌ Error syncing expense to Firestore: $e');
      return false;
    }
  }

  /// Sincroniza todos los gastos locales hacia Firestore
  static Future<void> syncToFirestore() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Obtener el userId correcto desde StorageService
    final userId = await _getCurrentUserId();
    if (userId == null) {
      print('❌ No se pudo obtener userId para syncToFirestore');
      return;
    }

    try {
      print('🔄 Sincronizando datos locales hacia Firestore...');

      // Obtener gastos locales del usuario usando userId correcto
      final localExpenses = await _localDb.getExpenses(userId: userId); // ✅ USAR userId CORRECTO
      
      for (final expense in localExpenses) {
        await syncExpenseToFirestore(expense);
      }

      print('✅ Sync to Firestore completado');
    } catch (e) {
      print('❌ Error en sync to Firestore: $e');
    }
  }

  /// Sincroniza un gasto desde Firestore hacia local
  static Future<void> _syncExpenseFromFirestore(DocumentSnapshot doc, int userId) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // Crear clave única para control de duplicados
      final syncKey = '${data['description']}_${data['amount']}_${data['date']}';
      
      // Si ya está siendo sincronizado, evitar duplicación
      if (_syncingExpenses.contains(syncKey)) {
        print('⚠️ Sync ya en progreso para: ${data['description']}');
        return;
      }
      
      _syncingExpenses.add(syncKey);
      
      try {
        // Convertir fecha - puede ser String o Timestamp
        DateTime expenseDate;
        if (data['date'] is Timestamp) {
          expenseDate = (data['date'] as Timestamp).toDate();
        } else {
          try {
            // Intentar formato ISO primero
            expenseDate = DateTime.parse(data['date'] as String);
          } catch (e) {
            // Si falla, intentar convertir timestamp como fallback
            print('⚠️ Fecha en formato no estándar: ${data['date']}');
            // Para fechas manuales, usar timestamp actual como fallback
            expenseDate = DateTime.now();
          }
        }
        
        // Convertir datos de Firestore a Expense
        final expenseData = Map<String, dynamic>.from(data);
        expenseData['id'] = int.tryParse(data['firebase_id']?.toString() ?? '0') ?? 0;
        expenseData['user_id'] = userId; // ✅ USAR userId CORRECTO
        expenseData['date'] = expenseDate.toIso8601String();
        
        final expense = Expense.fromFirestoreMap(expenseData);

        // Verificar si existe localmente usando descripción, monto, fecha
        final existsLocally = await _checkExpenseExistsLocally(expense);
        
        if (!existsLocally) {
          // Insertar directamente sin activar sync de vuelta
          await _localDb.insertExpense(expense);
          print('📥 Expense synced from Firestore: ${expense.description}');
        } else if (expense.id != null && expense.id! > 0) {
          // Si ya existe pero tiene cambios (ej: isPaid), actualizar
          await _localDb.updateExpense(expense);
          print('🔄 Expense actualizado desde Firestore: ${expense.description}');
        } else {
          print('⚠️ Expense already exists locally, skipping: ${expense.description}');
        }
      } finally {
        // Remover de control después de un delay
        Future.delayed(const Duration(seconds: 2), () {
          _syncingExpenses.remove(syncKey);
        });
      }
    } catch (e) {
      print('❌ Error syncing expense from Firestore: $e');
    }
  }

  /// Verifica si un gasto existe localmente
  static Future<bool> _checkExpenseExistsLocally(Expense expense) async {
    try {
      // Obtener el userId correcto desde StorageService
      final userId = await _getCurrentUserId();
      if (userId == null) {
        print('❌ No se pudo obtener userId para verificación');
        return false;
      }
      
      final expenses = await _localDb.getExpenses(userId: userId); // ✅ USAR userId CORRECTO
      
      // Primero buscar por ID coordinado (es la forma más confiable)
      if (expense.id != null && expense.id! > 0) {
        final existsById = expenses.any((e) => e.id == expense.id);
        if (existsById) {
          print('✅ Gasto ya existe localmente por ID: ${expense.id}');
          return true;
        }
      }
      
      // Si no tiene ID o no lo encontró por ID, buscar por descripción, monto, fecha y usuario
      final exists = expenses.any((e) => 
        e.description == expense.description &&
        e.amount == expense.amount &&
        e.date.isAtSameMomentAs(expense.date) &&
        e.userId == expense.userId
      );
      
      if (exists) {
        print('✅ Gasto ya existe localmente por campos descriptivos');
      }
      
      return exists;
    } catch (e) {
      print('❌ Error checking expense existence: $e');
      return false;
    }
  }

  /// Sincroniza una categoría desde Firestore hacia local
  /// Guarda un gasto con sincronización automática
  static Future<bool> saveExpense(Expense expense, {bool fromFirestore = false}) async {
    try {
      Expense expenseToSave = expense;
      
      // Si no viene de Firestore, obtener ID coordinado
      if (!fromFirestore) {
        final coordinatedId = await _getNextCoordinatedId();
        expenseToSave = expense.copyWith(id: coordinatedId);
        print('🆔 Usando ID coordinado: $coordinatedId para gasto: ${expense.description}');
      }
      
      // 1. Guardar local primero (offline-first)
      await _localDb.insertExpense(expenseToSave);
      
      // 2. Solo sincronizar con Firestore si NO viene de Firestore (evitar bucle)
      if (!fromFirestore && _auth.currentUser != null) {
        await syncExpenseToFirestore(expenseToSave);
        print('🔄 Gasto enviado a Firestore con ID coordinado');
      }
      
      return true;
    } catch (e) {
      print('❌ Error saving expense: $e');
      return false;
    }
  }

  /// Elimina un gasto con sincronización
  static Future<bool> deleteExpense(int expenseId) async {
    try {
      // 1. Eliminar local
      await _localDb.deleteExpense(expenseId);
      
      // 2. Eliminar de Firestore
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('expenses')
            .doc('${user.uid}_$expenseId')
            .delete();
      }
      
      return true;
    } catch (e) {
      print('❌ Error deleting expense: $e');
      return false;
    }
  }

  /// Sincroniza datos desde Firestore hacia local (pull)
  static Future<void> syncFromFirestore() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ syncFromFirestore: No hay usuario autenticado');
      return;
    }

    // Obtener el userId correcto desde StorageService
    final userId = await _getCurrentUserId();
    if (userId == null) {
      print('❌ No se pudo obtener userId de StorageService');
      return;
    }

    try {
      print('🔄 Sincronizando desde Firestore hacia local para usuario: ${user.uid}');

      // Obtener gastos de Firestore
      print('📥 Consultando Firestore...');
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .where('user_id', isEqualTo: user.uid)
          .get();

      print('📊 Encontrados ${expensesSnapshot.docs.length} documentos en Firestore');

      for (final doc in expensesSnapshot.docs) {
        await _syncExpenseFromFirestore(doc, userId); // ✅ PASAR userId
      }

      print('✅ Sync from Firestore completado');
    } catch (e) {
      print('❌ Error en sync from Firestore: $e');
      rethrow; // Importante: reenviar la excepción
    }
  }

  /// Sincronización bidireccional completa
  static Future<void> fullSync() async {
    print('🔄 Iniciando sincronización bidireccional...');
    try {
      _reportProgress(0);
      
      print('📥 Iniciando sync FROM Firestore...');
      try {
        await syncFromFirestore().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            print('⚠️ Timeout en sync FROM Firestore');
          },
        );
      } catch (e) {
        print('⚠️ Error en sync FROM Firestore: $e');
      }
      _reportProgress(50);
      
      print('📤 Iniciando sync TO Firestore...');
      try {
        await syncToFirestore().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            print('⚠️ Timeout en sync TO Firestore');
          },
        );
      } catch (e) {
        print('⚠️ Error en sync TO Firestore: $e');
      }
      _reportProgress(100);
      
      print('✅ Sincronización bidireccional completada');
      
      // Limpiar progreso después de completar
      Future.delayed(Duration(seconds: 1), () {
        _reportProgress(0);
      });
    } catch (e) {
      print('❌ Error en fullSync: $e');
      _reportProgress(0);
    }
  }

  /// Limpia recursos al cerrar la app
  static void dispose() {
    _authSubscription?.cancel();
    _syncTimer?.cancel();
    _dataUpdatedController.close();
    _syncProgressController.close();
  }

  /// Verifica el estado de conectividad (simplificado)
  static bool get hasConnection {
    // En una implementación real, usarías connectivity_plus
    // Por ahora asumimos que hay conexión si hay usuario autenticado
    return _auth.currentUser != null;
  }

  /// Estadísticas de sincronización
  static Future<Map<String, dynamic>> getSyncStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'local_expenses': 0,
        'cloud_expenses': 0,
        'last_sync': null,
        'sync_status': 'Not authenticated',
      };
    }

    // Obtener el userId correcto desde StorageService
    final userId = await _getCurrentUserId();
    if (userId == null) {
      return {
        'local_expenses': 0,
        'cloud_expenses': 0,
        'last_sync': null,
        'sync_status': 'Error: No userId available',
      };
    }

    try {
      final localExpenses = await _localDb.getExpenses(userId: userId); // ✅ USAR userId CORRECTO
      final cloudSnapshot = await _firestore
          .collection('expenses')
          .where('user_id', isEqualTo: user.uid)
          .get();

      return {
        'local_expenses': localExpenses.length,
        'cloud_expenses': cloudSnapshot.docs.length,
        'last_sync': DateTime.now().toIso8601String(),
        'sync_status': hasConnection ? 'Connected' : 'Offline',
        'user_email': user.email,
      };
    } catch (e) {
      return {
        'local_expenses': 0,
        'cloud_expenses': 0,
        'last_sync': null,
        'sync_status': 'Error: $e',
      };
    }
  }
}
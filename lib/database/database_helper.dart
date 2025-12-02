import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/monthly_report.dart';
import '../models/expense_division.dart';
import '../services/storage_service.dart';
import '../services/firebase_sync_service.dart';

/// Helper para manejar la base de datos de la aplicación
/// 
/// IMPORTANTE: En web, usamos almacenamiento en memoria en lugar de SQLite
/// porque SQLite no está soportado nativamente en navegadores web.
/// Para apps móviles reales, esto funcionaría perfectamente.
/// 
/// Esta clase implementa el patrón Singleton para asegurar que solo
/// haya una instancia de la base de datos en toda la aplicación
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  
  // Para web: simulamos la base de datos en memoria
  static List<Category> _webCategories = [];
  static List<Expense> _webExpenses = [];
  static List<Budget> _webBudgets = [];
  static int _webCategoryIdCounter = 1;
  static int _webExpenseIdCounter = 1;
  static int _webBudgetIdCounter = 1;

  // Firestore y Storage Service
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  /// Constructor privado para el patrón Singleton
  DatabaseHelper._internal();

  /// Getter para obtener la única instancia de DatabaseHelper
  factory DatabaseHelper() => _instance;

  /// Getter para obtener la base de datos, creándola si es necesario
  Future<Database> get database async {
    if (kIsWeb) {
      // En web, inicializamos datos en memoria
      if (_webCategories.isEmpty) {
        await _initWebData();
      }
      // Retornamos null porque no usamos Database en web
      throw UnsupportedError('SQLite no soportado en web - usando almacenamiento en memoria');
    }
    
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Inicializa datos en memoria para web (ya que SQLite no funciona en web)
  Future<void> _initWebData() async {
    if (_webCategories.isNotEmpty) return; // Ya inicializado
    
    // Siempre inicializar con categorías por defecto
    _webCategories = [
      Category(id: _webCategoryIdCounter++, name: 'Comida', icon: 'restaurant', color: '#FF6B6B'),
      Category(id: _webCategoryIdCounter++, name: 'Transporte', icon: 'directions_car', color: '#4ECDC4'),
      Category(id: _webCategoryIdCounter++, name: 'Entretenimiento', icon: 'movie', color: '#45B7D1'),
      Category(id: _webCategoryIdCounter++, name: 'Salud', icon: 'local_hospital', color: '#96CEB4'),
      Category(id: _webCategoryIdCounter++, name: 'Compras', icon: 'shopping_bag', color: '#FCEA2B'),
      Category(id: _webCategoryIdCounter++, name: 'Servicios', icon: 'build', color: '#FF8C42'),
    ];
    
    final defaultCategoriesCount = _webCategories.length;
    
    // Luego cargar y agregar categorías personalizadas del usuario
    try {
      final currentUser = await _storageService.getCurrentUser();
      if (currentUser != null) {
        await _loadUserCategoriesFromFirestore(currentUser.id.toString());
      }
    } catch (e) {
      print('⚠️ Error cargando categorías personalizadas de Firestore: $e');
    }
    
    print('✅ Datos web inicializados con ${_webCategories.length} categorías ($defaultCategoriesCount por defecto + ${_webCategories.length - defaultCategoriesCount} personalizadas)');
  }

  /// Inicializa la base de datos creando las tablas necesarias (solo móvil)
  Future<Database> _initDatabase() async {
    // Obtiene la ruta donde se almacenará la base de datos
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'expense_tracker.db');

    // Abre/crea la base de datos
    return await openDatabase(
      path,
      version: 6, // ← VERSION 6: Agregar tablas para divisor de gastos
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // ← Agregar método de migración
    );
  }

  /// Crea las tablas cuando se inicializa la base de datos por primera vez
  Future<void> _onCreate(Database db, int version) async {
    // Tabla de usuarios (para almacenar info básica localmente)
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        name TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabla de categorías
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL
      )
    ''');

    // Tabla de gastos (AHORA CON user_id)
    await db.execute('''
      CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        date TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        is_credit_card INTEGER DEFAULT 0,
        total_installments INTEGER,
        current_installment INTEGER,
        credit_card_group_id TEXT,
        is_paid INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Tabla de presupuestos
    await db.execute('''
      CREATE TABLE budgets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        month INTEGER NOT NULL,
        year INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES categories(id),
        FOREIGN KEY(user_id) REFERENCES users(id),
        UNIQUE(category_id, user_id, month, year)
      )
    ''');

    // Tabla de divisiones de gastos
    await db.execute('''
      CREATE TABLE expense_divisions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        settled_at TEXT,
        total_amount REAL NOT NULL,
        expense_ids TEXT NOT NULL,
        is_settled INTEGER DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES users(id)
      )
    ''');

    // Tabla de participantes en divisiones
    await db.execute('''
      CREATE TABLE division_participants(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        division_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        percentage REAL NOT NULL,
        amount_owed REAL NOT NULL,
        FOREIGN KEY(division_id) REFERENCES expense_divisions(id)
      )
    ''');

    // Insertar categorías por defecto
    await _insertDefaultCategories(db);
    
    // Insertar usuarios hardcodeados
    await _insertDefaultUsers(db);
  }

  /// Migra la base de datos cuando se actualiza la versión
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migración de versión 1 a 2: agregar users y user_id
      
      // Crear tabla users
      await db.execute('''
        CREATE TABLE users(
          id INTEGER PRIMARY KEY,
          email TEXT UNIQUE NOT NULL,
          name TEXT,
          created_at TEXT NOT NULL
        )
      ''');

      // Agregar columna user_id a expenses existentes
      await db.execute('ALTER TABLE expenses ADD COLUMN user_id INTEGER DEFAULT 1');
      
      // Crear usuario por defecto para gastos existentes
      await db.execute('''
        INSERT INTO users (id, email, name, created_at) 
        VALUES (1, 'default@local.com', 'Usuario Local', '${DateTime.now().toIso8601String()}')
      ''');

      print('✅ Migración v1→v2 completada: Base de datos actualizada para multi-usuario');
    }

    if (oldVersion < 3) {
      // Migración de versión 2 a 3: insertar usuarios hardcodeados
      await _insertDefaultUsers(db);
      print('✅ Migración v2→v3 completada: Usuarios hardcodeados insertados');
    }

    if (oldVersion < 4) {
      // Migración de versión 3 a 4: agregar tabla de presupuestos
      await db.execute('''
        CREATE TABLE budgets(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          month INTEGER NOT NULL,
          year INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(category_id) REFERENCES categories(id),
          FOREIGN KEY(user_id) REFERENCES users(id),
          UNIQUE(category_id, user_id, month, year)
        )
      ''');
      print('✅ Migración v3→v4 completada: Tabla de presupuestos creada');
    }

    if (oldVersion < 5) {
      // Migración de versión 4 a 5: agregar campos para tarjeta de crédito
      await db.execute('ALTER TABLE expenses ADD COLUMN is_credit_card INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE expenses ADD COLUMN total_installments INTEGER');
      await db.execute('ALTER TABLE expenses ADD COLUMN current_installment INTEGER');
      await db.execute('ALTER TABLE expenses ADD COLUMN credit_card_group_id TEXT');
      await db.execute('ALTER TABLE expenses ADD COLUMN is_paid INTEGER DEFAULT 0');
      print('✅ Migración v4→v5 completada: Campos de tarjeta de crédito agregados');
    }

    if (oldVersion < 6) {
      // Migración de versión 5 a 6: agregar tablas para divisor de gastos
      await db.execute('''
        CREATE TABLE expense_divisions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          created_at TEXT NOT NULL,
          settled_at TEXT,
          total_amount REAL NOT NULL,
          expense_ids TEXT NOT NULL,
          is_settled INTEGER DEFAULT 0,
          FOREIGN KEY(user_id) REFERENCES users(id)
        )
      ''');

      await db.execute('''
        CREATE TABLE division_participants(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          division_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          percentage REAL NOT NULL,
          amount_owed REAL NOT NULL,
          FOREIGN KEY(division_id) REFERENCES expense_divisions(id)
        )
      ''');

      print('✅ Migración v5→v6 completada: Tablas de divisor de gastos creadas');
    }
  }

  /// Inserta categorías predeterminadas cuando se crea la base de datos
  Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = [
      {'name': 'Comida', 'icon': 'restaurant', 'color': '#FF6B6B'},
      {'name': 'Transporte', 'icon': 'directions_car', 'color': '#4ECDC4'},
      {'name': 'Entretenimiento', 'icon': 'movie', 'color': '#45B7D1'},
      {'name': 'Salud', 'icon': 'local_hospital', 'color': '#96CEB4'},
      {'name': 'Compras', 'icon': 'shopping_bag', 'color': '#FCEA2B'},
      {'name': 'Servicios', 'icon': 'build', 'color': '#FF8C42'},
    ];

    for (final category in defaultCategories) {
      await db.insert('categories', category);
    }

    print('📂 Categorías predeterminadas insertadas');
  }

  /// Inserta usuarios hardcodeados en SQLite (mismo que AuthService)
  Future<void> _insertDefaultUsers(Database db) async {
    final defaultUsers = [
      {
        'id': 1,
        'email': 'admin@test.com',
        'name': 'Administrador',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 2,
        'email': 'user@test.com',
        'name': 'Usuario Demo',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 3,
        'email': 'demo@test.com',
        'name': 'Usuario Prueba',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final user in defaultUsers) {
      try {
        await db.insert('users', user);
        print('👤 Usuario ${user['name']} (ID: ${user['id']}) insertado en SQLite');
      } catch (e) {
        print('⚠️ Error insertando usuario ${user['name']}: $e');
      }
    }
  }

  // OPERACIONES CRUD PARA CATEGORÍAS

  /// Inserta una nueva categoría
  Future<int> insertCategory(Category category) async {
    if (kIsWeb) {
      final newCategory = Category(
        id: _webCategoryIdCounter++,
        name: category.name,
        icon: category.icon,
        color: category.color,
      );
      _webCategories.add(newCategory);
      
      // Guardar también en Firestore (sin bloquear la operación local)
      _saveCategoryToFirestoreAsync(newCategory);
      
      return newCategory.id!;
    }
    
    final db = await database;
    return await db.insert('categories', category.toMap());
  }

  /// Obtiene todas las categorías
  Future<List<Category>> getCategories() async {
    if (kIsWeb) {
      await _initWebData(); // Asegurarse de que estén inicializadas
      print('📱 Web: Retornando ${_webCategories.length} categorías');
      return List.from(_webCategories); // Copia para evitar modificaciones accidentales
    }
    
    final db = await database;
    final maps = await db.query('categories', orderBy: 'name');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  /// Obtiene una categoría específica por su ID
  Future<Category?> getCategoryById(int id) async {
    if (kIsWeb) {
      await _initWebData();
      try {
        return _webCategories.firstWhere((cat) => cat.id == id);
      } catch (e) {
        return null;
      }
    }
    
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  /// Actualiza una categoría existente
  Future<int> updateCategory(Category category) async {
    if (kIsWeb) {
      final index = _webCategories.indexWhere((cat) => cat.id == category.id);
      if (index != -1) {
        _webCategories[index] = category;
        
        // Actualizar también en Firestore (sin bloquear)
        _updateCategoryInFirestoreAsync(category);
        
        return 1; // Éxito
      }
      return 0; // No encontrado
    }
    
    final db = await database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// Elimina una categoría (solo si no tiene gastos asociados)
  Future<int> deleteCategory(int id) async {
    // Verificar que no sea una categoría por defecto (IDs 1-6)
    if (id <= 6) {
      throw Exception('No se pueden eliminar las categorías por defecto');
    }
    
    if (kIsWeb) {
      // Verificar si hay gastos asociados a esta categoría
      final expensesUsingCategory = _webExpenses.where((expense) => expense.categoryId == id);
      
      if (expensesUsingCategory.isNotEmpty) {
        throw Exception('No se puede eliminar una categoría que tiene gastos asociados');
      }
      
      _webCategories.removeWhere((category) => category.id == id);
      
      // Eliminar también de Firestore (sin bloquear)
      _deleteCategoryFromFirestoreAsync(id);
      
      return 1; // Éxito
    }
    
    final db = await database;
    
    // Verificar si hay gastos asociados a esta categoría
    final expenseCount = await db.query(
      'expenses',
      where: 'category_id = ?',
      whereArgs: [id],
    );
    
    if (expenseCount.isNotEmpty) {
      throw Exception('No se puede eliminar una categoría que tiene gastos asociados');
    }
    
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // OPERACIONES CRUD PARA GASTOS

  /// Inserta un nuevo gasto
  Future<int> insertExpense(Expense expense) async {
    print('🔍 DEBUG insertExpense: Insertando gasto con userId: ${expense.userId}');
    print('🔍 DEBUG insertExpense: Descripción: ${expense.description}');
    print('🔍 DEBUG insertExpense: Monto: ${expense.amount}');
    
    if (kIsWeb) {
      // Si el expense ya tiene un ID válido (viene de Firestore), usarlo directamente
      // Si no, obtener uno nuevo coordinado con Firebase
      int finalId;
      if (expense.id != null && expense.id! > 0) {
        finalId = expense.id!;
      } else {
        finalId = await FirebaseSyncService.getNextCoordinatedId();
      }
      
      final newExpense = Expense(
        id: finalId,
        amount: expense.amount,
        description: expense.description,
        date: expense.date,
        categoryId: expense.categoryId,
        userId: expense.userId,
        isCreditCard: expense.isCreditCard,
        totalInstallments: expense.totalInstallments,
        currentInstallment: expense.currentInstallment,
        creditCardGroupId: expense.creditCardGroupId,
        isPaid: expense.isPaid,
      );
      _webExpenses.add(newExpense);
      
      // Actualizar contador local para mantener sincronía
      if (finalId >= _webExpenseIdCounter) {
        _webExpenseIdCounter = finalId + 1;
      }
      
      print('🔍 DEBUG Web: Gasto agregado con ID: ${newExpense.id}');
      print('🔍 DEBUG Web: Total gastos: ${_webExpenses.length}');
      print('💰 Web: Agregado gasto ${newExpense.description} - \$${newExpense.amount}');
      
      // Sincronizar a Firebase en segundo plano (solo si no viene de Firestore)
      if (expense.id == null || expense.id! <= 0) {
        FirebaseSyncService.syncExpenseToFirestore(newExpense).then((success) {
          if (success) {
            print('✅ Gasto sincronizado a Firebase: ${newExpense.description}');
          } else {
            print('❌ Error sincronizando gasto a Firebase: ${newExpense.description}');
          }
        });
      }
      
      return newExpense.id!;
    }
    
    final db = await database;
    final expenseMap = expense.toMap();
    print('💰 SQLite: Insertando expense: $expenseMap');
    final id = await db.insert('expenses', expenseMap);
    print('✅ SQLite: Expense insertado con ID: $id, userId: ${expense.userId}');
    return id;
  }

  /// Inserta un gasto con tarjeta de crédito generando todas las cuotas
  Future<List<int>> insertCreditCardExpense({
    required int userId,
    required double totalAmount,
    required String description,
    required DateTime startDate,
    required int categoryId,
    required int installments,
  }) async {
    final List<int> insertedIds = [];
    final groupId = 'cc_${DateTime.now().millisecondsSinceEpoch}';
    final installmentAmount = totalAmount / installments;
    
    print('💳 Creando gasto con tarjeta: $description');
    print('💰 Total: \$${totalAmount.toStringAsFixed(2)} en $installments cuotas de \$${installmentAmount.toStringAsFixed(2)}');
    
    for (int i = 1; i <= installments; i++) {
      final installmentDate = DateTime(
        startDate.year,
        startDate.month + (i - 1), // Cada cuota un mes después
        startDate.day,
      );
      
      final expense = Expense(
        userId: userId,
        amount: installmentAmount,
        description: description,
        date: installmentDate,
        categoryId: categoryId,
        isCreditCard: true,
        totalInstallments: installments,
        currentInstallment: i,
        creditCardGroupId: groupId,
        isPaid: false,
      );
      
      final id = await insertExpense(expense);
      insertedIds.add(id);
      
      print('✅ Cuota $i/$installments creada para ${installmentDate.month}/${installmentDate.year}');
    }
    
    print('🎉 Gasto con tarjeta creado exitosamente: ${insertedIds.length} cuotas');
    return insertedIds;
  }

  /// Marca una cuota de tarjeta como pagada o no pagada
  Future<void> updateInstallmentPaymentStatus(int expenseId, bool isPaid) async {
    if (kIsWeb) {
      final index = _webExpenses.indexWhere((expense) => expense.id == expenseId);
      if (index != -1) {
        final updatedExpense = _webExpenses[index].copyWith(isPaid: isPaid);
        _webExpenses[index] = updatedExpense;
        
        // Sincronizar a Firebase en segundo plano
        FirebaseSyncService.syncExpenseToFirestore(updatedExpense).then((success) {
          if (success) {
            print('✅ Estado de pago sincronizado a Firebase: ${updatedExpense.description}');
          } else {
            print('❌ Error sincronizando estado de pago a Firebase: ${updatedExpense.description}');
          }
        });
      }
      return;
    }
    
    final db = await database;
    await db.update(
      'expenses',
      {'is_paid': isPaid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [expenseId],
    );
  }

  /// Obtiene todos los gastos o filtrados por usuario
  Future<List<Expense>> getExpenses({int? userId}) async {
    if (kIsWeb) {
      // Filtrar por usuario si se especifica
      final filteredExpenses = userId != null 
          ? _webExpenses.where((expense) => expense.userId == userId).toList()
          : List<Expense>.from(_webExpenses);
      
      // Ordenar por fecha descendente (más recientes primero)
      filteredExpenses.sort((a, b) => b.date.compareTo(a.date));
      print('📋 Web: Retornando ${filteredExpenses.length} gastos para usuario $userId');
      return filteredExpenses;
    }
    
    final db = await database;
    print('📋 SQLite: Buscando expenses para userId: $userId');
    final maps = await db.query(
      'expenses',
      where: userId != null ? 'user_id = ?' : null,
      whereArgs: userId != null ? [userId] : null,
      orderBy: 'date DESC',
    );
    print('📋 SQLite: Encontrados ${maps.length} expenses para userId: $userId');
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  /// Obtiene gastos filtrados por un rango de fechas y opcionalmente por usuario
  Future<List<Expense>> getExpensesByDateRange(DateTime startDate, DateTime endDate, {int? userId}) async {
    if (kIsWeb) {
      return _webExpenses.where((expense) {
        final dateMatch = expense.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
               expense.date.isBefore(endDate.add(const Duration(days: 1)));
        final userMatch = userId == null || expense.userId == userId;
        return dateMatch && userMatch;
      }).toList();
    }
    
    final db = await database;
    final String whereClause = userId != null ? 'date BETWEEN ? AND ? AND user_id = ?' : 'date BETWEEN ? AND ?';
    final List<dynamic> whereArgs = userId != null 
        ? [startDate.toIso8601String(), endDate.toIso8601String(), userId]
        : [startDate.toIso8601String(), endDate.toIso8601String()];
        
    final maps = await db.query(
      'expenses',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  /// Obtiene gastos de una categoría específica
  Future<List<Expense>> getExpensesByCategory(int categoryId) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  /// Actualiza un gasto existente
  Future<int> updateExpense(Expense expense) async {
    if (kIsWeb) {
      final index = _webExpenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _webExpenses[index] = expense;
        
        // Sincronizar a Firebase en segundo plano
        FirebaseSyncService.syncExpenseToFirestore(expense).then((success) {
          if (success) {
            print('✅ Gasto actualizado sincronizado a Firebase: ${expense.description}');
          } else {
            print('❌ Error sincronizando gasto actualizado a Firebase: ${expense.description}');
          }
        });
        
        return 1; // Éxito
      }
      return 0; // No encontrado
    }
    
    final db = await database;
    final result = await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    
    // En móvil también sincronizar a Firebase
    if (result > 0) {
      FirebaseSyncService.syncExpenseToFirestore(expense);
    }
    
    return result;
  }

  // MÉTODOS PARA ESTADÍSTICAS

  /// Obtiene el total gastado en un período específico
  Future<double> getTotalExpensesByPeriod(DateTime startDate, DateTime endDate) async {
    if (kIsWeb) {
      final expensesInPeriod = _webExpenses.where((expense) =>
        expense.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
        expense.date.isBefore(endDate.add(const Duration(days: 1)))
      );
      
      double total = 0.0;
      for (final expense in expensesInPeriod) {
        total += expense.amount;
      }
      
      print('📊 Web: Total del período: \$${total.toStringAsFixed(2)}');
      return total;
    }
    
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date BETWEEN ? AND ?',
      [startDate.toIso8601String(), endDate.toIso8601String()],
    );
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// Elimina un gasto
  Future<int> deleteExpense(int id) async {
    if (kIsWeb) {
      final index = _webExpenses.indexWhere((expense) => expense.id == id);
      if (index != -1) {
        _webExpenses.removeAt(index);
        print('🗑️ Web: Eliminado gasto con ID $id');
        return 1; // Simulamos que se eliminó 1 registro
      }
      return 0; // No se encontró
    }
    
    final db = await database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Obtiene gastos agrupados por categoría para gráficos
  Future<Map<String, double>> getExpensesGroupedByCategory(DateTime startDate, DateTime endDate) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT c.name, SUM(e.amount) as total 
      FROM expenses e 
      JOIN categories c ON e.category_id = c.id 
      WHERE e.date BETWEEN ? AND ? 
      GROUP BY c.id, c.name
      ORDER BY total DESC
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);
    
    final Map<String, double> categoryTotals = {};
    for (final row in result) {
      categoryTotals[row['name'] as String] = (row['total'] as num).toDouble();
    }
    
    return categoryTotals;
  }

  // OPERACIONES CRUD PARA PRESUPUESTOS

  /// Inserta un nuevo presupuesto
  Future<int> insertBudget(Budget budget) async {
    if (kIsWeb) {
      final newBudget = budget.copyWith(
        id: _webBudgetIdCounter++,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _webBudgets.add(newBudget);
      print('💰 Web: Presupuesto creado con ID ${newBudget.id}');
      return newBudget.id!;
    }

    final db = await database;
    final budgetWithDates = budget.copyWith(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    return await db.insert('budgets', budgetWithDates.toMap());
  }

  /// Obtiene todos los presupuestos de un usuario para un mes específico
  Future<List<Budget>> getBudgetsByMonth(int userId, int month, int year) async {
    if (kIsWeb) {
      return _webBudgets
          .where((budget) => 
              budget.userId == userId && 
              budget.month == month && 
              budget.year == year)
          .toList();
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'user_id = ? AND month = ? AND year = ?',
      whereArgs: [userId, month, year],
      orderBy: 'category_id',
    );
    return maps.map((map) => Budget.fromMap(map)).toList();
  }

  /// Obtiene todos los presupuestos de un usuario
  Future<List<Budget>> getUserBudgets(int userId) async {
    if (kIsWeb) {
      return _webBudgets
          .where((budget) => budget.userId == userId)
          .toList();
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'year DESC, month DESC, category_id',
    );
    return maps.map((map) => Budget.fromMap(map)).toList();
  }

  /// Obtiene un presupuesto específico por categoría, usuario y mes
  Future<Budget?> getBudget(int userId, int categoryId, int month, int year) async {
    if (kIsWeb) {
      try {
        return _webBudgets.firstWhere((budget) => 
            budget.userId == userId && 
            budget.categoryId == categoryId &&
            budget.month == month && 
            budget.year == year);
      } catch (e) {
        return null;
      }
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budgets',
      where: 'user_id = ? AND category_id = ? AND month = ? AND year = ?',
      whereArgs: [userId, categoryId, month, year],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  /// Actualiza un presupuesto existente
  Future<int> updateBudget(Budget budget) async {
    if (kIsWeb) {
      final index = _webBudgets.indexWhere((b) => b.id == budget.id);
      if (index != -1) {
        _webBudgets[index] = budget.copyWith(updatedAt: DateTime.now());
        print('💰 Web: Presupuesto ${budget.id} actualizado');
        return 1;
      }
      return 0;
    }

    final db = await database;
    final budgetWithUpdatedDate = budget.copyWith(updatedAt: DateTime.now());
    
    return await db.update(
      'budgets',
      budgetWithUpdatedDate.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  /// Elimina un presupuesto
  Future<int> deleteBudget(int budgetId) async {
    if (kIsWeb) {
      final initialLength = _webBudgets.length;
      _webBudgets.removeWhere((budget) => budget.id == budgetId);
      final removed = initialLength - _webBudgets.length;
      print('💰 Web: Presupuesto $budgetId ${removed > 0 ? 'eliminado' : 'no encontrado'}');
      return removed;
    }

    final db = await database;
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [budgetId],
    );
  }

  /// Obtiene el total gastado en una categoría para un mes específico
  Future<double> getSpentAmountByCategory(int userId, int categoryId, int month, int year) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);
    
    final expenses = await getExpensesByDateRange(startDate, endDate, userId: userId);
    
    double total = 0.0;
    for (final expense in expenses) {
      if (expense.categoryId == categoryId) {
        total += expense.amount;
      }
    }
    return total;
  }

  /// Obtiene estadísticas de presupuestos para un usuario y mes
  Future<Map<String, dynamic>> getBudgetStats(int userId, int month, int year) async {
    final budgets = await getBudgetsByMonth(userId, month, year);
    
    if (budgets.isEmpty) {
      return {
        'totalBudgeted': 0.0,
        'totalSpent': 0.0,
        'remaining': 0.0,
        'exceeded': 0,
        'warning': 0,
        'onTrack': 0,
        'safe': 0,
      };
    }

    double totalBudgeted = 0.0;
    double totalSpent = 0.0;
    int exceeded = 0;
    int warning = 0;
    int onTrack = 0;
    int safe = 0;

    for (final budget in budgets) {
      totalBudgeted += budget.amount;
      final spent = await getSpentAmountByCategory(userId, budget.categoryId, month, year);
      totalSpent += spent;
      
      final status = budget.getStatus(spent);
      switch (status) {
        case BudgetStatus.exceeded:
          exceeded++;
          break;
        case BudgetStatus.warning:
          warning++;
          break;
        case BudgetStatus.onTrack:
          onTrack++;
          break;
        case BudgetStatus.safe:
          safe++;
          break;
      }
    }

    return {
      'totalBudgeted': totalBudgeted,
      'totalSpent': totalSpent,
      'remaining': totalBudgeted - totalSpent,
      'exceeded': exceeded,
      'warning': warning,
      'onTrack': onTrack,
      'safe': safe,
    };
  }

  /// Obtiene el reporte de un mes específico
  Future<MonthlyReport?> getMonthlyReport(int year, int month, {int? userId}) async {
    try {
      // Calcular fechas del mes
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 0);
      
      // Obtener gastos del mes
      final monthExpenses = await getExpensesByDateRange(monthStart, monthEnd, userId: userId);
      
      if (monthExpenses.isEmpty) {
        return null; // No hay datos para este mes
      }

      // Calcular estadísticas básicas
      final total = monthExpenses.fold(0.0, (sum, expense) => sum + expense.amount);
      final expenseCount = monthExpenses.length;
      final averageExpense = total / expenseCount;
      
      // Calcular totales por categoría
      final Map<int, double> categoryTotals = {};
      for (final expense in monthExpenses) {
        categoryTotals[expense.categoryId] = 
            (categoryTotals[expense.categoryId] ?? 0) + expense.amount;
      }
      
      // Encontrar la categoría principal
      int? topCategoryId;
      double? topCategoryAmount;
      if (categoryTotals.isNotEmpty) {
        final topEntry = categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
        topCategoryId = topEntry.key;
        topCategoryAmount = topEntry.value;
      }
      
      // Fechas de primer y último gasto
      monthExpenses.sort((a, b) => a.date.compareTo(b.date));
      final firstExpenseDate = monthExpenses.first.date;
      final lastExpenseDate = monthExpenses.last.date;
      
      // Obtener datos del mes anterior para comparación
      final previousMonthStart = DateTime(year, month - 1, 1);
      final previousMonthEnd = DateTime(year, month, 0);
      final previousMonthExpenses = await getExpensesByDateRange(
        previousMonthStart, previousMonthEnd, userId: userId);
      
      double? previousMonthTotal;
      double? changePercentage;
      int? expenseCountChange;
      
      if (previousMonthExpenses.isNotEmpty) {
        previousMonthTotal = previousMonthExpenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
        
        if (previousMonthTotal > 0) {
          changePercentage = ((total - previousMonthTotal) / previousMonthTotal) * 100;
        }
        
        expenseCountChange = expenseCount - previousMonthExpenses.length;
      }
      
      return MonthlyReport(
        year: year,
        month: month,
        total: total,
        expenseCount: expenseCount,
        averageExpense: averageExpense,
        categoryTotals: categoryTotals,
        firstExpenseDate: firstExpenseDate,
        lastExpenseDate: lastExpenseDate,
        previousMonthTotal: previousMonthTotal,
        changePercentage: changePercentage,
        expenseCountChange: expenseCountChange,
        topCategoryId: topCategoryId,
        topCategoryAmount: topCategoryAmount,
      );
    } catch (e) {
      print('Error generating monthly report: $e');
      return null;
    }
  }

  /// Obtiene una lista de meses que tienen gastos registrados
  Future<List<Map<String, int>>> getMonthsWithExpenses({int? userId}) async {
    try {
      List<Expense> allExpenses;
      
      if (kIsWeb) {
        allExpenses = userId != null 
          ? _webExpenses.where((expense) => expense.userId == userId).toList()
          : _webExpenses;
      } else {
        final db = await database;
        final List<Map<String, dynamic>> maps;
        
        if (userId != null) {
          maps = await db.query(
            'expenses', 
            where: 'user_id = ?',
            whereArgs: [userId],
            orderBy: 'date DESC'
          );
        } else {
          maps = await db.query('expenses', orderBy: 'date DESC');
        }
        
        allExpenses = maps.map((map) => Expense.fromMap(map)).toList();
      }
      
      // Agrupar por año y mes
      final Set<String> monthYearSet = {};
      for (final expense in allExpenses) {
        final key = '${expense.date.year}-${expense.date.month}';
        monthYearSet.add(key);
      }
      
      // Convertir a lista de mapas y ordenar
      final List<Map<String, int>> monthsList = monthYearSet.map((key) {
        final parts = key.split('-');
        return {
          'year': int.parse(parts[0]),
          'month': int.parse(parts[1]),
        };
      }).toList();
      
      // Ordenar por año y mes (más reciente primero)
      monthsList.sort((a, b) {
        final aDate = DateTime(a['year']!, a['month']!);
        final bDate = DateTime(b['year']!, b['month']!);
        return bDate.compareTo(aDate);
      });
      
      return monthsList;
    } catch (e) {
      print('Error getting months with expenses: $e');
      return [];
    }
  }

  /// Obtiene estadísticas generales de todos los meses
  Future<Map<String, dynamic>> getGeneralStats({int? userId}) async {
    try {
      final months = await getMonthsWithExpenses(userId: userId);
      if (months.isEmpty) return {};
      
      final List<MonthlyReport> reports = [];
      for (final month in months) {
        final report = await getMonthlyReport(month['year']!, month['month']!, userId: userId);
        if (report != null) {
          reports.add(report);
        }
      }
      
      if (reports.isEmpty) return {};
      
      // Calcular estadísticas generales
      final totalSpent = reports.fold(0.0, (sum, report) => sum + report.total);
      final averageMonthly = totalSpent / reports.length;
      final highestMonth = reports.reduce((a, b) => a.total > b.total ? a : b);
      final lowestMonth = reports.reduce((a, b) => a.total < b.total ? a : b);
      
      return {
        'totalMonths': reports.length,
        'totalSpent': totalSpent,
        'averageMonthly': averageMonthly,
        'highestMonth': highestMonth,
        'lowestMonth': lowestMonth,
        'reports': reports,
      };
    } catch (e) {
      print('Error getting general stats: $e');
      return {};
    }
  }

  /// Obtiene los gastos de un mes específico
  Future<List<Expense>> getExpensesByMonth(int year, int month, {int? userId}) async {
    try {
      List<Expense> allExpenses;
      
      if (kIsWeb) {
        allExpenses = userId != null 
          ? _webExpenses.where((expense) => expense.userId == userId).toList()
          : _webExpenses;
      } else {
        allExpenses = await getExpenses(userId: userId);
      }

      // Filtrar gastos del mes específico
      final monthExpenses = allExpenses.where((expense) {
        return expense.date.year == year && expense.date.month == month;
      }).toList();

      // Ordenar por fecha (más reciente primero)
      monthExpenses.sort((a, b) => b.date.compareTo(a.date));

      return monthExpenses;
    } catch (e) {
      print('Error getting expenses by month: $e');
      return [];
    }
  }

  /// Carga las categorías personalizadas del usuario desde Firestore
  Future<void> _loadUserCategoriesFromFirestore(String userId) async {
    try {
      final categoriesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .orderBy('name')
          .get();

      if (categoriesSnapshot.docs.isEmpty) {
        print('✅ No hay categorías personalizadas en Firestore para este usuario');
        return;
      }

      // Obtener el ID máximo actual para evitar conflictos
      int maxId = _webCategories.isNotEmpty 
          ? _webCategories.map((c) => c.id!).reduce((a, b) => a > b ? a : b)
          : 0;

      // Agregar categorías personalizadas a las existentes
      for (final doc in categoriesSnapshot.docs) {
        final data = doc.data();
        final category = Category(
          id: data['id'] ?? ++maxId, // Usar ID de Firestore o asignar nuevo
          name: data['name'],
          icon: data['icon'],
          color: data['color'],
        );
        
        // Verificar que no exista ya una categoría con el mismo nombre
        final existingCategory = _webCategories.where((c) => c.name == category.name);
        if (existingCategory.isEmpty) {
          _webCategories.add(category);
          if (category.id! > _webCategoryIdCounter) {
            _webCategoryIdCounter = category.id! + 1;
          }
        }
      }

      print('✅ Agregadas ${categoriesSnapshot.docs.length} categorías personalizadas desde Firestore');
    } catch (e) {
      print('❌ Error cargando categorías de Firestore: $e');
    }
  }

  /// Guarda una categoría en Firestore de forma asíncrona sin bloquear
  void _saveCategoryToFirestoreAsync(Category category) {
    Future.microtask(() async {
      try {
        final currentUser = await _storageService.getCurrentUser();
        if (currentUser?.id != null) {
          await _saveCategoryToFirestore(category, currentUser!.id.toString());
        } else {
          print('⚠️ No hay usuario autenticado para guardar categoría en Firestore');
        }
      } catch (e) {
        print('⚠️ Error guardando categoría en Firestore: $e');
      }
    });
  }

  /// Actualiza una categoría en Firestore de forma asíncrona sin bloquear
  void _updateCategoryInFirestoreAsync(Category category) {
    Future.microtask(() async {
      try {
        final currentUser = await _storageService.getCurrentUser();
        if (currentUser?.id != null) {
          await _saveCategoryToFirestore(category, currentUser!.id.toString());
        }
      } catch (e) {
        print('⚠️ Error actualizando categoría en Firestore: $e');
      }
    });
  }

  /// Elimina una categoría de Firestore de forma asíncrona sin bloquear
  void _deleteCategoryFromFirestoreAsync(int categoryId) {
    Future.microtask(() async {
      try {
        final currentUser = await _storageService.getCurrentUser();
        if (currentUser?.id != null) {
          await _deleteCategoryFromFirestore(categoryId, currentUser!.id.toString());
        }
      } catch (e) {
        print('⚠️ Error eliminando categoría de Firestore: $e');
      }
    });
  }

  /// Guarda una categoría en Firestore
  Future<void> _saveCategoryToFirestore(Category category, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(category.id.toString())
          .set({
        'id': category.id,
        'name': category.name,
        'icon': category.icon,
        'color': category.color,
      });
      
      print('✅ Categoría "${category.name}" guardada en Firestore');
    } catch (e) {
      print('❌ Error guardando categoría en Firestore: $e');
      throw e;
    }
  }

  /// Elimina una categoría de Firestore
  Future<void> _deleteCategoryFromFirestore(int categoryId, String userId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('categories')
          .doc(categoryId.toString())
          .delete();
      
      print('✅ Categoría eliminada de Firestore');
    } catch (e) {
      print('❌ Error eliminando categoría de Firestore: $e');
      throw e;
    }
  }

  /// Cierra la conexión a la base de datos
  Future<void> close() async {
    if (kIsWeb) return; // No cierra en web
    final db = await database;
    await db.close();
  }

  // ==================== MÉTODOS PARA DIVISIONES DE GASTOS ====================

  /// Inserta una nueva división de gastos
  Future<int> insertDivision(ExpenseDivision division) async {
    if (kIsWeb) {
      // Simulación para web - no implementado aún
      throw UnsupportedError('Divisiones no soportadas en web');
    }

    try {
      final db = await database;
      final id = await db.insert('expense_divisions', division.toMap());
      
      // Insertar participantes
      for (final participant in division.participants) {
        await db.insert(
          'division_participants',
          participant.copyWith(divisionId: id).toMap(),
        );
      }

      print('✅ División creada con ID: $id');
      return id;
    } catch (e) {
      print('❌ Error insertando división: $e');
      rethrow;
    }
  }

  /// Obtiene todas las divisiones del usuario
  Future<List<ExpenseDivision>> getDivisions({required int userId}) async {
    if (kIsWeb) {
      throw UnsupportedError('Divisiones no soportadas en web');
    }

    try {
      final db = await database;
      final maps = await db.query(
        'expense_divisions',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
      );

      final divisions = <ExpenseDivision>[];
      for (final map in maps) {
        final division = ExpenseDivision.fromMap(map);
        
        // Cargar participantes
        final participantMaps = await db.query(
          'division_participants',
          where: 'division_id = ?',
          whereArgs: [division.id],
        );
        
        final participants = participantMaps
            .map((pm) => Participant.fromMap(pm))
            .toList();
        
        divisions.add(division.copyWith(participants: participants));
      }

      return divisions;
    } catch (e) {
      print('❌ Error obteniendo divisiones: $e');
      return [];
    }
  }

  /// Obtiene una división específica por ID
  Future<ExpenseDivision?> getDivisionById(int divisionId) async {
    if (kIsWeb) {
      throw UnsupportedError('Divisiones no soportadas en web');
    }

    try {
      final db = await database;
      final maps = await db.query(
        'expense_divisions',
        where: 'id = ?',
        whereArgs: [divisionId],
      );

      if (maps.isEmpty) return null;

      final division = ExpenseDivision.fromMap(maps.first);
      
      // Cargar participantes
      final participantMaps = await db.query(
        'division_participants',
        where: 'division_id = ?',
        whereArgs: [divisionId],
      );
      
      final participants = participantMaps
          .map((pm) => Participant.fromMap(pm))
          .toList();
      
      return division.copyWith(participants: participants);
    } catch (e) {
      print('❌ Error obteniendo división: $e');
      return null;
    }
  }

  /// Actualiza una división de gastos
  Future<int> updateDivision(ExpenseDivision division) async {
    if (kIsWeb) {
      throw UnsupportedError('Divisiones no soportadas en web');
    }

    try {
      final db = await database;
      
      // Actualizar división
      final result = await db.update(
        'expense_divisions',
        division.toMap(),
        where: 'id = ?',
        whereArgs: [division.id],
      );

      // Eliminar y reinsertar participantes
      await db.delete(
        'division_participants',
        where: 'division_id = ?',
        whereArgs: [division.id],
      );

      for (final participant in division.participants) {
        await db.insert(
          'division_participants',
          participant.copyWith(divisionId: division.id).toMap(),
        );
      }

      print('✅ División actualizada: ${division.id}');
      return result;
    } catch (e) {
      print('❌ Error actualizando división: $e');
      rethrow;
    }
  }

  /// Elimina una división de gastos
  Future<int> deleteDivision(int divisionId) async {
    if (kIsWeb) {
      throw UnsupportedError('Divisiones no soportadas en web');
    }

    try {
      final db = await database;
      
      // Eliminar participantes
      await db.delete(
        'division_participants',
        where: 'division_id = ?',
        whereArgs: [divisionId],
      );

      // Eliminar división
      final result = await db.delete(
        'expense_divisions',
        where: 'id = ?',
        whereArgs: [divisionId],
      );

      print('✅ División eliminada: $divisionId');
      return result;
    } catch (e) {
      print('❌ Error eliminando división: $e');
      rethrow;
    }
  }

  /// Marca una división como liquidada
  Future<int> settleDivision(int divisionId) async {
    if (kIsWeb) {
      throw UnsupportedError('Divisiones no soportadas en web');
    }

    try {
      final db = await database;
      final result = await db.update(
        'expense_divisions',
        {
          'is_settled': 1,
          'settled_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [divisionId],
      );

      print('✅ División liquidada: $divisionId');
      return result;
    } catch (e) {
      print('❌ Error liquidando división: $e');
      rethrow;
    }
  }
}
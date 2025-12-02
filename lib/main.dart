import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/firebase_sync_service.dart';
import 'services/theme_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  // Asegura que Flutter esté inicializado antes de ejecutar la app
  WidgetsFlutterBinding.ensureInitialized();
  
  final platformInfo = kIsWeb ? 'Web' : Platform.operatingSystem;
  print('🚀 INICIO: Aplicación iniciando en $platformInfo');
  
  // Inicializar Firebase
  try {
    print('🔥 FIREBASE: Inicializando Firebase para plataforma: $platformInfo');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ FIREBASE: Firebase inicializado correctamente');
  } catch (e) {
    print('❌ FIREBASE ERROR: $e');
    // Continuar de todas formas para debug
  }
  
  // Inicializar servicio de sincronización
  try {
    print('🔄 SYNC: Inicializando FirebaseSyncService...');
    await FirebaseSyncService.initialize();
    print('✅ SYNC: FirebaseSyncService inicializado');
  } catch (e) {
    print('❌ SYNC ERROR: $e');
  }
  
  // Inicializar servicio de temas
  final themeService = ThemeService();
  await themeService.init();
  
  // Inicializa la localización en español
  await initializeDateFormatting('es', null);
  
  print('🚀 APP: Iniciando interfaz...');
  runApp(ExpenseTrackerApp(themeService: themeService));
}

/// Aplicación principal para el rastreador de gastos
class ExpenseTrackerApp extends StatelessWidget {
  final ThemeService themeService;

  const ExpenseTrackerApp({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeService>.value(
      value: themeService,
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            title: 'GastoTorta',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme(themeService.accentColor),
            darkTheme: AppThemes.darkTheme(themeService.accentColor),
            themeMode: themeService.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}

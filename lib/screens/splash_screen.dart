import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/firebase_sync_service.dart';
import '../widgets/sync_progress_bar.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

/// Pantalla de splash con verificación automática de sesión
/// 
/// Se muestra al iniciar la app y verifica si el usuario
/// ya está autenticado para navegar automáticamente
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
    with TickerProviderStateMixin {
  final _storageService = StorageService();
  
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkSession();
  }

  /// Configura las animaciones
  void _setupAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    // Iniciar animaciones
    _logoController.forward();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _textController.forward();
      }
    });
  }

  /// Verifica si hay una sesión activa
  Future<void> _checkSession() async {
    try {
      // Esperar mínimo tiempo para mostrar splash
      await Future.delayed(const Duration(seconds: 2));

      // Verificar si hay sesión activa (con timeout)
      bool isLoggedIn = false;
      try {
        isLoggedIn = await _storageService.isLoggedIn().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('⚠️ Timeout verificando sesión, asumiendo no autenticado');
            return false;
          },
        );
      } catch (e) {
        print('Error verificando sesión: $e');
        isLoggedIn = false;
      }
      
      if (mounted) {
        if (isLoggedIn) {
          // Usuario está autenticado, hacer fullSync antes de ir al Dashboard
          print('🔄 Splash: Realizando sincronización completa antes de navegar...');
          try {
            // Inicializar el servicio de sincronización si no está inicializado
            await FirebaseSyncService.initialize();
            
            // Timeout de 15 segundos para el sync completo (más tiempo para APK)
            await FirebaseSyncService.fullSync().timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('⚠️ Splash: Timeout en sincronización, continuando sin esperar');
              },
            );
            print('✅ Splash: Sincronización completada');
            
            // Esperar un poco más para que la UI se renderice en APK
            await Future.delayed(const Duration(milliseconds: 1000));
          } catch (e) {
            print('⚠️ Splash: Error en sincronización inicial: $e');
            // Continuar de todas formas
          }
          
          // Ir al dashboard
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const DashboardScreen(),
              ),
            );
          }
        } else {
          // No hay sesión válida, ir al login
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          }
        }
      }
    } catch (e) {
      // En caso de error, ir al login como fallback
      print('Error checking session: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Stack(
        children: [
          // Contenido principal
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animado
                ScaleTransition(
                  scale: _logoAnimation,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/chocotorta.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Título animado
                FadeTransition(
                  opacity: _textAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(_textAnimation),
                    child: Column(
                      children: [
                        Text(
                          'GastoTorta',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Controla tus finanzas de manera inteligente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 60),

            // Indicador de carga
            FadeTransition(
              opacity: _textAnimation,
              child: Column(
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.8),
                      ),
                      strokeWidth: 3,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    'Verificando sesión...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),

            // Información de versión
            FadeTransition(
              opacity: _textAnimation,
              child: Text(
                'Versión 1.0.0',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
              ],
            ),
          ),
          
          // Barra de progreso de sincronización en la parte superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SyncProgressBar(
              backgroundColor: Colors.white.withOpacity(0.2),
              progressColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
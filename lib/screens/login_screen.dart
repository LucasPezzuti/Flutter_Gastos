import 'package:flutter/material.dart';
import '../models/auth_response.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/storage_service.dart';
import 'dashboard_screen.dart';

/// Pantalla de login con usuarios simulados
/// 
/// Permite autenticación con credenciales hardcodeadas
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firebaseAuthService = FirebaseAuthService();
  final _storageService = StorageService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRegistering = false; // Para alternar entre login y registro

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Procesa el login o registro
  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      AuthResponse authResponse;
      
      if (_isRegistering) {
        // Registro de nuevo usuario
        authResponse = await _firebaseAuthService.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _emailController.text.split('@')[0], // Usar parte del email como nombre por defecto
        );
      } else {
        // Login de usuario existente
        authResponse = await _firebaseAuthService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (authResponse.success) {
        // Guardar sesión localmente
        await _storageService.saveSession(
          token: authResponse.token,
          user: authResponse.user,
          expiresAt: authResponse.expiresAt,
        );

        if (mounted) {
          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isRegistering 
                  ? '¡Cuenta creada! Bienvenido ${authResponse.user.name ?? authResponse.user.email}!' 
                  : '¡Bienvenido de vuelta ${authResponse.user.name ?? authResponse.user.email}!'
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Verificar si necesita sincronización inicial
          final syncDone = await _storageService.isSyncDone();
          
          if (!syncDone) {
            // Mostrar dialog de sincronización
            if (mounted) {
              _showSyncDialog();
            }
          } else {
            // Ya se sincronizó antes, navegar directamente
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const DashboardScreen(),
                ),
              );
            }
          }
        }
      } else {
        // Mostrar error de autenticación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authResponse.message ?? 'Error de autenticación'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Muestra un dialog con progreso de sincronización
  void _showSyncDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // No se puede cerrar tocando afuera
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Evitar back button
          child: Dialog(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_download,
                    size: 48,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sincronizando datos...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Esta es la primera vez que inicias sesión.\nEstamos sincronizando tus gastos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  // Stream del progreso
                  StreamBuilder<int>(
                    stream: FirebaseSyncService.syncProgressStream,
                    initialData: 0,
                    builder: (context, snapshot) {
                      final progress = snapshot.data ?? 0;
                      return Column(
                        children: [
                          LinearProgressIndicator(
                            value: progress / 100,
                            minHeight: 6,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$progress%',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        );
      },
    );

    // Realizar la sincronización
    _performInitialSync();
  }

  /// Realiza la sincronización inicial y luego navega
  Future<void> _performInitialSync() async {
    try {
      // Inicializar el servicio de sincronización
      await FirebaseSyncService.initialize();
      
      // Marcar como sincronizado
      await _storageService.markSyncDone();
      
      print('✅ Sincronización completada exitosamente');
      
      // Cerrar el dialog y navegar
      if (mounted) {
        Navigator.of(context).pop(); // Cerrar dialog
        
        // Navegar al dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DashboardScreen(),
          ),
        );
      }
    } catch (e) {
      print('❌ Error en sincronización: $e');
      
      if (mounted) {
        Navigator.of(context).pop(); // Cerrar dialog
        
        // Mostrar error pero permitir continuar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en sincronización: $e'),
            backgroundColor: Colors.orange,
          ),
        );
        
        // Navegar de todos modos
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const DashboardScreen(),
          ),
        );
      }
    }
  }

  /// Rellena automáticamente con credenciales de demo
  void _fillDemoCredentials(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegistering ? 'Crear Cuenta' : 'Iniciar Sesión'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // Logo o icono de Chocotorta
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/chocotorta.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Si no existe la imagen, mostrar un icono
                    return Icon(
                      Icons.pets,
                      size: 60,
                      color: Theme.of(context).primaryColor,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                'GastoTorta',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),

              // Subtítulo
              Text(
                _isRegistering 
                  ? 'Crea tu cuenta para comenzar'
                  : 'Ingresa tus credenciales para continuar',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),

              // Campo de email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                    helperText: _isRegistering 
                      ? 'Usa tu email real para crear la cuenta'
                      : 'Ejemplo: usuario@test.com',
                  ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu email';
                  }
                  if (!value.contains('@')) {
                    return 'Por favor ingresa un email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo de password
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                  helperText: 'admin: 123456, user: password, demo: demo',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa tu contraseña';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Botón principal
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _authenticate,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: _isLoading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(_isRegistering ? 'Creando cuenta...' : 'Iniciando sesión...'),
                          ],
                        )
                      : Text(_isRegistering ? 'Crear Cuenta' : 'Iniciar Sesión'),
                ),
              ),
              const SizedBox(height: 16),

              // Botón para alternar entre login y registro
              TextButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                    _emailController.clear();
                    _passwordController.clear();
                  });
                },
                child: Text(
                  _isRegistering 
                    ? '¿Ya tienes cuenta? Inicia sesión'
                    : '¿No tienes cuenta? Regístrate',
                ),
              ),
              const SizedBox(height: 24),

              // Usuarios de ejemplo (solo para login, no registro)
              
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDemoUserTile(String name, String email, String password, IconData icon, Color color) {
    return InkWell(
      onTap: () => _fillDemoCredentials(email, password),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$email / $password',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.touch_app,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
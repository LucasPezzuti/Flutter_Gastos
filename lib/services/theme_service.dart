import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar temas (claro/oscuro)
class ThemeService extends ChangeNotifier {
  static const String _themePreferenceKey = 'app_theme_mode';
  static const String _accentColorKey = 'app_accent_color';

  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  Color _accentColor = Colors.blue;

  /// Getter para el modo de tema actual
  ThemeMode get themeMode => _themeMode;

  /// Getter para el color de acento
  Color get accentColor => _accentColor;

  /// Getter para verificar si está en modo oscuro
  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // Sistema: obtener del dispositivo
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  /// Inicializa el servicio de temas
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadThemePreference();
    _loadAccentColor();
  }

  /// Carga la preferencia de tema guardada
  void _loadThemePreference() {
    final savedTheme = _prefs.getString(_themePreferenceKey) ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.toString().split('.').last == savedTheme,
      orElse: () => ThemeMode.system,
    );
  }

  /// Carga el color de acento guardado
  void _loadAccentColor() {
    final savedColor = _prefs.getInt(_accentColorKey);
    if (savedColor != null) {
      _accentColor = Color(savedColor);
    }
  }

  /// Cambia el modo de tema y lo guarda
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(_themePreferenceKey, mode.toString().split('.').last);
    notifyListeners();
  }

  /// Cambia el color de acento y lo guarda
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _prefs.setInt(_accentColorKey, color.value);
    notifyListeners();
  }

  /// Alterna entre tema claro y oscuro
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}

/// Temas predefinidos de la aplicación
class AppThemes {
  /// Tema claro
  static ThemeData lightTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.light,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: accentColor.withOpacity(0.1),
        foregroundColor: Colors.black87,
        elevation: 2,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
    );
  }

  /// Tema oscuro
  static ThemeData darkTheme(Color accentColor) {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: Brightness.dark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.grey.shade800,
        elevation: 2,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade800,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: Colors.white,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
      ),
    );
  }
}

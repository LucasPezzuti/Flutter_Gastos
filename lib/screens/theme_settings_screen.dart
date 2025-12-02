import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';

/// Pantalla de configuración de tema y apariencia
class ThemeSettingsScreen extends StatefulWidget {
  const ThemeSettingsScreen({super.key});

  @override
  State<ThemeSettingsScreen> createState() => _ThemeSettingsScreenState();
}

class _ThemeSettingsScreenState extends State<ThemeSettingsScreen> {
  /// Colores de acento disponibles
  static const List<Color> _accentColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];

  static const List<String> _accentColorNames = [
    'Azul',
    'Rojo',
    'Verde',
    'Púrpura',
    'Naranja',
    'Teal',
    'Índigo',
    'Rosa',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Configuración de Tema'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sección de modo de tema
                Text(
                  'Modo de Tema',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        title: const Text('Claro'),
                        subtitle: const Text('Siempre usar tema claro'),
                        value: ThemeMode.light,
                        groupValue: themeService.themeMode,
                        onChanged: (mode) async {
                          if (mode != null) {
                            await themeService.setThemeMode(mode);
                          }
                        },
                      ),
                      const Divider(height: 0),
                      RadioListTile<ThemeMode>(
                        title: const Text('Oscuro'),
                        subtitle: const Text('Siempre usar tema oscuro'),
                        value: ThemeMode.dark,
                        groupValue: themeService.themeMode,
                        onChanged: (mode) async {
                          if (mode != null) {
                            await themeService.setThemeMode(mode);
                          }
                        },
                      ),
                      const Divider(height: 0),
                      RadioListTile<ThemeMode>(
                        title: const Text('Sistema'),
                        subtitle: const Text('Usar preferencia del dispositivo'),
                        value: ThemeMode.system,
                        groupValue: themeService.themeMode,
                        onChanged: (mode) async {
                          if (mode != null) {
                            await themeService.setThemeMode(mode);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Sección de color de acento
                Text(
                  'Color de Acento',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  'Selecciona el color principal de la aplicación',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _accentColors.length,
                  itemBuilder: (context, index) {
                    final color = _accentColors[index];
                    final isSelected = themeService.accentColor == color;

                    return GestureDetector(
                      onTap: () async {
                        await themeService.setAccentColor(color);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        child: isSelected
                            ? const Center(
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    _accentColors.length,
                    (index) => Tooltip(
                      message: _accentColorNames[index],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: _accentColors[index],
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          _accentColorNames[index],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Información adicional
                Card(
                  color: Colors.blue.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue),
                            const SizedBox(width: 12),
                            Text(
                              'Información',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• El modo "Sistema" usa la preferencia del dispositivo\n'
                          '• Los cambios se aplican inmediatamente\n'
                          '• Tus preferencias se guardan automáticamente\n'
                          '• El color de acento afecta a toda la interfaz',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

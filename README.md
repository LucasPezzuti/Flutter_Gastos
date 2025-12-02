# GastoTorta - Expense Tracker App

## Short Description (for portfolio)

**English:** Smart expense tracker built with Flutter & Firebase. Track spending, manage credit card installments, divide expenses with friends, analyze with AI, and export reports. Real-time sync across devices.

**Spanish:** Gestor de gastos inteligente con Flutter y Firebase. Registra gastos, administra cuotas de tarjeta, divide gastos entre amigos, analiza con IA y exporta reportes. Sincronización en tiempo real.

---

## 📱 English Version

### About GastoTorta

GastoTorta is a comprehensive expense tracking application built with **Flutter** and **Firebase**. Designed to help users manage their personal finances efficiently with advanced features for tracking spending, managing credit card installments, and generating insightful financial reports.

### ✨ Key Features

#### 💰 **Expense Management**
- Quick and easy expense logging with multiple input methods
- Support for cash and credit card transactions
- Voice-to-text expense entry using speech recognition
- Automatic categorization and tagging
- Search and filter expenses by date, category, and amount

#### 💳 **Credit Card Installments**
- Track credit card purchases across multiple installments (1-60 months)
- Visualize installment payments schedule
- Mark installments as paid/pending
- Track current vs. future credit obligations
- Installment payment reminders

#### 👥 **Expense Splitting**
- Divide expenses among multiple people
- Flexible splitting options (equal, custom amounts, percentages)
- Track who owes whom
- Generate settlement reports
- Calculate total debts and credits

#### 📊 **Analytics & Insights**
- AI-powered expense analysis and spending patterns
- Visual charts and statistics (pie charts, line graphs, bar charts)
- Monthly and yearly spending trends
- Category-wise expense breakdown
- Spending alerts and budget warnings

#### 📤 **Data Export & Reporting**
- Export data to CSV format
- Generate PDF reports with detailed expense summaries
- Print-friendly financial reports
- Data backup and restoration

#### 🎨 **User Interface**
- Dark and light theme support
- Intuitive navigation with bottom tab bar
- Responsive design for all screen sizes
- Smooth animations and transitions
- Material Design 3 compliance

#### 🔐 **Security & Authentication**
- Firebase Authentication (Email/Password)
- Secure credential storage
- Session management
- User account management

#### ☁️ **Cloud Synchronization**
- Real-time Firebase Firestore sync
- Cross-device synchronization
- Offline-first approach with sync queue
- Automatic data backup to cloud
- Conflict resolution

### 🛠️ Tech Stack

**Frontend:**
- **Framework:** Flutter 3.10+
- **Language:** Dart
- **State Management:** Provider
- **UI Components:** Material Design 3

**Backend & Services:**
- **Authentication:** Firebase Authentication
- **Database:** Cloud Firestore
- **Backend Logic:** Firebase Cloud Functions (ready)
- **Real-time Updates:** Firebase Realtime Database

**Local Storage:**
- **SQLite:** Local database with sqflite
- **Secure Storage:** Flutter Secure Storage for sensitive data
- **Preferences:** Shared Preferences

**Additional Libraries:**
- **Charts:** FL Chart for data visualization
- **PDF Generation:** Printing & PDF libraries
- **Speech Recognition:** Speech to Text
- **File Management:** File Picker
- **Localization:** Intl (Spanish support)
- **HTTP:** For API calls

### 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/                            # Data models
│   └── expense.dart, user.dart, etc.
├── screens/                           # UI screens
│   ├── dashboard_screen.dart
│   ├── add_expense_screen.dart
│   ├── installments_payment_screen.dart
│   ├── expense_divider_screen.dart
│   ├── statistics_screen.dart
│   └── ...
├── services/                          # Business logic
│   ├── firebase_auth_service.dart
│   ├── firebase_sync_service.dart
│   ├── database_helper.dart
│   ├── export_service.dart
│   └── ...
├── widgets/                           # Reusable components
│   └── custom_widgets.dart
├── scripts/                           # Utility scripts
└── firebase_options.dart              # Firebase config

android/                               # Android native code
ios/                                   # iOS native code
assets/
└── images/                            # App assets and logo
```

### 🚀 Getting Started

#### Prerequisites
- Flutter SDK (3.10+)
- Dart SDK (3.10+)
- Android SDK or Xcode (for iOS)
- Firebase project configured

#### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/gasotorta.git
   cd gasotorta
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place files in appropriate directories

4. **Run the app**
   ```bash
   flutter run
   ```

5. **Build for release**
   ```bash
   flutter build apk      # Android
   flutter build ipa      # iOS
   ```

### 🎯 Use Cases

- Personal finance management for daily users
- Family expense tracking and sharing
- Freelancers tracking project expenses
- Small business owners managing costs
- Budget planning and financial analysis

### 📱 Screenshots

- Dashboard with expense summary
- Expense entry form (manual and voice)
- Credit card installment tracker
- Expense splitting interface
- Analytics and statistics view
- PDF export functionality

### 🔄 Workflow

1. **User Authentication:** Register/Login via Firebase
2. **Add Expense:** Enter expense manually or via voice
3. **Categorization:** Auto-categorize or manually assign category
4. **Payment Method:** Select cash or credit card
5. **Installments:** Configure installment details if applicable
6. **Sync:** Automatic cloud sync via Firebase
7. **Track & Analyze:** View statistics and patterns
8. **Export:** Generate and share reports

### 📈 Future Enhancements

- Multi-currency support
- Recurring expenses automation
- OCR for receipt scanning
- Budget recommendations engine
- Integration with banking APIs
- Mobile payment gateway integration
- Advanced analytics with machine learning

### 🤝 Contributing

This is a portfolio project. Feel free to fork and suggest improvements!

### 📄 License

This project is open source and available under the MIT License.

### 👨‍💻 Developer

Created as a portfolio project showcasing:
- Full-stack mobile development with Flutter
- Firebase integration and real-time synchronization
- Complex state management
- Advanced UI/UX design
- API integration and data handling

---

## 📱 Versión en Español

### Acerca de GastoTorta

GastoTorta es una aplicación integral de seguimiento de gastos construida con **Flutter** y **Firebase**. Diseñada para ayudar a los usuarios a gestionar sus finanzas personales de manera eficiente con características avanzadas para rastrear gastos, administrar cuotas de tarjetas de crédito y generar informes financieros perspicaces.

### ✨ Características Principales

#### 💰 **Gestión de Gastos**
- Registro rápido y fácil de gastos con múltiples métodos de entrada
- Soporte para transacciones en efectivo y tarjeta de crédito
- Entrada de gastos por voz usando reconocimiento de voz
- Categorización automática y etiquetado
- Búsqueda y filtrado de gastos por fecha, categoría y cantidad

#### 💳 **Cuotas de Tarjeta de Crédito**
- Rastrear compras de tarjeta de crédito en múltiples cuotas (1-60 meses)
- Visualizar cronograma de pagos de cuotas
- Marcar cuotas como pagadas/pendientes
- Rastrear obligaciones de crédito actuales y futuras
- Recordatorios de pago de cuotas

#### 👥 **División de Gastos**
- Dividir gastos entre múltiples personas
- Opciones de división flexible (iguales, montos personalizados, porcentajes)
- Rastrear quién debe a quién
- Generar reportes de liquidación
- Calcular deudas y créditos totales

#### 📊 **Análisis e Insights**
- Análisis de gastos impulsado por IA y patrones de gasto
- Gráficos visuales y estadísticas (gráficos circulares, gráficos de líneas, gráficos de barras)
- Tendencias de gasto mensual y anual
- Desglose de gastos por categoría
- Alertas de gastos y advertencias de presupuesto

#### 📤 **Exportación de Datos e Informes**
- Exportar datos a formato CSV
- Generar reportes en PDF con resúmenes detallados de gastos
- Reportes listos para imprimir
- Copia de seguridad y restauración de datos

#### 🎨 **Interfaz de Usuario**
- Soporte para temas claro y oscuro
- Navegación intuitiva con barra de pestañas inferior
- Diseño receptivo para todos los tamaños de pantalla
- Animaciones y transiciones suaves
- Cumplimiento de Material Design 3

#### 🔐 **Seguridad y Autenticación**
- Autenticación de Firebase (Email/Contraseña)
- Almacenamiento seguro de credenciales
- Gestión de sesiones
- Gestión de cuenta de usuario

#### ☁️ **Sincronización en la Nube**
- Sincronización en tiempo real con Firebase Firestore
- Sincronización entre dispositivos
- Enfoque sin conexión con cola de sincronización
- Copia de seguridad automática en la nube
- Resolución de conflictos

### 🛠️ Stack Tecnológico

**Frontend:**
- **Framework:** Flutter 3.10+
- **Lenguaje:** Dart
- **Gestión de Estado:** Provider
- **Componentes UI:** Material Design 3

**Backend y Servicios:**
- **Autenticación:** Firebase Authentication
- **Base de Datos:** Cloud Firestore
- **Lógica Backend:** Firebase Cloud Functions (lista)
- **Actualizaciones en Tiempo Real:** Firebase Realtime Database

**Almacenamiento Local:**
- **SQLite:** Base de datos local con sqflite
- **Almacenamiento Seguro:** Flutter Secure Storage para datos sensibles
- **Preferencias:** Shared Preferences

**Librerías Adicionales:**
- **Gráficos:** FL Chart para visualización de datos
- **Generación de PDF:** Librerías de Printing & PDF
- **Reconocimiento de Voz:** Speech to Text
- **Gestión de Archivos:** File Picker
- **Localización:** Intl (soporte en español)
- **HTTP:** Para llamadas a API

### 📁 Estructura del Proyecto

```
lib/
├── main.dart                          # Punto de entrada
├── models/                            # Modelos de datos
│   └── expense.dart, user.dart, etc.
├── screens/                           # Pantallas UI
│   ├── dashboard_screen.dart
│   ├── add_expense_screen.dart
│   ├── installments_payment_screen.dart
│   ├── expense_divider_screen.dart
│   ├── statistics_screen.dart
│   └── ...
├── services/                          # Lógica de negocio
│   ├── firebase_auth_service.dart
│   ├── firebase_sync_service.dart
│   ├── database_helper.dart
│   ├── export_service.dart
│   └── ...
├── widgets/                           # Componentes reutilizables
│   └── custom_widgets.dart
├── scripts/                           # Scripts de utilidad
└── firebase_options.dart              # Configuración de Firebase

android/                               # Código nativo Android
ios/                                   # Código nativo iOS
assets/
└── images/                            # Recursos y logo de la app
```

### 🚀 Comenzar

#### Requisitos Previos
- Flutter SDK (3.10+)
- Dart SDK (3.10+)
- SDK de Android o Xcode (para iOS)
- Proyecto de Firebase configurado

#### Instalación

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/tuusuario/gasotorta.git
   cd gasotorta
   ```

2. **Instalar dependencias**
   ```bash
   flutter pub get
   ```

3. **Configurar Firebase**
   - Crear un proyecto de Firebase
   - Descargar `google-services.json` (Android) y `GoogleService-Info.plist` (iOS)
   - Colocar archivos en directorios apropiados

4. **Ejecutar la aplicación**
   ```bash
   flutter run
   ```

5. **Compilar para lanzamiento**
   ```bash
   flutter build apk      # Android
   flutter build ipa      # iOS
   ```

### 🎯 Casos de Uso

- Gestión de finanzas personales para usuarios diarios
- Seguimiento y distribución de gastos familiares
- Freelancers rastreando gastos de proyectos
- Dueños de pequeños negocios gestionando costos
- Planificación de presupuesto y análisis financiero

### 📱 Capturas de Pantalla

- Panel de control con resumen de gastos
- Formulario de entrada de gastos (manual y por voz)
- Rastreador de cuotas de tarjeta de crédito
- Interfaz de división de gastos
- Vista de análisis y estadísticas
- Funcionalidad de exportación a PDF

### 🔄 Flujo de Trabajo

1. **Autenticación de Usuario:** Registrarse/Iniciar sesión vía Firebase
2. **Agregar Gasto:** Ingresar gasto manualmente o por voz
3. **Categorización:** Categorizar automáticamente o asignar manualmente
4. **Método de Pago:** Seleccionar efectivo o tarjeta de crédito
5. **Cuotas:** Configurar detalles de cuotas si aplica
6. **Sincronización:** Sincronización automática en la nube vía Firebase
7. **Seguimiento y Análisis:** Ver estadísticas y patrones
8. **Exportación:** Generar y compartir reportes

### 📈 Mejoras Futuras

- Soporte para múltiples monedas
- Automatización de gastos recurrentes
- OCR para escaneo de recibos
- Motor de recomendaciones de presupuesto
- Integración con APIs bancarias
- Integración de pasarelas de pago móvil
- Análisis avanzado con aprendizaje automático

### 🤝 Contribuir

Este es un proyecto de cartera. ¡Siéntete libre de hacer un fork y sugerir mejoras!

### 📄 Licencia

Este proyecto es de código abierto y está disponible bajo la Licencia MIT.

### 👨‍💻 Desarrollador

Creado como un proyecto de cartera que demuestra:
- Desarrollo móvil full-stack con Flutter
- Integración de Firebase y sincronización en tiempo real
- Gestión compleja del estado
- Diseño UI/UX avanzado
- Integración de API y manejo de datos

---

## 📊 Project Statistics

- **Language:** Dart
- **Lines of Code:** 10,000+
- **Total Features:** 15+
- **Supported Platforms:** Android, iOS
- **Development Time:** 3+ months
- **Firebase Integration:** Full-featured

---

**Last Updated:** December 2025
**Status:** Active Development

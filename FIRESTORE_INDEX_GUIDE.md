# Firestore Índices Requeridos 📊

## Problema
El sync incremental requiere un índice compuesto en Firestore para consultas que filtran por `user_id` y ordenan por `last_updated`.

## Error que aparece:
```
The query requires an index. You can create it here:
https://console.firebase.google.com/v1/r/project/fluttergastos-7b824/firestore/indexes
```

## Solución

### 1. Crear el índice automáticamente 
**Usa el enlace que aparece en el error** - Firebase detecta automáticamente qué índice necesitas.

### 2. Crear el índice manualmente
Si el enlace no funciona, ve a:
1. [Firebase Console](https://console.firebase.google.com)
2. Selecciona proyecto **fluttergastos-7b824**
3. Ve a **Firestore Database** → **Indexes** → **Composite**
4. Clic en **Create Index**
5. Configuración:
   - **Collection ID**: `expenses`
   - **Fields**:
     - `user_id` → Ascending
     - `last_updated` → Ascending
     - `__name__` → Ascending (se agrega automáticamente)

### 3. Tiempo de creación
- Los índices pueden tardar **varios minutos** en crearse
- Mientras tanto, la app usará la **consulta fallback** (sin índice)
- Una vez creado el índice, automáticamente se optimizará el sync

### 4. Verificar estado del índice
En Firebase Console → Firestore → Indexes, verifica que aparezca:
- **Status**: `Enabled` ✅
- **Fields**: `user_id (ASC), last_updated (ASC), __name__ (ASC)`

## Comportamiento actual sin índice
✅ **La app seguirá funcionando** - el código tiene un fallback
✅ **Sync funciona** - solo que menos optimizado
✅ **No hay errores críticos** - solo advertencias en el log

## Una vez creado el índice
🚀 **Sync más rápido** - consultas optimizadas
📉 **Menos tráfico** - solo documentos recientes
🔥 **Mejor performance** - aprovecha índices nativos de Firestore
# 🔄 Sistema de Sincronización de Credenciales

## 📋 Descripción General

Este sistema mantiene sincronizadas las contraseñas entre dos colecciones de Firestore:
- **`administradores`**: Almacena contraseñas hasheadas (SHA256) para autenticación
- **`credenciales`**: Almacena contraseñas en texto plano para visualización en el panel de super usuario

## 🏗️ Arquitectura

### Colecciones de Firestore

#### 1. **administradores**
```json
{
  "email": "admin.ventura@fortguards.com",
  "passwordHash": "936dbe14b022ace5b0ecac211c3f6d301e347d678ace42...",
  "condominio": "Ventura",
  "nombre": "Administrador de Ventura",
  "createdAt": "2025-08-06T...",
  "fechaActualizacion": "2025-10-19T...",
  "ultimoCambioContrasena": "2025-10-19T..."
}
```

#### 2. **credenciales**
```json
{
  "condominio": "Ventura",
  "email": "admin.ventura@fortguards.com",
  "nombre": "Administrador de Ventura",
  "password": "leonardo123",
  "tipo": "administrador",
  "createdAt": "2025-08-06T...",
  "updatedAt": "2025-10-19T...",
  "updatedBy": "uid_del_admin"
}
```

#### 3. **credenciales/{id}/historial** (Subcollection)
```json
{
  "accion": "password_update",
  "by": "uid_del_admin",
  "at": "2025-10-19T...",
  "detalle": "Contraseña actualizada"
}
```

## 🔧 Componentes del Sistema

### 1. **CredentialsSyncService**
Servicio dedicado a la sincronización de credenciales.

**Ubicación**: `lib/services/credentials_sync_service.dart`

**Métodos principales**:

#### `updateAdminPasswordAndSyncCredentials()`
Sincroniza la contraseña del administrador en la colección `credenciales`.

```dart
await CredentialsSyncService().updateAdminPasswordAndSyncCredentials(
  condominio: 'Ventura',
  email: 'admin.ventura@fortguards.com',
  newPassword: 'nuevaContraseña123',
  adminUid: currentUser.uid,
);
```

**Parámetros**:
- `condominio`: Nombre del condominio (ej. "Ventura")
- `email`: Email del administrador
- `newPassword`: Nueva contraseña en texto plano
- `adminUid`: UID del admin que realiza el cambio (para auditoría)
- `createIfMissing`: Si es `true`, crea la credencial si no existe (default: true)

**Comportamiento**:
1. Busca credenciales con query compuesta: `tipo == 'administrador' && email == email && condominio == condominio`
2. Si encuentra documentos: los actualiza con la nueva contraseña
3. Si NO encuentra y `createIfMissing == true`: crea un nuevo documento
4. Registra cada cambio en la subcollection `historial`
5. Ejecuta todas las operaciones en un WriteBatch (atómico)

#### `existsCredentialForAdmin()`
Verifica si existe una credencial para el administrador.

```dart
final exists = await CredentialsSyncService().existsCredentialForAdmin(
  condominio: 'Ventura',
  email: 'admin.ventura@fortguards.com',
);
```

#### `getCredentialHistory()`
Obtiene el historial de cambios de una credencial.

```dart
final history = await CredentialsSyncService().getCredentialHistory(
  credentialId: 'jZnq6bH3CygWbfguk9OU',
  limit: 10,
);
```

### 2. **ConfiguracionService.cambiarContrasena()**
Método actualizado que integra la sincronización automática.

**Ubicación**: `lib/services/configuracion_service.dart`

**Flujo de ejecución**:
1. ✅ Valida contraseña actual (compara hash SHA256)
2. ✅ Actualiza contraseña en colección `administradores` (hasheada)
3. 🔄 **Sincroniza automáticamente** con colección `credenciales` (texto plano)
4. ✅ Retorna éxito/fracaso

```dart
final exito = await ConfiguracionService.cambiarContrasena(
  contrasenaActual: 'contraseñaActual',
  nuevaContrasena: 'nuevaContraseña123',
);
```

**Nota importante**: La sincronización es **no bloqueante**. Si falla, se registra un warning pero no falla toda la operación (la contraseña en `administradores` ya se actualizó correctamente).

## 🔐 Seguridad

### Hashing de Contraseñas
- **administradores**: Contraseñas hasheadas con SHA256
- **credenciales**: Contraseñas en texto plano (requerimiento del sistema para visualización)

### Auditoría
Cada cambio de contraseña se registra en:
- `credenciales/{id}/historial`: Subcollection con historial completo
- Campos: `accion`, `by` (UID), `at` (timestamp), `detalle`

### Índice Compuesto Requerido
La query de sincronización requiere un índice compuesto en Firestore:

**Collection**: `credenciales`  
**Fields**: 
- `tipo` (Ascending)
- `email` (Ascending)
- `condominio` (Ascending)

**Crear índice**:
1. Firebase Console → Firestore → Indexes
2. O seguir el link que Firestore proporciona en el error

## 📱 Experiencia de Usuario

### Pantalla de Configuración
**Ubicación**: `lib/screens/admin/configuracion_screen.dart`

**Flujo UX**:
1. Usuario ingresa contraseña actual y nueva contraseña
2. Botón "Cambiar" muestra loading (CircularProgressIndicator)
3. Sistema actualiza contraseña en `administradores`
4. Sistema sincroniza automáticamente con `credenciales`
5. SnackBar de confirmación: "✅ Contraseña actualizada y credenciales sincronizadas"

**Estados visuales**:
- **Loading**: Botón deshabilitado con spinner
- **Success**: SnackBar verde con ícono de check
- **Error**: SnackBar rojo con ícono de error

## 🔄 Flujo Completo

```
┌─────────────────────────────────────────────────────────────┐
│  1. Usuario cambia contraseña en ConfiguracionScreen        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  2. ConfiguracionService.cambiarContrasena()                │
│     - Valida contraseña actual (hash SHA256)                │
│     - Actualiza 'administradores' (passwordHash)            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  3. CredentialsSyncService.updateAdminPasswordAndSync...()  │
│     - Busca en 'credenciales' (query compuesta)             │
│     - Actualiza password (texto plano)                      │
│     - Registra en historial                                 │
│     - Commit WriteBatch (atómico)                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│  4. UI muestra confirmación                                 │
│     ✅ "Contraseña actualizada y credenciales sincronizadas"│
└─────────────────────────────────────────────────────────────┘
```

## 🧪 Testing

### Casos de Prueba

#### 1. **Cambio de contraseña exitoso**
```dart
// Dado: Admin con credencial existente
// Cuando: Cambia su contraseña
// Entonces: 
//   - passwordHash actualizado en 'administradores'
//   - password actualizado en 'credenciales'
//   - Entrada creada en historial
```

#### 2. **Credencial no existe**
```dart
// Dado: Admin sin credencial en 'credenciales'
// Cuando: Cambia su contraseña
// Entonces: 
//   - passwordHash actualizado en 'administradores'
//   - Nueva credencial creada en 'credenciales'
//   - Entrada creada en historial
```

#### 3. **Error de sincronización**
```dart
// Dado: Error de red durante sincronización
// Cuando: Cambia su contraseña
// Entonces: 
//   - passwordHash actualizado en 'administradores' (OK)
//   - Warning logged pero no falla operación
//   - Usuario puede reintentar sincronización
```

#### 4. **Índice compuesto faltante**
```dart
// Dado: Índice compuesto no creado
// Cuando: Intenta sincronizar
// Entonces: 
//   - Exception con mensaje claro sobre crear índice
//   - Link o instrucciones para crear índice
```

## 📊 Monitoreo y Logs

### Logs del Sistema
El sistema usa `print()` con emojis para facilitar debugging:

```
🔄 Sincronizando credencial para: admin.ventura@fortguards.com en Ventura
📊 Documentos encontrados: 1
🔄 Actualizando 1 credencial(es)...
✅ Actualizada credencial: jZnq6bH3CygWbfguk9OU
✅ Sincronización completada: 1 operación(es)
```

### Errores Comunes

#### Error: Índice compuesto faltante
```
❌ Error Firebase al sincronizar: failed-precondition
Se requiere crear un índice compuesto en Firestore.
Collection: credenciales
Fields: tipo (Asc), email (Asc), condominio (Asc)
```

**Solución**: Crear índice en Firebase Console o seguir link del error.

#### Warning: Datos faltantes
```
⚠️ Advertencia: Faltan datos para sincronizar (email: null, condominio: Ventura)
```

**Solución**: Verificar que el documento en `administradores` tenga campos `email` y `condominio`.

## 🚀 Despliegue

### Checklist Pre-Producción

- [ ] Índice compuesto creado en Firestore
- [ ] Todos los admins tienen campo `email` y `condominio`
- [ ] Credenciales existentes migradas (si aplica)
- [ ] Tests de integración pasados
- [ ] Logs de producción configurados
- [ ] Monitoreo de errores activo

### Migración de Datos (si necesario)

Si tienes administradores existentes sin credenciales:

```dart
// Script de migración (ejecutar una vez)
final admins = await FirebaseFirestore.instance
    .collection('administradores')
    .get();

for (final admin in admins.docs) {
  final data = admin.data();
  await CredentialsSyncService().updateAdminPasswordAndSyncCredentials(
    condominio: data['condominio'],
    email: data['email'],
    newPassword: 'contraseñaTemporal123', // Cambiar después
    adminUid: 'SYSTEM_MIGRATION',
    createIfMissing: true,
  );
}
```

## 📚 Referencias

- **Firebase WriteBatch**: https://firebase.google.com/docs/firestore/manage-data/transactions#batched-writes
- **Índices Compuestos**: https://firebase.google.com/docs/firestore/query-data/indexing
- **Material Design 3**: https://m3.material.io/

## 🤝 Contribución

Al modificar este sistema:
1. NO modificar la lógica de `administradores` (ya está correcta)
2. Mantener sincronización no bloqueante
3. Registrar todos los cambios en historial
4. Actualizar esta documentación

---

**Última actualización**: 19 de octubre de 2025  
**Versión**: 1.0.0  
**Autor**: Sistema FortGuard Admin

# 🏠 Sistema de Gestión de Propietarios

## 📋 Descripción General

Sistema completo y profesional que permite al administrador ver, gestionar y cambiar las contraseñas de los propietarios de las casas en el condominio. Diseño minimalista, funcional y con todas las características necesarias para una gestión profesional.

---

## 🎯 Características Principales

### ✅ **Visualización de Información del Propietario**
- Información general: Casa, propietario, condominio
- Datos de contacto: Email, teléfono (si disponibles)
- Contraseña actual visible/oculta con toggle
- Interfaz limpia y minimalista

### ✅ **Cambio de Contraseña Seguro**
- Validación de nueva contraseña (mínimo 4 caracteres)
- Confirmación de contraseña
- Sincronización automática en múltiples colecciones
- Historial de cambios para auditoría
- Feedback visual claro (loading, éxito, error)

### ✅ **Historial de Cambios**
- Registro completo de cambios de contraseña
- Información de quién realizó el cambio (admin UID)
- Timestamps precisos
- Últimos 5 cambios mostrados

### ✅ **Diseño Profesional**
- Material Design 3 minimalista
- Secciones organizadas con iconos
- Responsive en móviles y tablets
- Modo oscuro/claro automático
- Sombras sutiles para profundidad

---

## 🔧 Componentes Técnicos

### **1. PropietarioService** (`lib/services/propietario_service.dart`)

Servicio completo para gestionar propietarios.

#### **Métodos Principales:**

**`obtenerPropietario()`**
```dart
final propietario = await PropietarioService.obtenerPropietario(
  condominio: 'Ventura',
  casa: '101',
);
```
- Obtiene datos completos del propietario
- Consulta colección `credenciales` con query compuesta
- Retorna Map con todos los datos

**`cambiarPasswordPropietario()`**
```dart
final exito = await PropietarioService.cambiarPasswordPropietario(
  condominio: 'Ventura',
  casa: '101',
  nuevaPassword: 'nuevaContraseña123',
  adminUid: currentUser.uid,
);
```
- Cambia contraseña en `credenciales`
- Actualiza también en `casas` (si existe)
- Registra en historial
- Usa WriteBatch para atomicidad
- Retorna bool (éxito/fracaso)

**`obtenerHistorialPropietario()`**
```dart
final historial = await PropietarioService.obtenerHistorialPropietario(
  condominio: 'Ventura',
  casa: '101',
);
```
- Obtiene últimos 5 cambios
- Ordenados por fecha (más recientes primero)
- Información completa de cada cambio

**`validarPassword()` y `obtenerErrorPassword()`**
```dart
if (!PropietarioService.validarPassword(password)) {
  final error = PropietarioService.obtenerErrorPassword(password);
  // Mostrar error
}
```
- Validación de requisitos mínimos
- Mensajes de error descriptivos

---

### **2. EditarPropietarioScreen** (`lib/screens/admin/editar_propietario_screen.dart`)

Pantalla profesional para gestionar propietarios.

#### **Estructura:**

**AppBar Compacto**
- Botón retroceso
- Título "Propietario"
- Fondo del tema

**Sección: Información General**
- Casa
- Propietario
- Condominio
- Email (si disponible)
- Teléfono (si disponible)

**Sección: Cambiar Contraseña**
- Contraseña actual (visible/oculta con toggle)
- Nueva contraseña (input)
- Confirmar contraseña (input)
- Botón "Guardar Cambios" con loading state

**Sección: Historial de Cambios**
- Lista de últimos cambios
- Fecha y hora
- Detalles de cada cambio

#### **Funcionalidades:**

```dart
// Cargar propietario al abrir
Future<void> _cargarPropietario() async {
  final data = await PropietarioService.obtenerPropietario(
    condominio: widget.condominio,
    casa: widget.casa,
  );
  setState(() => propietarioData = data ?? {});
}

// Cambiar contraseña
Future<void> _cambiarPassword() async {
  if (!_validarFormulario()) return;
  
  final exito = await PropietarioService.cambiarPasswordPropietario(
    condominio: widget.condominio,
    casa: widget.casa,
    nuevaPassword: passwordController.text.trim(),
    adminUid: currentUser.uid,
  );
  
  if (exito) {
    // Mostrar éxito
  } else {
    // Mostrar error
  }
}

// Validar formulario
bool _validarFormulario() {
  final nuevaPassword = passwordController.text.trim();
  final confirmPassword = confirmPasswordController.text.trim();
  
  if (nuevaPassword.isEmpty) return false;
  if (nuevaPassword.length < 4) return false;
  if (nuevaPassword != confirmPassword) return false;
  
  return true;
}
```

---

## 🔄 Flujo de Uso

### **Paso 1: Acceder desde Dashboard**
1. Admin ve lista de casas en dashboard
2. Toca el menú (⋮) de una casa
3. Selecciona "Editar propietario"

### **Paso 2: Ver Información**
1. Pantalla abre con información del propietario
2. Admin ve datos actuales
3. Puede ver contraseña actual (toggle)

### **Paso 3: Cambiar Contraseña**
1. Admin ingresa nueva contraseña
2. Confirma la contraseña
3. Toca "Guardar Cambios"
4. Sistema valida y actualiza
5. Muestra confirmación

### **Paso 4: Ver Historial**
1. Admin ve últimos cambios
2. Información de quién cambió y cuándo
3. Para auditoría y seguridad

---

## 📊 Estructura de Datos

### **Colección: `credenciales`**
```json
{
  "condominio": "Ventura",
  "email": "propietario@example.com",
  "nombre": "Propietario Nombre",
  "password": "nuevaContraseña123",
  "tipo": "propietario",
  "casa": "101",
  "telefono": "+58-2123456789",
  "cedula": "V-12345678",
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  "updatedBy": "uid_del_admin"
}
```

### **Subcollection: `credenciales/{id}/historial`**
```json
{
  "accion": "password_update",
  "by": "uid_del_admin",
  "at": Timestamp,
  "detalle": "Contraseña actualizada por administrador"
}
```

### **Colección: `condominios/{id}/casas`**
```json
{
  "numero": 101,
  "propietario": "Propietario Nombre",
  "password": "nuevaContraseña123",
  "residentes": ["Residente 1", "Residente 2"],
  "fechaActualizacion": Timestamp
}
```

---

## 🎨 Diseño UI/UX

### **Paleta de Colores**
```dart
- Fondo: colorScheme.surface
- Tarjetas: colorScheme.surfaceVariant.withOpacity(0.2)
- Texto principal: colorScheme.onSurface
- Texto secundario: colorScheme.onSurface.withOpacity(0.7)
- Primario: colorScheme.primary
- Éxito: Colors.green
- Error: Colors.red
```

### **Tipografía**
```dart
- AppBar title: titleMedium, w600
- Sección header: labelMedium, w600
- Labels: labelSmall, w600
- Valores: bodySmall, w500
- Monospace para contraseñas
```

### **Espaciado**
```dart
- Padding global: 16px
- Entre secciones: 20px
- Dentro de sección: 14px
- Entre campos: 12px
```

### **Bordes y Sombras**
```dart
- BorderRadius: 10-12px
- Sombra: alpha 0.05-0.08, blur 8px
- Inputs: borderRadius 10px
```

---

## 🔐 Seguridad

### **Validaciones**
- ✅ Contraseña mínimo 4 caracteres
- ✅ Confirmación de contraseña
- ✅ Sincronización en múltiples colecciones
- ✅ Auditoría completa con UID del admin

### **Sincronización**
- ✅ Actualiza `credenciales.password` (texto plano para UI)
- ✅ Actualiza `casas.password` (si existe)
- ✅ Registra en `historial` para auditoría
- ✅ WriteBatch para atomicidad

### **Auditoría**
- ✅ Quién cambió (adminUid)
- ✅ Cuándo cambió (timestamp)
- ✅ Qué cambió (detalles)
- ✅ Historial completo guardado

---

## 🚀 Integración en Dashboard

### **Menú Popup de Casa**
```dart
PopupMenuItem(
  value: 'propietario',
  child: Row(
    children: [
      Icon(Icons.person_outline_rounded, size: 20),
      SizedBox(width: 12),
      Text('Editar propietario'),
    ],
  ),
),
```

### **Navegación**
```dart
else if (value == 'propietario') {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => EditarPropietarioScreen(
      condominio: condominioId,
      casa: numero.toString(),
      propietarioNombre: propietario,
    ),
  ));
}
```

---

## 📱 Experiencia de Usuario

### **Estados Visuales**
- **Loading**: CircularProgressIndicator en botón
- **Éxito**: SnackBar verde con ícono check
- **Error**: SnackBar rojo con ícono error
- **Validación**: Mensajes de error claros

### **Feedback**
- ✅ Confirmación visual de cambios
- ✅ Mensajes descriptivos
- ✅ Duración 3 segundos en SnackBars
- ✅ Comportamiento floating

### **Accesibilidad**
- ✅ Contraste adecuado
- ✅ Tamaños táctiles mínimos 40x40px
- ✅ Iconos descriptivos
- ✅ Textos claros y concisos

---

## 🧪 Casos de Uso

### **Caso 1: Cambio de Contraseña Exitoso**
```
1. Admin abre pantalla de propietario
2. Ingresa nueva contraseña
3. Confirma contraseña
4. Toca "Guardar Cambios"
5. Sistema valida ✓
6. Actualiza en credenciales ✓
7. Actualiza en casas ✓
8. Registra en historial ✓
9. Muestra "✅ Contraseña actualizada exitosamente"
10. Historial se actualiza automáticamente
```

### **Caso 2: Validación Fallida**
```
1. Admin ingresa contraseña muy corta (< 4 caracteres)
2. Toca "Guardar Cambios"
3. Sistema valida ✗
4. Muestra "⚠️ La contraseña debe tener al menos 4 caracteres"
5. No permite guardar
```

### **Caso 3: Contraseñas No Coinciden**
```
1. Admin ingresa contraseña: "password123"
2. Confirma con: "password124"
3. Toca "Guardar Cambios"
4. Sistema valida ✗
5. Muestra "⚠️ Las contraseñas no coinciden"
6. No permite guardar
```

---

## 🔗 Relaciones con Otros Sistemas

### **Con Sistema de Credenciales**
- Sincroniza automáticamente
- Mantiene consistencia
- Auditoría completa

### **Con Dashboard**
- Acceso desde menú de casa
- Navegación fluida
- Integración seamless

### **Con Sistema de Autenticación**
- Propietarios usan contraseña en `credenciales`
- Admin puede cambiar contraseña
- Cambios reflejados inmediatamente

---

## 📚 Referencias

- **Firebase WriteBatch**: https://firebase.google.com/docs/firestore/manage-data/transactions#batched-writes
- **Material Design 3**: https://m3.material.io/
- **Flutter Best Practices**: https://flutter.dev/docs/development/best-practices

---

## 🎯 Resumen

El sistema de gestión de propietarios es:
- ✅ **Profesional**: Diseño minimalista y moderno
- ✅ **Funcional**: Todas las características necesarias
- ✅ **Seguro**: Validaciones y auditoría completa
- ✅ **Integrado**: Funciona perfectamente con el dashboard
- ✅ **Escalable**: Fácil de extender con nuevas funcionalidades
- ✅ **Listo para Producción**: Código limpio y optimizado

**Última actualización**: 20 de octubre de 2025  
**Versión**: 1.0.0  
**Estado**: ✅ COMPLETADO Y FUNCIONAL

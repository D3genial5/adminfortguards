# Escaneo QR - Sistema FortGuards

## Cambios Implementados

### 1. Parser Robusto de QR (`qr_parser_service.dart`)

Se implementó un parser que acepta múltiples formatos de QR:

#### Formatos Soportados:
- **Formato FortGuardsApp** (actual): `CONDO:xxx|CASA:yyy|CODIGO:zzz`
- **Formato Legacy**: `CONDO:xxx|CASA:yyy` (sin código)
- **Formato JSON**: `{"type":"fg_pass","condominio":"xxx","casa":123,"codigo":"456","hmac":"..."}`
- **Formato URL**: `fortguards://pass?condominio=xxx&casa=123&codigo=456`
- **Formato Compacto**: `FG:condominio:casa:codigo`

### 2. Validación Contra Firestore

El servicio `QrScanService` ahora:
- Parsea el QR con tolerancia a múltiples formatos
- Lee datos de Firestore: `/condominios/{id}/casas/{num}`
- Valida código de casa contra `codigoCasa`
- Verifica expiración (`codigoExpira`)
- Verifica usos disponibles (`codigoUsos`)
- Carga residentes y datos del propietario

### 3. Cooldown en Escáner

Se agregó cooldown de **1.5 segundos** entre escaneos para evitar lecturas duplicadas.

### 4. UI Mejorada

- **Indicador de estado**: Verde (vigente), Rojo (inválido), Ámbar (expirado/sin usos)
- **Información completa**: Condominio, casa, residentes, estado de expensa
- **Botones de acción**: Permitir/Denegar con motivos
- **Registro automático**: Cada acceso se registra en Firestore

## Flujo End-to-End

1. **Propietario genera QR** (fortguardsapp)
   - Pantalla "Mi QR" o "QR Casa"
   - QR contiene: condominio + casa + código de 3 dígitos

2. **Guardia escanea QR** (admin_fortguards)
   - Pantalla "Escanear QR"
   - Parser detecta formato y extrae datos

3. **Validación**
   - Lee datos de Firestore
   - Valida código, expiración, usos
   - Muestra UI con información completa

4. **Decisión del Guardia**
   - **Permitir**: Registra acceso con timestamp
   - **Denegar**: Registra denegación con motivo

5. **Registro en Firestore**
   - Colección: `access_requests` o `registros`
   - Datos: guardId, guardName, resultado, timestamp

## Archivos Modificados

### admin_fortguards:
- `lib/services/qr_parser_service.dart` (NUEVO)
- `lib/services/qr_scan_service.dart` (ACTUALIZADO)
- `lib/screens/seguridad/scan_qr_screen_new.dart` (COOLDOWN)

### fortguardsapp:
- `lib/screens/visita/qr_casa_screen.dart` (FORMATO QR CON CODIGO)

## Cómo Probar

### Test 1: QR Básico (sin código)
1. En fortguardsapp: ir a una casa sin código
2. Generar QR
3. En admin_fortguards: escanear
4. **Esperado**: Muestra casa y condominio, permite acceso

### Test 2: QR con Código Válido
1. En fortguardsapp: ir a "PROPIETARIO"
2. Ver código de 3 dígitos en panel
3. Generar QR de casa
4. En admin_fortguards: escanear
5. **Esperado**: Valida código, muestra residentes, permite acceso

### Test 3: Código Expirado
1. En Firestore: ajustar `codigoExpira` a fecha pasada
2. Generar y escanear QR
3. **Esperado**: Estado "expirado", UI ámbar, no permite acceso

### Test 4: Sin Usos
1. En Firestore: ajustar `codigoUsos` = 0
2. Generar y escanear QR
3. **Esperado**: Estado "sin_usos", no permite acceso

### Test 5: Casa Inexistente
1. Crear QR manual: `CONDO:xxx|CASA:999`
2. Escanear
3. **Esperado**: "Casa no encontrada", no permite acceso

## Colecciones Firestore

### `/condominios/{id}/casas/{num}`
```
{
  "propietario": "Juan Pérez",
  "residentes": ["Juan Pérez", "María López"],
  "codigoCasa": "123",
  "codigoExpira": Timestamp,
  "codigoUsos": 10,
  "estadoExpensa": "al_dia" | "pendiente"
}
```

### `/access_requests` o `/registros`
```
{
  "guardId": "guard_123",
  "guardName": "Carlos Guardia",
  "condominioId": "Sky",
  "casaNumero": 5,
  "codigo": "123",
  "resultado": "aprobado" | "rechazado",
  "motivoError": "QR expirado" (si aplica),
  "observaciones": "Traía paquete",
  "createdAt": Timestamp
}
```

## Logs de Debug

Para depurar el escaneo, revisar logs en consola:
```
[QrScan] QR raw: CONDO:Sky|CASA:5|CODIGO:123
[QrScan] Validando QR: condo=Sky, casa=5, codigo=123
```

## Comandos Útiles

```bash
# Compilar admin_fortguards
cd d:\work\admin_fortguards
flutter run

# Compilar fortguardsapp
cd d:\work\fortguardsapp
flutter run

# Analizar errores
flutter analyze

# Ver dependencias
flutter pub deps | findstr mobile_scanner
```

## Pendientes / Mejoras Futuras

- [ ] Agregar firma HMAC para mayor seguridad
- [ ] Vibración diferenciada (éxito vs error)
- [ ] Beep sonoro al escanear
- [ ] Historial de escaneos en pantalla del guardia
- [ ] Notificación push al propietario cuando se usa su QR
- [ ] Modo offline: cachear datos de casas frecuentes

## Soporte

Para reportar problemas o sugerir mejoras, contactar al equipo de desarrollo.

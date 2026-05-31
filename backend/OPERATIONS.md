# Operaciones día a día — FortGuards

---

## Arquitectura de auth (resumen)

```
┌─────────────────┐   loginPropietario CF         ┌────────────────┐
│  fortguardsapp  │ ────────────────────────────▶ │  Cloud Func    │
│  (propietario)  │ ◀── Custom Token ───────────  │  + PBKDF2      │
└─────────────────┘                                └────────────────┘
        │                                                   │
        ▼                                                   ▼
┌─────────────────┐                                 ┌──────────────┐
│  Firebase Auth  │ ─── auth.token.role ─────────▶ │  Firestore   │
│  signInWithCT() │       .condominio                │  Rules       │
│                 │       .casaId                    │              │
└─────────────────┘                                 └──────────────┘

Admin & Guardia: signInWithEmailAndPassword + syncAdminClaims/syncGuardiaClaims
Visitante: signInAnonymously (todavía no integrado en cliente; usado por rules)
```

### Custom Claims

| Rol | Claims |
|---|---|
| Super Admin | `{role: 'superadmin', condominio: 'Todos'}` |
| Admin condo | `{role: 'admin', condominio: 'X'}` |
| Guardia | `{role: 'guardia', condominio: 'X', guardiaId: 'g_123'}` |
| Propietario | `{role: 'propietario', condominio: 'X', casaId: '1'}` |

Los claims se setean automáticamente por triggers Firestore. Para forzar
refresh desde la app: llamar a la function `refreshMyClaims` o cerrar
sesión + login.

---

## Tareas frecuentes

### Resetear password de un propietario

```javascript
// Desde firebase functions:shell con super-admin auth
const result = await resetPropietarioPassword({
  condominio: 'Sky',
  casaId: '1',
});
console.log('Nueva password:', result.newPassword);
// Esta password se muestra UNA SOLA VEZ. Entregársela al propietario por canal seguro.
```

### Rotar el secret de QR de un condominio

```javascript
// Útil si sospechas que el secret se filtró (ej: app vieja sin actualizar)
await rotateQrSecret({condominio: 'Sky'});
// ⚠️ Esto invalida TODOS los QR vigentes del condominio. Los usuarios deben
// regenerar los suyos.
```

### Crear un super-admin nuevo

Solo desde Firebase Console o CLI (ver DEPLOY.md sección 3).

### Migrar credenciales legacy

El re-hash a PBKDF2 ocurre **automáticamente en el siguiente login** de cada
usuario. No requiere acción.

Si quieres forzarlo (ej: para invalidar el hash SHA-256 viejo de inmediato):

```javascript
// Para cada casa con legacy passwordHash + passwordSalt:
await resetPropietarioPassword({condominio, casaId});
// → genera nueva password aleatoria + PBKDF2; hay que notificar al propietario.
```

---

## Monitoreo

### Logs en tiempo real

```bash
firebase functions:log --project=prod --only loginPropietario
firebase functions:log --project=prod --only verifyQrPayload
```

### Crashlytics

https://console.firebase.google.com/project/fortguard-9bba5/crashlytics

Filtros sugeridos:
- **App > FortGuards / FortGuards Admin**
- **Time range > Last 24h**

### Rate-limit hits

Si un login propietario falla muchas veces, queda registrado en
`_rate_limits/prop_{condo}_{casa}`. La function `limpiarRateLimits` corre
cada 24h limpiando entradas viejas. Para liberar manualmente:

```bash
# Borrar el doc específico desde Firestore Console
```

---

## Métricas clave (DAU / errores)

```javascript
// En Firebase Console → Analytics → Events:
// - 'app_open' → uso diario
// - 'login_success' / 'login_failed' → salud del auth
// - 'qr_scanned' / 'qr_rejected' → uso del módulo guardia
```

---

## Backup y recuperación

### Backup manual

```bash
gcloud firestore export gs://fortguard-9bba5.appspot.com/backups/$(date +%Y%m%d) \
  --project=fortguard-9bba5
```

### Backup programado

En Firebase Console → Firestore → Backups → habilitar **daily backup** con
retención 7 días (incluido en plan Blaze).

### Restaurar

```bash
gcloud firestore import gs://fortguard-9bba5.appspot.com/backups/20260520 \
  --project=fortguard-9bba5
```

---

## Costos a vigilar (plan Blaze)

| Concepto | Free tier | Costo extra |
|---|---|---|
| Firestore reads | 50k/día | $0.06 / 100k |
| Firestore writes | 20k/día | $0.18 / 100k |
| Functions invocations | 2M/mes | $0.40 / millón |
| Functions compute | 400k GB-sec | $0.0025 / GB-sec |
| Auth verifications | ilimitado | gratis |
| FCM | ilimitado | gratis |
| Storage | 5 GB | $0.026 / GB |

Para una operación de ~10 condominios × 50 casas → estimado **$5–15 USD/mes**.
Setear budget alert en https://console.cloud.google.com/billing/budgets

---

## Auth del Custom Token — caducidad

Los Custom Tokens emitidos por `loginPropietario` duran **1 hora**. La app
debe refrescar la sesión automáticamente (Firebase SDK lo hace solo). Si
ves errores 401 frecuentes, verificá que el cliente esté haciendo
`signInWithCustomToken` recientemente.

---

## Soporte para usuarios finales (FAQ)

**Q: Propietario no puede loguear, dice "Credenciales inválidas".**
A: Verificar que el condominio/casa esté bien escrito. Si está claro,
   usar `resetPropietarioPassword` y enviarle la nueva.

**Q: Guardia escanea un QR válido y dice "Firma inválida".**
A: El secret HMAC del condominio cambió. El propietario debe regenerar su
   QR (cierra sesión y vuelve a entrar al panel).

**Q: Notificación push no llega.**
A: Verificar token FCM en `condominios/{c}/casas/{casa}.fcmToken`. Si es
   null, el dispositivo no completó el `getToken()`. Pedir al usuario que
   abra la app y dé permiso de notificaciones.

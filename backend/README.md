# FortGuards — Suite

Plataforma de control de acceso para condominios. Dos apps Android +
backend serverless en Firebase.

| Componente | Tecnología | Carpeta |
|---|---|---|
| App propietarios/visitantes | Flutter | `fortguardsapp/` |
| App admin/guardia | Flutter | `admin_fortguards/` |
| Backend | Cloud Functions TypeScript | `functions/` |
| Base de datos | Cloud Firestore | reglas en `firestore.rules` |
| Auth | Firebase Auth + Custom Claims | reglas en `firestore.rules` |
| Storage | Cloud Storage | reglas en `storage.rules` |
| Notificaciones | Firebase Cloud Messaging | trigger en `functions/src/notifications.ts` |

## Documentación

- **[HANDOVER.md](HANDOVER.md)** — Traspaso del proyecto a un nuevo dueño.
- **[DEPLOY.md](DEPLOY.md)** — Cómo desplegar de cero.
- **[OPERATIONS.md](OPERATIONS.md)** — Operación diaria, troubleshooting,
  costos.

## Quick start (desarrollo local con emulador)

```bash
# 1. Levantar todo el stack Firebase localmente
cd D:\work
firebase emulators:start

# 2. (En otra terminal) sembrar data de prueba
cd functions
npm run seed-emulator

# 3. (En otra terminal) correr una app contra el emulador
cd ../fortguardsapp
flutter run --dart-define=USE_EMULATOR=true -d <device-id>
```

UI del emulador: http://localhost:4000

### Credenciales de demo (sólo emulador)

| Rol | Login |
|---|---|
| Propietario | condominio `Sky` · casa `1` · password `demo1` |
| Admin | `admin.sky@fortguards.com` / `admin123` |
| Super Admin | `super@fortguards.com` / `super123` |
| Guardia | `guardia.sky@fortguards.com` / `guardia123` |

## Verificación

```bash
# Lints + análisis estático
cd fortguardsapp && flutter analyze
cd ../admin_fortguards && flutter analyze
cd ../functions && npx tsc --noEmit

# Tests
cd fortguardsapp && flutter test
cd ../admin_fortguards && flutter test
cd ../functions && npm test
```

## Estructura de seguridad (resumen)

- **Firestore rules** con custom claims granulares por rol y condominio.
- **HMAC secret** de QR vive en `condominios_secrets/{id}` (denegado al
  cliente), accesible sólo desde Cloud Functions vía Admin SDK.
- **Passwords** propietarios: PBKDF2-SHA512 con 210k iteraciones
  (OWASP 2023). Hash legacy SHA-256 se migra automáticamente al primer
  login post-deploy.
- **QR signing** y **QR verifying** ocurre 100% server-side via Cloud
  Functions HTTPS callable. El cliente solo embebe la firma resultante.
- **Rate-limit** en login (5 intentos / 5min por casa).
- **Android hardening**: `allowBackup=false`, `usesCleartextTraffic=false`,
  Network Security Config + Data Extraction Rules, ProGuard activo en
  release.

## Soporte

Issues conocidos y troubleshooting: [OPERATIONS.md](OPERATIONS.md).

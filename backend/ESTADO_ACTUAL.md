# FortGuards — Estado actual y próximos pasos

_Última actualización: 2026-06-01_

## Qué está hecho (rama `feat/v2-base` en ambos repos, pusheada a GitHub)

- **Backend v2** integrado en `admin_fortguards/backend/`:
  - `functions/` (auth + claims, HMAC server-side, notificaciones, scheduled) — `tsc` OK, **15/15 tests**.
  - `firestore.rules` endurecidas (custom claims + `condominios_secrets`), `storage.rules`, `indexes`.
  - Emulador: las **18 functions cargan** (`loginPropietario`, `signQrPayload`, …).
- **Apps migradas a v2** (Firebase Auth + Cloud Functions):
  - `flutter analyze` = **No issues found** en ambas.
  - **Build APK debug OK** en ambas (`app-debug.apk`).
- **Limpieza**: eliminadas 5 pantallas de escaneo muertas + `reportes_expensas_screen_temp`.

## QA realizado
- ✅ Build + unit (backend tests, ambas apps compilan y buildean, functions cargan).
- ⏳ Funcional en runtime (login real, QR, entrada/salida, push): **pendiente** — hacer en
  device tras desplegar functions, o con emulador en una máquina con **JDK 21**
  (JDK 17 actual da `NullPointerException` en el rules-runtime del emulador Firestore).

## Próximos pasos (orden)

### 1. Cuenta / proyecto Firebase de producción  _(acción del dueño)_
- Decidir: transferir ownership de `fortguard-9bba5` a la cuenta de la empresa
  (Opción A de `HANDOVER.md`, conserva data) **o** crear proyecto nuevo (Opción B).
- Actualizar `backend/.firebaserc` con alias `prod` = projectId real.

### 2. Package definitivo de las apps  _(handover)_
- Hoy `applicationId = com.example.fortguardsapp` / `com.example.admin_fortguards`
  (registrados en el proyecto dev).
- Registrar el package real en Firebase y regenerar `google-services.json` /
  `GoogleService-Info.plist` con `flutterfire configure`.

### 3. Migrar secretos y rotar credenciales  _(ver DEPLOY.md §2-3, HANDOVER.md §3)_
- `migrateQrSecretsFromCondominios()` → mueve `qrSecret` a `condominios_secrets`.
- Crear el primer super-admin (custom claim a mano, DEPLOY.md §3).
- Rotar passwords de propietarios (`resetPropietarioPassword`) y `qrSecret`
  (`rotateQrSecret`) antes de entregar.

### 4. Deploy backend  _(DEPLOY.md §4)_
```
cd admin_fortguards/backend
firebase deploy --only functions --project prod
firebase deploy --only firestore:rules,firestore:indexes,storage:rules --project prod
```

### 5. Release apps
- **Android**: generar keystore nuevo (`.jks`), `key.properties`, `flutter build appbundle --release`.
- **iOS**: cuenta Apple Developer, certificado APNs → Firebase, capability Push,
  firma, `flutter build ipa`, TestFlight.

### 6. QA funcional end-to-end en device real
- Login propietario, generar/escanear QR, entrada/salida, push al propietario.

## Pendientes técnicos menores (no bloquean)
- Fusionar `notificacion_service` (in-app) y `notification_service` (FCM) — ambos en uso, refactor opcional.
- Firma HMAC en cliente aún presente en código legacy de las apps; v2 la mueve a
  `qr.ts` (server-side) — verificar que las apps usen `qr_secure_service`/`qr_verify_service` en todos los flujos.
- `copia_Nueva/` y `_backend_from_copia/` (carpetas temporales en `D:\work`): ya
  integradas; eliminar tras confirmar QA funcional.

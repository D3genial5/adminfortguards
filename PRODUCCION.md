# FortGuards — Runbook de salida a producción

_Actualizado: junio 2026. Complementa `backend/HANDOVER.md` y `backend/DEPLOY.md`._

## 0. Qué ya está hecho (en `feat/v2-base`)

| Ítem | Estado |
|---|---|
| Refactor casas con nombre de texto (String en apps + backend) | ✅ |
| Índices Firestore en `firestore.indexes.json` | ✅ (falta deploy) |
| Reglas Firestore endurecidas (rol + condominio, sin `isAuth()` laxo) | ✅ (falta deploy) |
| Topics FCM saneados (`fcmTopic`/`safeTopic`) | ✅ |
| Packages de producción `com.fortguards.app` / `com.fortguards.admin` | ✅ |
| Keystores de firma + `key.properties` (locales, NO en git) | ✅ |
| Backend compila, 15/15 tests | ✅ |

⚠️ **Las apps NO compilan hasta el paso 2** (el `google-services.json` actual
es del package viejo en el proyecto dev).

---

## 1. Crear el proyecto Firebase de producción (cuenta de la empresa)

**Dónde:** https://console.firebase.google.com con la cuenta Google de la empresa.

1. *Agregar proyecto* → nombre sugerido `fortguards-prod`. Desactiva Analytics si no lo usan.
2. **Plan Blaze** (requerido por Cloud Functions): Configuración → Uso y facturación → Modificar plan. Asociar tarjeta de la empresa.
3. **Authentication** → Comenzar → habilitar **Email/Password** y **Anónimo**.
4. **Firestore Database** → Crear base de datos → producción → región `us-central1` (debe coincidir con las functions).
5. **Storage** → Comenzar → misma región.

## 2. Registrar las apps y regenerar configuración

**Dónde:** terminal en tu PC, logueado con la cuenta de la empresa.

```powershell
npm i -g firebase-tools
dart pub global activate flutterfire_cli
firebase login   # cuenta de la EMPRESA

cd D:\work\fortguardsapp
flutterfire configure --project=fortguards-prod `
  --platforms=android,ios `
  --android-package-name=com.fortguards.app `
  --ios-bundle-id=com.fortguards.app

cd D:\work\admin_fortguards
flutterfire configure --project=fortguards-prod `
  --platforms=android,ios `
  --android-package-name=com.fortguards.admin `
  --ios-bundle-id=com.fortguards.admin
```

Esto regenera `google-services.json`, `GoogleService-Info.plist` y
`firebase_options.dart`. Verifica que compile: `flutter build apk --debug`.

## 3. Desplegar el backend al proyecto de producción

**Dónde:** `D:\work\admin_fortguards\backend`.

```powershell
firebase use --add        # elige fortguards-prod, alias "prod"
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

Notas:
- `maxInstances=1` global ya está configurado (cuota CPU 20/región). Si el deploy
  de las 20 funciones falla por cuota, despliega en 2 tandas con
  `--only functions:fn1,functions:fn2,...`.
- **IAM para login de propietarios** (`createCustomToken`):
  ```powershell
  gcloud projects add-iam-policy-binding fortguards-prod `
    --member="serviceAccount:fortguards-prod@appspot.gserviceaccount.com" `
    --role="roles/iam.serviceAccountTokenCreator"
  ```
  (o Console → IAM → cuenta `...@appspot.gserviceaccount.com` → agregar rol
  *Creador de tokens de cuentas de servicio*).

## 4. Crear el super-admin y datos iniciales

1. Console → Authentication → Agregar usuario: email del admin de la empresa + contraseña fuerte.
2. Console → Firestore → colección `administradores` → doc nuevo (ID = UID del usuario creado):
   `{ email: "<email>", nombre: "...", condominio: "Todos", role: "superadmin" }`
   → la función `syncAdminClaims` asigna los claims al guardarse.
3. Entrar a la app admin con ese usuario y **crear los condominios y casas reales**
   (no migrar los datos del proyecto dev: tienen `casaNumero` int legacy y datos de prueba).
4. Los `qrSecret` se generan solos en `condominios_secrets` al primer uso del QR.

## 5. QA end-to-end (OBLIGATORIO antes de publicar)

**Dónde:** dispositivo Android real (push no funciona en emulador), apps en modo release
(`flutter run --release`).

- [ ] Login super-admin, crear condominio + casas (incluir una con nombre de texto, ej. "Acacia 21")
- [ ] Crear guardia → muestra credenciales → login del guardia
- [ ] Reset de contraseña de propietario (centro de credenciales) → login propietario
- [ ] Propietario: generar QR de invitado → guardia escanea → entrada/salida registrada
- [ ] Invitados: solicitar acceso, propietario acepta/rechaza/revoca
- [ ] Reservas de áreas comunes (crear, aprobar, cancelar)
- [ ] Expensas: marcar pagada (admin) + registrar pago (propietario)
- [ ] Notificaciones: admin → todo el condominio y a casa específica; llega el **push**
- [ ] Alerta de pánico del propietario → la ve el guardia
- [ ] **Vigilar `permission-denied`**: las reglas nuevas son estrictas; cualquier denegado
      inesperado se corrige en `backend/firestore.rules` y se redespliega
- [ ] QRs viejos no valen (cambió el tipo de `h` en el payload): regenerar

## 6. App Check (recomendado, post-QA)

Console → App Check → registrar ambas apps Android con **Play Integrity** (e iOS con
**App Attest**). Empezar en modo *monitoreo* (sin enforcement) y activar enforcement en
Firestore/Functions cuando las métricas estén limpias.

## 7. Android — Play Store

**Keystores ya generados** (NO están en git):
- `D:\work\fortguardsapp\android\upload-keystore.jks` + `android\key.properties`
- `D:\work\admin_fortguards\android\upload-keystore.jks` + `android\key.properties`

🔐 **RESPALDA ya** los 2 `.jks` y los 2 `key.properties` en un lugar seguro
(gestor de contraseñas / drive cifrado de la empresa). Si se pierden antes de
publicar, se pierde la identidad de firma.

```powershell
cd D:\work\fortguardsapp;    flutter build appbundle --release
cd D:\work\admin_fortguards; flutter build appbundle --release
# salida: build\app\outputs\bundle\release\app-release.aab
```

**Play Console** (https://play.google.com/console, cuenta de la empresa, USD 25 una vez):
1. Crear app ×2 (FortGuards / FortGuards Admin). Acepta **Play App Signing** (Google
   guarda la clave final; tu `.jks` queda como upload key — recuperable si se pierde).
2. Subir el `.aab` a **Prueba interna** primero; agregar testers; validar.
3. Completar: clasificación de contenido, **política de privacidad** (URL obligatoria,
   la app pide cámara y envía datos personales), declaración de seguridad de datos.
4. Promover a producción. Revisión de Google: horas a días.
5. La app admin puede ser *privada* (Managed Play / lista de testers) si no quieren
   que aparezca pública.

## 8. iOS — App Store

**Requisitos:** Mac con Xcode + cuenta **Apple Developer** de la empresa (USD 99/año).

1. developer.apple.com → Identifiers → registrar `com.fortguards.app` y
   `com.fortguards.admin` con capability **Push Notifications**.
2. Keys → crear **APNs Auth Key** (.p8) → subirla en Firebase Console → Configuración
   del proyecto → Cloud Messaging → configuración de apps Apple (para AMBAS apps).
3. En el Mac: clonar repos, `flutter pub get`, abrir `ios/Runner.xcworkspace` en Xcode →
   Signing & Capabilities → Team de la empresa → agregar capabilities
   **Push Notifications** y **Background Modes → Remote notifications**.
4. `flutter build ipa --release` → subir con Transporter/Xcode → **TestFlight** → QA → enviar a revisión.

## 9. Post-lanzamiento / deuda conocida

- Fusionar `notificacion_service` y `notification_service` (duplicados, ambos en uso).
- Borrar `D:\work\copia_Nueva\` y `D:\work\_backend_from_copia\` (ya integradas).
- El proyecto dev `fortguard-9bba5` queda como entorno de pruebas; no mezclar datos.
- Mergear `feat/v2-base` → `main` en ambos repos cuando el QA pase.

# FortGuards — Traspaso a empresa

Este documento detalla todo lo necesario para que el nuevo propietario reciba
y opere las aplicaciones **FortGuards** (propietarios) y **FortGuards Admin**
(administradores / guardias).

---

## 1. Inventario de archivos

Todo el código y configuración vive en `D:\work` (renombrar a gusto). El
repositorio se compone de:

```
D:\work\
├── fortguardsapp/              ← App propietarios/visitantes (Flutter Android)
├── admin_fortguards/           ← App administradores/guardias (Flutter Android)
├── functions/                  ← Cloud Functions TypeScript
│   ├── src/
│   │   ├── auth.ts             ← Login propietario + PBKDF2
│   │   ├── qr.ts               ← Firma/verificación HMAC de QR
│   │   ├── notifications.ts    ← Triggers FCM
│   │   ├── scheduled.ts        ← Tareas programadas (auto-regenerar códigos)
│   │   ├── index.ts            ← Re-exporta todo
│   │   └── __tests__/          ← Tests unitarios
│   ├── scripts/
│   │   └── seed_emulator.ts    ← Carga data de prueba al emulador
│   ├── package.json
│   └── tsconfig.json
├── firestore.rules             ← Reglas Firestore (production-grade)
├── firestore.indexes.json      ← Índices Firestore
├── storage.rules               ← Reglas Cloud Storage
├── firebase.json               ← Config Firebase + emulator suite
├── .firebaserc                 ← Alias del projectId
├── HANDOVER.md                 ← Este archivo
├── DEPLOY.md                   ← Runbook de deploy
└── OPERATIONS.md               ← Operación día a día
```

### Archivos sensibles que NO deben entregarse por canal público

| Archivo | Riesgo | Acción |
|---|---|---|
| `fortguardsapp/android/key.properties` | Password del keystore | Entregar por canal cifrado (1Password, Bitwarden, GPG) |
| `admin_fortguards/android/key.properties` | Idem | Idem |
| `*.jks` / `*.keystore` | Clave de firma APK | Idem |
| `contraseñas/usuarios_fortguards.txt` | Credenciales planas legacy | Rotar TODAS antes de entregar; el archivo no debe llegar al nuevo dueño |
| `serviceAccount.json` (si existe) | Admin SDK key | No reusar — el nuevo dueño genera la suya |

### Archivos públicos OK

`google-services.json`, `firebase_options.dart`, `GoogleService-Info.plist` —
contienen la API key web/Android/iOS que es **pública por diseño** (Firebase
las marca así). La seguridad la dan las Firestore Rules + Custom Claims.

---

## 2. Transferencia del proyecto Firebase

El proyecto actual es **`fortguard-9bba5`** en plan **Blaze (pay-as-you-go)**.

### 2.1 Opción A — Transferir ownership (recomendada)

Ventajas: data, Auth users, FCM tokens, configuración → todo se mantiene.

**Pasos del dueño actual (vos):**

1. Abrir `https://console.cloud.google.com/iam-admin/iam?project=fortguard-9bba5`
2. Click **"Grant Access"** → agregar el email del nuevo dueño con rol
   **Owner**.
3. Esperar a que el nuevo dueño acepte (recibe email).
4. Una vez confirmado, **cambiar la cuenta de facturación**:
   `https://console.cloud.google.com/billing/linkedaccount?project=fortguard-9bba5`
   → "Change billing" → vincular la billing account de la empresa.
5. Cuando el nuevo billing esté activo, **quitar tu rol Owner** dejando solo
   el del nuevo dueño (opcional pero recomendado).

**Pasos del nuevo dueño:**

1. Aceptar la invitación de IAM (email).
2. Asociar billing account propio (Blaze).
3. Verificar acceso a https://console.firebase.google.com/project/fortguard-9bba5
4. Ir a *Configuración del proyecto → Cuentas de servicio* y descargar una
   nueva clave (`serviceAccount.json`) para CI/CD propio.

### 2.2 Opción B — Crear proyecto Firebase nuevo

Más limpia pero requiere migrar data manualmente. Solo recomendable si la
empresa tiene políticas que prohíben heredar proyectos.

```bash
# 1. Empresa crea proyecto fortguards-prod
firebase projects:create fortguards-prod

# 2. Agregar apps Android (nuevo applicationId si quieren)
flutterfire configure --project=fortguards-prod
# Esto regenera firebase_options.dart + google-services.json

# 3. Exportar data del proyecto viejo
gcloud auth login
gcloud config set project fortguard-9bba5
gcloud firestore export gs://fortguard-9bba5.appspot.com/backups/snapshot1

# 4. Importar al proyecto nuevo
gcloud config set project fortguards-prod
gcloud firestore import gs://fortguard-9bba5.appspot.com/backups/snapshot1

# 5. Auth users no se transfieren directamente — el nuevo dueño debe
#    forzar password reset por email a todos los usuarios.
```

---

## 3. Antes de entregar — checklist obligatorio

- [ ] Rotar **TODAS** las passwords de propietarios mediante
      `resetPropietarioPassword` (Cloud Function).
- [ ] Rotar el `qrSecret` de TODOS los condominios con `rotateQrSecret`.
- [ ] Borrar `contraseñas/usuarios_fortguards.txt` del disco del nuevo dueño.
- [ ] Generar **nuevo** keystore Android (`.jks`) y subir el público a Play
      Console del nuevo owner. El viejo se descarta.
- [ ] Revocar cualquier service account propio que hayas creado para CI.
- [ ] Bajar tus tokens de Crashlytics/Analytics si compartiste alguno.
- [ ] Verificar que tu email no quede en `administradores/` con rol
      superadmin (sólo el nuevo equipo).

---

## 4. Soporte primer mes

Recomendación: ofrecer 2–4 semanas de soporte post-traspaso para resolver
dudas. Mantenete con rol *Viewer* (no Owner) en el proyecto Firebase y con
acceso al repositorio si hace falta.

---

Continúa en [DEPLOY.md](DEPLOY.md) y [OPERATIONS.md](OPERATIONS.md).

# Deploy runbook — FortGuards

Para el **nuevo dueño**: cómo pasar de "recibo el repo" a producción
funcionando.

---

## 0. Pre-requisitos

```bash
# Versions exactas que usamos en desarrollo
node --version          # v20.x
npm --version           # 10.x
flutter --version       # 3.27+
firebase --version      # 14.x
java -version           # 21+ (sólo para emulador Firestore)
```

Instalar:

```bash
npm install -g firebase-tools
# Flutter: https://docs.flutter.dev/get-started/install
```

Login:

```bash
firebase login
gcloud auth login
```

---

## 1. Setup del proyecto (una sola vez)

```bash
cd D:\work

# Vincular el repo con el projectId real
firebase use fortguard-9bba5 --alias prod
# (o el nuevo projectId si crearon uno)

# Functions
cd functions
npm ci
npm run build
cd ..

# Apps
cd fortguardsapp && flutter pub get && cd ..
cd admin_fortguards && flutter pub get && cd ..
```

---

## 2. Migración inicial (sólo si vienen de Firebase del dueño anterior)

Si reciben el proyecto Firebase ya migrado y poblado de data legacy:

```bash
firebase deploy --only functions --project=prod

# Con super-admin auth en el cliente:
firebase functions:shell --project=prod
> migrateQrSecretsFromCondominios()   # mueve qrSecret a colección segura
```

Esto extrae los `qrSecret` que aún están en `condominios/{id}.qrSecret` y
los mueve a `condominios_secrets/{id}.hmacKey` (colección denegada al
cliente). Una vez ejecutado, **eliminar el campo `qrSecret`** de los docs
legacy si quedó alguno.

---

## 3. Otorgar rol Super Admin a un humano

Cada admin/guardia recibe su rol vía custom claim sincronizado por las
funciones `syncAdminClaims` / `syncGuardiaClaims`. **El primer super-admin
hay que crearlo a mano** (huevo y la gallina):

```bash
# Opción A — vía Firebase Console
# 1. Authentication → Users → click sobre el usuario → "..." → Add custom claim
# 2. JSON: {"role":"superadmin","condominio":"Todos"}

# Opción B — vía CLI
firebase functions:shell --project=prod
> const admin = require('firebase-admin');
> await admin.auth().setCustomUserClaims('UID_DEL_USUARIO', {
    role: 'superadmin',
    condominio: 'Todos'
  })
```

El usuario debe **cerrar sesión y volver a entrar** para que el token
incorpore el claim.

---

## 4. Deploy completo

```bash
cd D:\work

# 1. Cloud Functions (debe ir primero — las rules las necesitan)
firebase deploy --only functions --project=prod

# 2. Firestore rules + indexes
firebase deploy --only firestore:rules,firestore:indexes --project=prod

# 3. Storage rules
firebase deploy --only storage:rules --project=prod

# 4. Apps Android — release con signing real
cd fortguardsapp
flutter build appbundle --release    # .aab para Play Store
flutter build apk --release          # .apk para distribución directa
cd ..

cd admin_fortguards
flutter build appbundle --release
flutter build apk --release
cd ..
```

Los artefactos quedan en:

- `fortguardsapp/build/app/outputs/bundle/release/app-release.aab`
- `fortguardsapp/build/app/outputs/flutter-apk/app-release.apk`
- Idem para `admin_fortguards`.

### 4.1 Signing config

Cada app necesita `android/key.properties` con:

```properties
storePassword=...
keyPassword=...
keyAlias=...
storeFile=../release.jks
```

Y el `release.jks` correspondiente. **NO commiteales**. El `.gitignore` ya
los excluye.

Para generar uno nuevo:

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias fortguards
```

---

## 5. CI/CD recomendado

Crear `.github/workflows/deploy-functions.yml`:

```yaml
name: Deploy Functions
on:
  push:
    branches: [main]
    paths:
      - 'functions/**'
      - 'firestore.rules'
      - 'storage.rules'
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
          cache-dependency-path: functions/package-lock.json
      - run: cd functions && npm ci && npm run build && npm test
      - uses: w9jds/firebase-action@master
        with:
          args: deploy --only functions,firestore:rules,firestore:indexes,storage:rules
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
          PROJECT_ID: fortguard-9bba5
```

Generar `FIREBASE_TOKEN`:

```bash
firebase login:ci
```

Y guardarlo en GitHub Secrets.

---

## 6. Rollback

```bash
# Functions — volver a versión anterior
firebase functions:list --project=prod
# Identificar la function, luego en Console: Functions → seleccionar → Versions → "Rollback"

# Firestore rules — git revert + redeploy
git revert <commit>
firebase deploy --only firestore:rules --project=prod

# Apps — Play Console permite "Halt rollout" en Production track
```

---

## 7. Verificación post-deploy

```bash
# Smoke test de las funciones
curl -X POST https://us-central1-fortguard-9bba5.cloudfunctions.net/loginPropietario \
  -H "Content-Type: application/json" \
  -d '{"data":{"condominio":"FAKE","casaId":"1","password":"wrong"}}'

# Debería devolver {"error":{"status":"NOT_FOUND",...}}
```

```bash
# Logs en vivo
firebase functions:log --project=prod --only loginPropietario
```

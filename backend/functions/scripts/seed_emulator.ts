// =============================================================================
// seed_emulator.ts — Carga data de prueba al Firebase Emulator
// =============================================================================
// Uso (con el emulador corriendo):
//   FIRESTORE_EMULATOR_HOST=localhost:8080 \
//   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
//   npx ts-node --transpile-only scripts/seed_emulator.ts
//
// O en una sola línea desde la raíz del proyecto:
//   npm --prefix functions run seed-emulator
// =============================================================================
import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import * as crypto from "crypto";

// Forzar uso de emulador
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "localhost:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? "localhost:9099";

const PROJECT_ID = process.env.GCLOUD_PROJECT ?? "fortguard-9bba5";
if (getApps().length === 0) {
  initializeApp({ projectId: PROJECT_ID });
}
const db = getFirestore();
const auth = getAuth();

// PBKDF2 helpers (mismos que auth.ts)
function pbkdf2(password: string, saltB64: string): string {
  return crypto.pbkdf2Sync(
    password, Buffer.from(saltB64, "base64"), 210_000, 32, "sha512",
  ).toString("base64");
}
function newSalt(): string {
  return crypto.randomBytes(16).toString("base64");
}
function encodePhc(salt: string, hash: string): string {
  return `pbkdf2$sha512$210000$${salt}$${hash}`;
}

async function seedCondominio(condoId: string, casas: Array<{
  numero: number;
  propietario: string;
  password: string;
}>) {
  console.log(`==> Sembrando ${condoId} con ${casas.length} casas`);
  await db.collection("condominios").doc(condoId).set({
    nombre: condoId,
    createdAt: FieldValue.serverTimestamp(),
  });

  // qrSecret en colección segura aparte
  await db.collection("condominios_secrets").doc(condoId).set({
    hmacKey: crypto.randomBytes(32).toString("base64"),
    createdAt: FieldValue.serverTimestamp(),
  });

  for (const casa of casas) {
    const salt = newSalt();
    const hash = pbkdf2(casa.password, salt);
    await db.collection("condominios").doc(condoId).collection("casas")
      .doc(casa.numero.toString()).set({
        numero: casa.numero,
        propietario: casa.propietario,
        residentes: [casa.propietario],
        estadoExpensa: "pagada",
        passwordHash: encodePhc(salt, hash),
        codigoCasa: Math.floor(100 + Math.random() * 900).toString(),
        codigoUsos: 10,
        codigoExpira: new Date(Date.now() + 24 * 3600 * 1000),
      });
    console.log(`   Casa ${casa.numero}: ${casa.propietario} (pwd: ${casa.password})`);
  }
}

async function seedAdmin(email: string, password: string, condominio: string) {
  try {
    const user = await auth.createUser({ email, password });
    await db.collection("administradores").doc(user.uid).set({
      email,
      nombre: "Admin Demo",
      condominio,
      createdAt: FieldValue.serverTimestamp(),
    });
    await auth.setCustomUserClaims(user.uid, {
      role: condominio === "Todos" ? "superadmin" : "admin",
      condominio,
    });
    console.log(`==> Admin: ${email} / ${password} (${condominio})`);
  } catch (e) {
    console.log(`==> Admin ya existe: ${email}`);
  }
}

async function seedGuardia(email: string, password: string, condominio: string) {
  try {
    const user = await auth.createUser({ email, password });
    const guardiaId = `g_${Date.now()}`;
    await db.collection("guardias").doc(guardiaId).set({
      nombre: "Guardia",
      apellido: "Demo",
      condominio,
      activo: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    await db.collection("guardias_auth").doc(user.uid).set({
      guardiaId,
      email,
      nombre: "Guardia",
      apellido: "Demo",
      condominio,
      createdAt: FieldValue.serverTimestamp(),
    });
    await auth.setCustomUserClaims(user.uid, {
      role: "guardia",
      condominio,
      guardiaId,
    });
    console.log(`==> Guardia: ${email} / ${password} (${condominio})`);
  } catch (e) {
    console.log(`==> Guardia ya existe: ${email}`);
  }
}

(async () => {
  console.log("=== SEED EMULATOR ===");
  console.log(`Firestore: ${process.env.FIRESTORE_EMULATOR_HOST}`);
  console.log(`Auth:      ${process.env.FIREBASE_AUTH_EMULATOR_HOST}`);
  console.log("");

  await seedCondominio("Sky", [
    { numero: 1, propietario: "Juan Pérez", password: "demo1" },
    { numero: 2, propietario: "María García", password: "demo2" },
    { numero: 3, propietario: "Carlos López", password: "demo3" },
  ]);

  await seedCondominio("Plaza", [
    { numero: 1, propietario: "Ana Torres", password: "demo1" },
    { numero: 2, propietario: "Luis Mendoza", password: "demo2" },
  ]);

  await seedAdmin("admin.sky@fortguards.com", "admin123", "Sky");
  await seedAdmin("admin.plaza@fortguards.com", "admin123", "Plaza");
  await seedAdmin("super@fortguards.com", "super123", "Todos");

  await seedGuardia("guardia.sky@fortguards.com", "guardia123", "Sky");
  await seedGuardia("guardia.plaza@fortguards.com", "guardia123", "Plaza");

  console.log("\n=== LISTO ===");
  console.log("Abrí http://localhost:4000 para ver el emulator UI");
  console.log("Login propietario: condominio=Sky / casa=1 / password=demo1");
  console.log("Login admin: admin.sky@fortguards.com / admin123");
  console.log("Login guardia: guardia.sky@fortguards.com / guardia123");
  process.exit(0);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});

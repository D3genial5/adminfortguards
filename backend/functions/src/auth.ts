// =============================================================================
// FortGuards - Auth Cloud Functions
// =============================================================================
// - loginPropietario       : valida password + emite Custom Token
// - changePropietarioPassword : cambia password validando la anterior
// - resetPropietarioPassword  : reset por admin (devuelve nueva pwd temporal)
// - syncAdminClaims        : Trigger Firestore → set custom claims a admin
// - syncGuardiaClaims      : Trigger Firestore → set custom claims a guardia
// =============================================================================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";

const db = () => getFirestore();
const auth = () => getAuth();

// -----------------------------------------------------------------------------
// PBKDF2 password hashing (OWASP 2023 recommendation)
// -----------------------------------------------------------------------------
const PBKDF2_ALGO = "sha512";
const PBKDF2_ITER = 210_000;
const PBKDF2_KEYLEN = 32;
const PBKDF2_SALTLEN = 16;

function pbkdf2Hash(password: string, saltB64: string): string {
  const salt = Buffer.from(saltB64, "base64");
  const derived = crypto.pbkdf2Sync(
    password,
    salt,
    PBKDF2_ITER,
    PBKDF2_KEYLEN,
    PBKDF2_ALGO,
  );
  return derived.toString("base64");
}

function newSalt(): string {
  return crypto.randomBytes(PBKDF2_SALTLEN).toString("base64");
}

/** Formato almacenado: `pbkdf2$sha512$210000$<salt_b64>$<hash_b64>` */
function encodePhc(salt: string, hash: string): string {
  return `pbkdf2$${PBKDF2_ALGO}$${PBKDF2_ITER}$${salt}$${hash}`;
}

function decodePhc(s: string): { salt: string; hash: string; iter: number } | null {
  const parts = s.split("$");
  if (parts.length !== 5 || parts[0] !== "pbkdf2") return null;
  return { salt: parts[3], hash: parts[4], iter: parseInt(parts[2], 10) };
}

/** Comparación constant-time */
function safeEqual(a: string, b: string): boolean {
  const aB = Buffer.from(a);
  const bB = Buffer.from(b);
  if (aB.length !== bB.length) return false;
  return crypto.timingSafeEqual(aB, bB);
}

/** Verificación legacy: SHA-256(salt:password) en hex */
function legacySha256(password: string, salt: string): string {
  return crypto.createHash("sha256").update(`${salt}:${password}`).digest("hex");
}

function generateTempPassword(len = 12): string {
  const chars = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let out = "";
  const bytes = crypto.randomBytes(len);
  for (let i = 0; i < len; i++) out += chars[bytes[i] % chars.length];
  return out;
}

// -----------------------------------------------------------------------------
// Rate limiting helper — bloquea por IP+casa tras N intentos fallidos
// -----------------------------------------------------------------------------
async function checkRateLimit(key: string, max = 5, windowSec = 300): Promise<void> {
  const ref = db().collection("_rate_limits").doc(key);
  const now = Date.now();
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() ?? {};
    const attempts: number[] = (data.attempts ?? []).filter(
      (t: number) => now - t < windowSec * 1000,
    );
    if (attempts.length >= max) {
      throw new HttpsError(
        "resource-exhausted",
        `Demasiados intentos. Espere ${Math.ceil(windowSec / 60)} minutos.`,
      );
    }
    attempts.push(now);
    tx.set(ref, { attempts }, { merge: true });
  });
}

async function clearRateLimit(key: string): Promise<void> {
  await db().collection("_rate_limits").doc(key).delete().catch(() => {});
}

// =============================================================================
// loginPropietario — emite Custom Token
// =============================================================================
export const loginPropietario = onCall(
  { region: "us-central1" },
  async (request) => {
    const { condominio, casaId, password } = request.data ?? {};
    if (
      typeof condominio !== "string" || !condominio.trim() ||
      typeof casaId !== "string" || !casaId.trim() ||
      typeof password !== "string" || !password
    ) {
      throw new HttpsError("invalid-argument", "Faltan datos de login");
    }

    const condoTrim = condominio.trim();
    const casaTrim = casaId.trim();
    const rateKey = `prop_${condoTrim}_${casaTrim}`;
    await checkRateLimit(rateKey);

    // 1. Buscar el condominio (case-insensitive como fallback)
    let condoDoc = await db().collection("condominios").doc(condoTrim).get();
    if (!condoDoc.exists) {
      const all = await db().collection("condominios").get();
      const match = all.docs.find(
        (d) =>
          d.id.toLowerCase() === condoTrim.toLowerCase() ||
          (d.data().nombre ?? "").toString().toLowerCase() === condoTrim.toLowerCase(),
      );
      if (!match) throw new HttpsError("not-found", "Condominio no encontrado");
      condoDoc = match;
    }
    const condoId = condoDoc.id;

    // 2. Buscar la casa
    let casaDoc = await db()
      .collection("condominios").doc(condoId)
      .collection("casas").doc(casaTrim).get();
    if (!casaDoc.exists) {
      const altId = parseInt(casaTrim, 10);
      if (!isNaN(altId)) {
        casaDoc = await db()
          .collection("condominios").doc(condoId)
          .collection("casas").doc(altId.toString()).get();
      }
    }
    if (!casaDoc.exists) throw new HttpsError("not-found", "Casa no encontrada");

    const casaData = casaDoc.data() ?? {};
    const stored = casaData.passwordHash as string | undefined;
    const legacySalt = casaData.passwordSalt as string | undefined;
    const plain = casaData.password as string | undefined;

    // 3. Verificar password (PBKDF2 → legacy SHA256 → plain)
    let ok = false;
    let needRehash = false;

    if (stored?.startsWith("pbkdf2$")) {
      const parsed = decodePhc(stored);
      if (parsed) {
        const got = pbkdf2Hash(password, parsed.salt);
        ok = safeEqual(got, parsed.hash);
        if (ok && parsed.iter !== PBKDF2_ITER) needRehash = true;
      }
    } else if (stored && legacySalt) {
      ok = safeEqual(legacySha256(password, legacySalt), stored);
      needRehash = ok;
    } else if (plain && plain === password) {
      ok = true;
      needRehash = true;
    }

    if (!ok) {
      throw new HttpsError("unauthenticated", "Credenciales inválidas");
    }

    // 4. Re-hash transparente si era legacy
    if (needRehash) {
      const salt = newSalt();
      const hash = pbkdf2Hash(password, salt);
      await casaDoc.ref.update({
        passwordHash: encodePhc(salt, hash),
        passwordSalt: FieldValue.delete(),
        password: FieldValue.delete(),
        passwordMigratedAt: FieldValue.serverTimestamp(),
      });
    }

    await clearRateLimit(rateKey);

    // 5. Crear/usar Firebase Auth user y emitir Custom Token
    const propietarioUid = `prop_${condoId}_${casaDoc.id}`;
    try {
      await auth().getUser(propietarioUid);
    } catch {
      // No existe → crear
      await auth().createUser({
        uid: propietarioUid,
        displayName: `Casa ${casaDoc.id} - ${condoId}`,
      });
    }

    const claims = {
      role: "propietario",
      condominio: condoId,
      casaId: casaDoc.id,
    };
    await auth().setCustomUserClaims(propietarioUid, claims);

    const customToken = await auth().createCustomToken(propietarioUid, claims);

    return {
      token: customToken,
      condominio: condoId,
      casaId: casaDoc.id,
      casaNumero: casaData.numero ?? parseInt(casaDoc.id, 10),
      propietario: casaData.propietario ?? "",
      residentes: casaData.residentes ?? [],
    };
  },
);

// =============================================================================
// changePropietarioPassword — cambiar password validando la actual
// =============================================================================
export const changePropietarioPassword = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    const claims = request.auth.token;
    if (claims.role !== "propietario") {
      throw new HttpsError("permission-denied", "Solo propietarios");
    }
    const { passwordActual, nuevaPassword } = request.data ?? {};
    if (
      typeof passwordActual !== "string" || !passwordActual ||
      typeof nuevaPassword !== "string" || nuevaPassword.length < 6
    ) {
      throw new HttpsError("invalid-argument", "Datos inválidos");
    }

    const casaRef = db()
      .collection("condominios").doc(claims.condominio as string)
      .collection("casas").doc(claims.casaId as string);
    const casaDoc = await casaRef.get();
    if (!casaDoc.exists) throw new HttpsError("not-found", "Casa no encontrada");

    const stored = casaDoc.data()?.passwordHash as string | undefined;
    if (!stored?.startsWith("pbkdf2$")) {
      throw new HttpsError("failed-precondition", "Migre primero la password");
    }
    const parsed = decodePhc(stored);
    if (!parsed) throw new HttpsError("internal", "Hash corrupto");

    if (!safeEqual(pbkdf2Hash(passwordActual, parsed.salt), parsed.hash)) {
      throw new HttpsError("unauthenticated", "Password actual incorrecta");
    }

    const salt = newSalt();
    const hash = pbkdf2Hash(nuevaPassword, salt);
    await casaRef.update({
      passwordHash: encodePhc(salt, hash),
      passwordChangedAt: FieldValue.serverTimestamp(),
    });
    return { success: true };
  },
);

// =============================================================================
// resetPropietarioPassword — Admin resetea password de una casa
// =============================================================================
export const resetPropietarioPassword = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    const claims = request.auth.token;
    const { condominio, casaId } = request.data ?? {};
    if (typeof condominio !== "string" || typeof casaId !== "string") {
      throw new HttpsError("invalid-argument", "Datos inválidos");
    }
    if (
      claims.role !== "superadmin" &&
      !(claims.role === "admin" && (claims.condominio === condominio || claims.condominio === "Todos"))
    ) {
      throw new HttpsError("permission-denied", "No autorizado");
    }

    const newPwd = generateTempPassword(10);
    const salt = newSalt();
    const hash = pbkdf2Hash(newPwd, salt);

    await db()
      .collection("condominios").doc(condominio)
      .collection("casas").doc(casaId)
      .update({
        passwordHash: encodePhc(salt, hash),
        passwordSalt: FieldValue.delete(),
        password: FieldValue.delete(),
        passwordResetAt: FieldValue.serverTimestamp(),
        passwordResetBy: request.auth.uid,
      });

    return { newPassword: newPwd };
  },
);

// =============================================================================
// syncAdminClaims — al crear/actualizar /administradores/{uid}, set claims
// =============================================================================
export const syncAdminClaims = onDocumentWritten(
  { document: "administradores/{uid}", region: "us-central1" },
  async (event) => {
    const uid = event.params.uid as string;
    const after = event.data?.after.data();
    if (!after) {
      // Borrado: limpiar claims
      try {
        await auth().setCustomUserClaims(uid, {});
      } catch {/* ignore */}
      return;
    }
    const condominio = (after.condominio as string | undefined) ?? "";
    const isSuper = condominio === "Todos";
    await auth().setCustomUserClaims(uid, {
      role: isSuper ? "superadmin" : "admin",
      condominio,
    });
  },
);

// =============================================================================
// syncGuardiaClaims — al crear/actualizar /guardias_auth/{uid}, set claims
// =============================================================================
export const syncGuardiaClaims = onDocumentWritten(
  { document: "guardias_auth/{uid}", region: "us-central1" },
  async (event) => {
    const uid = event.params.uid as string;
    const after = event.data?.after.data();
    if (!after) {
      try { await auth().setCustomUserClaims(uid, {}); } catch {/* ignore */}
      return;
    }
    const condominio = (after.condominio as string | undefined) ?? "";
    await auth().setCustomUserClaims(uid, {
      role: "guardia",
      condominio,
      guardiaId: after.guardiaId ?? "",
    });
  },
);

// =============================================================================
// Login admin/guardia — fuerza refresh de claims si el cliente los necesita
// =============================================================================
export const refreshMyClaims = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    const uid = request.auth.uid;
    // Comprueba en qué colección está y resetea claims
    const adminSnap = await db().collection("administradores").doc(uid).get();
    if (adminSnap.exists) {
      const condominio = adminSnap.data()?.condominio ?? "";
      const isSuper = condominio === "Todos";
      await auth().setCustomUserClaims(uid, {
        role: isSuper ? "superadmin" : "admin",
        condominio,
      });
      return { role: isSuper ? "superadmin" : "admin", condominio };
    }
    const guardiaSnap = await db().collection("guardias_auth").doc(uid).get();
    if (guardiaSnap.exists) {
      const condominio = guardiaSnap.data()?.condominio ?? "";
      await auth().setCustomUserClaims(uid, {
        role: "guardia",
        condominio,
        guardiaId: guardiaSnap.data()?.guardiaId ?? "",
      });
      return { role: "guardia", condominio };
    }
    throw new HttpsError("not-found", "Usuario sin rol asignado");
  },
);

// =============================================================================
// resetAuthUserPassword — superadmin resetea la password de un usuario de
// Firebase Auth (admin o guardia). Devuelve la nueva password temporal para
// mostrarla UNA vez. Acepta {uid} o {email}.
// =============================================================================
export const resetAuthUserPassword = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    if (request.auth.token.role !== "superadmin") {
      throw new HttpsError("permission-denied", "Solo super admin");
    }
    const { uid, email } = request.data ?? {};
    let targetUid: string | undefined =
      typeof uid === "string" && uid ? uid : undefined;
    if (!targetUid && typeof email === "string" && email) {
      try {
        const u = await auth().getUserByEmail(email);
        targetUid = u.uid;
      } catch {
        throw new HttpsError("not-found", "Usuario no encontrado por email");
      }
    }
    if (!targetUid) {
      throw new HttpsError("invalid-argument", "uid o email requerido");
    }
    const newPwd = generateTempPassword(10);
    await auth().updateUser(targetUid, { password: newPwd });
    return { newPassword: newPwd };
  },
);

// =============================================================================
// createStaffUser — crea un usuario de Firebase Auth (admin o guardia) vía
// Admin SDK SIN afectar la sesión del que llama, escribe su doc (lo que dispara
// syncAdminClaims/syncGuardiaClaims) y devuelve la password para mostrarla 1 vez.
// =============================================================================
export const createStaffUser = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    const caller = request.auth.token;
    const { email, password, role, condominio, nombre, guardiaId } =
      request.data ?? {};

    if (
      typeof email !== "string" || !email ||
      typeof role !== "string" ||
      typeof condominio !== "string" || !condominio
    ) {
      throw new HttpsError("invalid-argument", "Datos inválidos");
    }

    if (role === "admin") {
      if (caller.role !== "superadmin") {
        throw new HttpsError("permission-denied", "Solo super admin crea admins");
      }
    } else if (role === "guardia") {
      const ok =
        caller.role === "superadmin" ||
        (caller.role === "admin" &&
          (caller.condominio === condominio || caller.condominio === "Todos"));
      if (!ok) throw new HttpsError("permission-denied", "No autorizado");
    } else {
      throw new HttpsError("invalid-argument", "role inválido");
    }

    const pwd =
      typeof password === "string" && password.length >= 6
        ? password
        : generateTempPassword(10);

    // Crear o reusar el usuario de Firebase Auth (sin tocar la sesión del caller)
    let uid: string;
    try {
      const existing = await auth().getUserByEmail(email);
      uid = existing.uid;
      await auth().updateUser(uid, { password: pwd });
    } catch {
      const created = await auth().createUser({
        email,
        password: pwd,
        displayName: typeof nombre === "string" ? nombre : undefined,
      });
      uid = created.uid;
    }

    // Escribir el doc → dispara syncAdminClaims / syncGuardiaClaims (custom claims)
    if (role === "admin") {
      await db().collection("administradores").doc(uid).set(
        { condominio, email, nombre: nombre ?? email },
        { merge: true },
      );
    } else {
      await db().collection("guardias_auth").doc(uid).set(
        {
          condominio,
          email,
          nombre: nombre ?? "",
          guardiaId: guardiaId ?? "",
        },
        { merge: true },
      );
    }

    return { uid, email, password: pwd };
  },
);

// Re-exportar utilidades para que QR las use
export const _pbkdf2 = { pbkdf2Hash, newSalt, encodePhc, decodePhc, safeEqual };

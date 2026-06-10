// =============================================================================
// FortGuards - QR Cloud Functions
// =============================================================================
// - signQrPayload   : firma un payload con HMAC-SHA256 (secret server-side)
// - verifyQrPayload : verifica firma + estado en Firestore
// - rotateQrSecret  : rota el secret HMAC para un condominio (super/admin)
//
// El qrSecret JAMÁS sale al cliente; vive en /condominios_secrets/{condoId}
// con regla `allow read, write: if false;`.
// =============================================================================
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore, Timestamp, FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";

const db = () => getFirestore();

// -----------------------------------------------------------------------------
// Secret store
// -----------------------------------------------------------------------------
async function getOrCreateSecret(condoId: string): Promise<string> {
  const ref = db().collection("condominios_secrets").doc(condoId);
  const snap = await ref.get();
  if (snap.exists && snap.data()?.hmacKey) {
    return snap.data()!.hmacKey as string;
  }
  // Auto-provision
  const key = crypto.randomBytes(32).toString("base64");
  await ref.set({
    hmacKey: key,
    createdAt: FieldValue.serverTimestamp(),
    rotatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return key;
}

function canonicalize(obj: Record<string, unknown>): string {
  // JSON estable ordenando keys → garantiza misma serialización al firmar/verificar
  const keys = Object.keys(obj).filter((k) => k !== "sig").sort();
  const ordered: Record<string, unknown> = {};
  for (const k of keys) {
    if (obj[k] !== undefined && obj[k] !== null) ordered[k] = obj[k];
  }
  return JSON.stringify(ordered);
}

function hmacSign(payload: Record<string, unknown>, secret: string): string {
  const data = canonicalize(payload);
  return crypto.createHmac("sha256", Buffer.from(secret, "base64"))
    .update(data).digest("base64url");
}

function safeEqual(a: string, b: string): boolean {
  const aB = Buffer.from(a);
  const bB = Buffer.from(b);
  if (aB.length !== bB.length) return false;
  return crypto.timingSafeEqual(aB, bB);
}

function sha256Hex(s: string): string {
  return crypto.createHash("sha256").update(s).digest("hex");
}

// =============================================================================
// signQrPayload — firma QR de propietario o invitado
// =============================================================================
export const signQrPayload = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    const claims = request.auth.token;
    const {
      condominio,
      casaNumero,
      codigoCasa,
      tipo,             // 'propietario' | 'invitado'
      validityHours,    // number, default 12
      usosMaximos,      // number | null
      visitanteCi,      // string opcional
    } = request.data ?? {};

    // El identificador de casa puede ser numérico (21) o texto ("Acacia 21").
    if (
      typeof condominio !== "string" ||
      (typeof casaNumero !== "number" && typeof casaNumero !== "string") ||
      (typeof casaNumero === "string" && casaNumero.trim().length === 0) ||
      typeof codigoCasa !== "string"
    ) {
      throw new HttpsError("invalid-argument", "Datos inválidos");
    }
    const casaId = casaNumero.toString().trim();

    // Permisos: propietario de la casa, guardia del condo, o admin
    const ok =
      claims.role === "superadmin" ||
      (claims.role === "admin" && (claims.condominio === condominio || claims.condominio === "Todos")) ||
      (claims.role === "guardia" && claims.condominio === condominio) ||
      (claims.role === "propietario" &&
        claims.condominio === condominio &&
        claims.casaId === casaId);
    if (!ok) throw new HttpsError("permission-denied", "No autorizado para firmar");

    const now = Date.now();
    const hours = typeof validityHours === "number" && validityHours > 0 ? validityHours : 12;
    const exp = now + hours * 3600 * 1000;

    const payload: Record<string, unknown> = {
      c: condominio,
      h: casaId,
      k: codigoCasa,
      t: tipo === "invitado" ? "inv" : "prop",
      iat: now,
      exp,
    };
    if (typeof usosMaximos === "number") payload.u = usosMaximos;
    if (typeof visitanteCi === "string" && visitanteCi.length > 0) {
      // Hash del CI para no exponer PII en el QR
      payload.vci = sha256Hex(`${visitanteCi}:${condominio}`);
    }

    const secret = await getOrCreateSecret(condominio);
    const sig = hmacSign(payload, secret);
    payload.sig = sig;

    return { qr: payload };
  },
);

// =============================================================================
// verifyQrPayload — usado por la app del guardia para validar el QR
// =============================================================================
export const verifyQrPayload = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    const claims = request.auth.token;
    if (claims.role !== "guardia" && claims.role !== "admin" && claims.role !== "superadmin") {
      throw new HttpsError("permission-denied", "Solo personal de seguridad");
    }

    const raw = request.data?.qr;
    if (!raw || typeof raw !== "object") {
      throw new HttpsError("invalid-argument", "Payload inválido");
    }
    const payload = raw as Record<string, unknown>;
    const condominio = payload.c as string | undefined;
    const sig = payload.sig as string | undefined;
    if (!condominio || !sig) {
      return { valid: false, reason: "missing_fields" };
    }

    // Solo personal del mismo condo (o super) puede verificar
    if (
      claims.role !== "superadmin" &&
      claims.condominio !== condominio &&
      !(claims.role === "admin" && claims.condominio === "Todos")
    ) {
      return { valid: false, reason: "wrong_condominio" };
    }

    const secret = await getOrCreateSecret(condominio);
    const expected = hmacSign(payload, secret);
    if (!safeEqual(expected, sig)) {
      return { valid: false, reason: "bad_signature" };
    }

    const exp = payload.exp as number | undefined;
    if (typeof exp !== "number" || Date.now() > exp) {
      return { valid: false, reason: "expired" };
    }

    // h puede ser numérico (QRs antiguos) o texto ("Acacia 21").
    const casaNumero = String(payload.h ?? "");
    const codigoCasa = payload.k as string;
    if (!casaNumero) return { valid: false, reason: "missing_fields" };

    // Cross-check con Firestore
    const casaDoc = await db()
      .collection("condominios").doc(condominio)
      .collection("casas").doc(casaNumero).get();

    if (!casaDoc.exists) return { valid: false, reason: "casa_not_found" };
    const casa = casaDoc.data() ?? {};

    if (codigoCasa && casa.codigoCasa && casa.codigoCasa !== codigoCasa) {
      return { valid: false, reason: "code_mismatch" };
    }

    const usosFirestore = casa.codigoUsos as number | undefined;
    const usosPayload = payload.u as number | undefined;

    return {
      valid: true,
      tipo: payload.t,
      condominio,
      casaNumero,
      codigoCasa: casa.codigoCasa ?? codigoCasa,
      propietario: casa.propietario ?? "",
      residentes: casa.residentes ?? [],
      usosRestantes: usosPayload ?? usosFirestore ?? null,
      expiresAt: exp,
      visitanteCiHash: payload.vci ?? null,
    };
  },
);

// =============================================================================
// rotateQrSecret — admin del condo regenera el HMAC key (invalida todos los QR)
// =============================================================================
export const rotateQrSecret = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    const claims = request.auth.token;
    const { condominio } = request.data ?? {};
    if (typeof condominio !== "string") {
      throw new HttpsError("invalid-argument", "condominio requerido");
    }
    if (
      claims.role !== "superadmin" &&
      !(claims.role === "admin" && (claims.condominio === condominio || claims.condominio === "Todos"))
    ) {
      throw new HttpsError("permission-denied", "No autorizado");
    }
    const ref = db().collection("condominios_secrets").doc(condominio);
    const key = crypto.randomBytes(32).toString("base64");
    await ref.set({
      hmacKey: key,
      rotatedAt: FieldValue.serverTimestamp(),
      rotatedBy: request.auth.uid,
    }, { merge: true });
    return { success: true, rotatedAt: Timestamp.now().toMillis() };
  },
);

// =============================================================================
// migrateQrSecretsFromCondominios — One-time helper: mover qrSecret existente
// desde /condominios/{id}.qrSecret a /condominios_secrets/{id}.hmacKey
// =============================================================================
export const migrateQrSecretsFromCondominios = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "No autenticado");
    if (request.auth.token.role !== "superadmin") {
      throw new HttpsError("permission-denied", "Solo super admin");
    }
    const condos = await db().collection("condominios").get();
    let migrated = 0;
    for (const doc of condos.docs) {
      const data = doc.data();
      const legacy = data.qrSecret as string | undefined;
      if (legacy && legacy.length > 0) {
        await db().collection("condominios_secrets").doc(doc.id).set({
          hmacKey: Buffer.from(legacy).toString("base64"),
          migratedFromLegacy: true,
          createdAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        await doc.ref.update({ qrSecret: FieldValue.delete() });
        migrated++;
      }
    }
    return { migrated };
  },
);

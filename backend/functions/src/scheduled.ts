// =============================================================================
// FortGuards - Scheduled Cloud Functions
// =============================================================================
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import * as crypto from "crypto";

const db = () => getFirestore();

function generarCodigo(): string {
  // Código de 3 dígitos criptográficamente seguro
  const buf = crypto.randomBytes(2);
  const n = buf.readUInt16BE(0) % 900 + 100;
  return n.toString();
}

// =============================================================================
// autoRegenerarCodigos — cada 30 minutos
// =============================================================================
export const autoRegenerarCodigos = onSchedule(
  { schedule: "every 30 minutes", timeZone: "America/La_Paz", region: "us-central1" },
  async () => {
    const ahora = Timestamp.now();
    let regenerados = 0;

    try {
      const condominios = await db().collection("condominios").get();

      for (const condoDoc of condominios.docs) {
        const casas = await db()
          .collection("condominios").doc(condoDoc.id)
          .collection("casas").get();

        for (const casaDoc of casas.docs) {
          const data = casaDoc.data();
          const expira = data.codigoExpira as Timestamp | undefined;
          const usos = data.codigoUsos as number | undefined;

          const expirado = expira && ahora.toMillis() > expira.toMillis();
          const sinUsos = usos !== undefined && usos <= 0;

          if (expirado || sinUsos) {
            const duracion = data.duracionHoras || 24;
            const nuevosUsos = data.usosPreferidos || 10;

            await casaDoc.ref.update({
              codigoCasa: generarCodigo(),
              codigoExpira: Timestamp.fromMillis(ahora.toMillis() + duracion * 3600 * 1000),
              codigoUsos: nuevosUsos,
              ultimaRegeneracion: ahora,
              regeneracionAutomatica: true,
            });
            regenerados++;
          }
        }
      }
      console.log(`autoRegenerarCodigos: ${regenerados} regenerados`);
    } catch (error) {
      console.error("autoRegenerarCodigos error:", error);
    }
  },
);

// =============================================================================
// onCodigoAgotado — trigger cuando codigoUsos pasa de !=0 a 0
// =============================================================================
export const onCodigoAgotado = onDocumentUpdated(
  {
    document: "condominios/{condominioId}/casas/{casaNumero}",
    region: "us-central1",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const usosPrevios = before.codigoUsos as number | undefined;
    const usosNuevos = after.codigoUsos as number | undefined;

    if (usosPrevios !== 0 && usosNuevos === 0) {
      const duracion = after.duracionHoras || 24;
      const nuevosUsos = after.usosPreferidos || 10;
      const ahora = Timestamp.now();

      await event.data?.after.ref.update({
        codigoCasa: generarCodigo(),
        codigoExpira: Timestamp.fromMillis(ahora.toMillis() + duracion * 3600 * 1000),
        codigoUsos: nuevosUsos,
        ultimaRegeneracion: ahora,
        regeneracionPorTrigger: true,
      });
    }
  },
);

// =============================================================================
// limpiarQrsExpirados — cada 2 horas
// =============================================================================
export const limpiarQrsExpirados = onSchedule(
  { schedule: "0 */2 * * *", timeZone: "America/La_Paz", region: "us-central1" },
  async () => {
    const ahora = Timestamp.now();
    let expirados = 0;
    let sinUsos = 0;
    let eliminados = 0;

    try {
      const qrsExpirados = await db()
        .collection("qr_invitados")
        .where("estado", "==", "activo")
        .where("expira", "<=", ahora)
        .get();

      for (const doc of qrsExpirados.docs) {
        await doc.ref.update({ estado: "expirado", fechaExpiracion: ahora });
        expirados++;
      }

      const qrsSinUsos = await db()
        .collection("qr_invitados")
        .where("estado", "==", "activo")
        .where("usosRestantes", "<=", 0)
        .get();

      for (const doc of qrsSinUsos.docs) {
        await doc.ref.update({ estado: "sinUsos", fechaAgotamiento: ahora });
        sinUsos++;
      }

      const hace90Dias = Timestamp.fromDate(
        new Date(Date.now() - 90 * 24 * 3600 * 1000),
      );
      const qrsAntiguos = await db()
        .collection("qr_invitados")
        .where("estado", "in", ["expirado", "sinUsos", "revocado"])
        .where("creadoEn", "<=", hace90Dias)
        .limit(500)
        .get();

      for (const doc of qrsAntiguos.docs) {
        await doc.ref.delete();
        eliminados++;
      }

      console.log(`limpiarQrsExpirados: ${expirados} expirados, ${sinUsos} sin usos, ${eliminados} eliminados`);
    } catch (error) {
      console.error("limpiarQrsExpirados error:", error);
    }
  },
);

// =============================================================================
// limpiarRateLimits — limpia entradas de _rate_limits con +24h
// =============================================================================
export const limpiarRateLimits = onSchedule(
  { schedule: "every 24 hours", timeZone: "America/La_Paz", region: "us-central1" },
  async () => {
    const cutoff = Date.now() - 24 * 3600 * 1000;
    const snap = await db().collection("_rate_limits").get();
    let deleted = 0;
    for (const doc of snap.docs) {
      const attempts = (doc.data().attempts ?? []) as number[];
      const fresh = attempts.filter((t) => t > cutoff);
      if (fresh.length === 0) {
        await doc.ref.delete();
        deleted++;
      } else if (fresh.length !== attempts.length) {
        await doc.ref.update({ attempts: fresh });
      }
    }
    console.log(`limpiarRateLimits: ${deleted} eliminados`);
  },
);

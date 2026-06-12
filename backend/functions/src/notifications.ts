// =============================================================================
// FortGuards - Notifications Cloud Functions
// =============================================================================
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

const messaging = () => getMessaging();

// Los nombres de topic FCM solo admiten [a-zA-Z0-9-_.~%]. Condominio y casa
// pueden tener espacios u otros caracteres ("Acacia 21") — se reemplazan por
// "_". DEBE coincidir con fcmTopic() en las apps Flutter.
function safeTopic(raw: string): string {
  return raw.replace(/[^a-zA-Z0-9\-_.~%]/g, "_");
}

// =============================================================================
// onNotificacionCreada — push cuando admin crea notificación
// =============================================================================
export const onNotificacionCreada = onDocumentCreated(
  { document: "notificaciones/{notifId}", region: "us-central1" },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const condominio = data.condominio || data.condominioId;
    if (!condominio) return;

    try {
      const titulo = data.titulo || "Nueva notificación";
      const mensaje = data.mensaje || "";
      const prioridad = data.prioridad || "media";
      const tipo = data.tipo;
      const casaNumero = data.casaNumero;

      const topic = tipo === "condominio" || !casaNumero
        ? safeTopic(`condo_${condominio}`)
        : safeTopic(`prop_${condominio}_${casaNumero}`);

      const color = prioridad === "alta" || prioridad === "urgente" ? "#F44336" : "#2196F3";

      const response = await messaging().send({
        topic,
        notification: { title: titulo, body: mensaje },
        data: {
          type: "adminNotification",
          notifId: event.params.notifId,
          condominio,
          prioridad,
        },
        android: {
          priority: "high",
          notification: { channelId: "fortguards_channel", color, sound: "default" },
        },
        apns: {
          payload: {
            aps: {
              alert: { title: titulo, body: mensaje },
              badge: 1,
              sound: "default",
            },
          },
        },
      });

      await snapshot.ref.update({
        pushEnviado: true,
        pushFecha: FieldValue.serverTimestamp(),
        pushMessageId: response,
      });
    } catch (error) {
      console.error("onNotificacionCreada error:", error);
      await snapshot.ref.update({
        pushEnviado: false,
        pushError: String(error),
      });
    }
  },
);

// =============================================================================
// onLogCreate — notificar al propietario cuando guardia acepta entrada
// =============================================================================
export const onLogCreate = onDocumentCreated(
  { document: "logs_accesos/{logId}", region: "us-central1" },
  async (event) => {
    const data = event.data?.data();
    if (!data || data.resultado !== "aceptado") return;

    try {
      const fecha = data.fecha?.toDate() ?? new Date();
      const hora = fecha.toLocaleTimeString("es-BO", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });

      await messaging().send({
        topic: safeTopic(`prop_${data.condominio}_${data.casaNumero}`),
        notification: {
          title: "Visita en tu casa",
          body: `${data.invitadoNombre ?? "Visita"} ha ingresado a las ${hora}`,
        },
        data: {
          type: "visitorAccepted",
          visitorName: data.invitadoNombre || "",
          time: hora,
        },
        android: { priority: "high", notification: { channelId: "fortguards_channel" } },
      });
    } catch (error) {
      console.error("onLogCreate error:", error);
    }
  },
);

// =============================================================================
// onRequestUpdate — notificar visitante cuando su solicitud cambia
// =============================================================================
export const onRequestUpdate = onDocumentUpdated(
  { document: "access_requests/{requestId}", region: "us-central1" },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.estado === after.estado) return;
    if (after.estado !== "aceptada" && after.estado !== "rechazada") return;

    try {
      const aceptada = after.estado === "aceptada";
      const titulo = aceptada ? "Solicitud aprobada" : "Solicitud rechazada";
      const body = aceptada
        ? "Tu solicitud de acceso ha sido aprobada. Ya puedes descargar tu QR."
        : "Tu solicitud de acceso ha sido rechazada.";

      const topic = safeTopic(after.codigoQr ? `qr_${after.codigoQr}` : `visitor_${after.ci}`);

      await messaging().send({
        topic,
        notification: { title: titulo, body },
        data: {
          type: "requestUpdate",
          estado: after.estado,
          requestId: event.params.requestId,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "fortguards_channel",
            color: aceptada ? "#4CAF50" : "#F44336",
          },
        },
      });
    } catch (error) {
      console.error("onRequestUpdate error:", error);
    }
  },
);

// =============================================================================
// onQrUpdate — notificar cuando QR expira o se queda sin usos
// =============================================================================
export const onQrUpdate = onDocumentUpdated(
  { document: "qr_invitados/{qrId}", region: "us-central1" },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (before.estado === after.estado) return;

    if (after.estado === "expirado" || after.estado === "sinUsos") {
      try {
        await messaging().send({
          topic: safeTopic(`qr_${after.codigo}`),
          notification: {
            title: "QR expirado",
            body: after.estado === "expirado"
              ? "Tu código QR ha expirado por tiempo"
              : "Tu código QR se ha quedado sin usos",
          },
          data: {
            type: "qrExpired",
            qrId: event.params.qrId,
            estado: after.estado,
          },
        });
      } catch (error) {
        console.error("onQrUpdate error:", error);
      }
    }
  },
);

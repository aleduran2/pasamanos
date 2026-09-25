import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

// `initializeApp()` tiene que correr antes de que se cargue cualquier
// módulo que llame `getFirestore()`/`getMessaging()` a nivel de módulo (acá
// entra `./notificaciones`) — por eso este import va después, no arriba
// del todo con el resto: tsc preserva el orden exacto de los `require()`
// generados, no los reordena como un bundler.
initializeApp();
const db = getFirestore();

import { enviarNotificacion } from "./notificaciones";

export const onNuevoMensaje = onDocumentCreated(
  "conversaciones/{conversacionId}/mensajes/{mensajeId}",
  async (event) => {
    const mensaje = event.data?.data();
    if (!mensaje) {
      logger.warn("onNuevoMensaje: sin datos del mensaje");
      return;
    }

    const conversacionSnap = await db
      .collection("conversaciones")
      .doc(event.params.conversacionId)
      .get();
    const conversacion = conversacionSnap.data();
    if (!conversacion) {
      logger.warn(
        `onNuevoMensaje: no se encontró la conversación ${event.params.conversacionId}`
      );
      return;
    }

    const participantes: string[] = conversacion.participantes ?? [];
    const destinatario = participantes.find(
      (uid) => uid !== mensaje.emisorId
    );
    logger.info(
      `onNuevoMensaje: emisorId=${mensaje.emisorId} participantes=${JSON.stringify(
        participantes
      )} destinatario=${destinatario}`
    );
    if (!destinatario) return;

    await enviarNotificacion(
      destinatario,
      conversacion.publicacionTitulo ?? "Nuevo mensaje",
      mensaje.texto ?? "Tenés un mensaje nuevo"
    );
  }
);

export const onAcuerdoCerrado = onDocumentCreated(
  "acuerdos/{acuerdoId}",
  async (event) => {
    const acuerdo = event.data?.data();
    if (!acuerdo) return;

    await enviarNotificacion(
      acuerdo.compradorId,
      "Trato cerrado",
      `El trato se cerró por $${acuerdo.precioAcordado}`
    );
  }
);

export {
  crearPreferenciaPago,
  mpOAuthCallback,
  mpWebhook,
} from "./mercadopago";

export { crearSesionVerificacion, diditWebhook } from "./didit";

export { onNuevaCalificacion } from "./calificaciones";

export { onNuevaPublicacionParaAlertas } from "./alertas";

export { crearPreferenciaDestacada, destacarWebhook } from "./destacar";

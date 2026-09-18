import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

/**
 * Envía una notificación a todos los dispositivos guardados de un usuario y
 * limpia los tokens que ya no son válidos (apps desinstaladas, etc.).
 */
async function enviarNotificacion(
  uid: string,
  titulo: string,
  cuerpo: string
): Promise<void> {
  const usuarioSnap = await db.collection("users").doc(uid).get();
  const tokens: string[] = usuarioSnap.data()?.fcmTokens ?? [];
  logger.info(`enviarNotificacion: uid=${uid} tokens=${tokens.length}`);
  if (tokens.length === 0) return;

  const respuesta = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: titulo, body: cuerpo },
  });
  logger.info(
    `enviarNotificacion: exitosos=${respuesta.successCount} fallidos=${respuesta.failureCount}`
  );
  respuesta.responses.forEach((resultado, indice) => {
    if (!resultado.success) {
      logger.warn(
        `enviarNotificacion: fallo token[${indice}] error=${resultado.error?.message}`
      );
    }
  });

  const tokensInvalidos: string[] = [];
  respuesta.responses.forEach((resultado, indice) => {
    if (!resultado.success) {
      tokensInvalidos.push(tokens[indice]);
    }
  });
  if (tokensInvalidos.length > 0) {
    await db
      .collection("users")
      .doc(uid)
      .update({
        fcmTokens: FieldValue.arrayRemove(...tokensInvalidos),
      });
  }
}

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

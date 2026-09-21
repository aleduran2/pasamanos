import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";

const db = getFirestore();
const messaging = getMessaging();

/**
 * Envía una notificación a todos los dispositivos guardados de un usuario y
 * limpia los tokens que ya no son válidos (apps desinstaladas, etc.).
 */
export async function enviarNotificacion(
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

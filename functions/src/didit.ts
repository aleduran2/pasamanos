import { createHmac, timingSafeEqual } from "crypto";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";

const db = getFirestore();

const REGION = "southamerica-east1";

// La API key y el secreto del webhook son secretos (Secret Manager,
// `firebase functions:secrets:set DIDIT_API_KEY` / `DIDIT_WEBHOOK_SECRET`).
// El workflow_id no lo es — es solo el identificador del flujo de
// verificación configurado en el panel de Didit (business.didit.me).
const DIDIT_API_KEY = defineSecret("DIDIT_API_KEY");
const DIDIT_WEBHOOK_SECRET = defineSecret("DIDIT_WEBHOOK_SECRET");
const DIDIT_WORKFLOW_ID = defineString("DIDIT_WORKFLOW_ID");

const DIDIT_BASE_URL = "https://verification.didit.me/v3";

/**
 * La llama la app cuando alguien quiere verificar su identidad (siempre
 * iniciativa propia, nunca automático). Crea una sesión de verificación
 * en Didit y devuelve la URL del flujo hospedado — la app la abre en el
 * navegador, así que ni una foto de DNI ni ningún dato personal pasa
 * nunca por nuestro Firestore: solo se guarda el resultado final
 * (verificado / rechazado) y un id de sesión opaco para poder
 * correlacionar la respuesta del webhook.
 */
export const crearSesionVerificacion = onCall(
  { region: REGION, secrets: [DIDIT_API_KEY] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Iniciá sesión para verificarte.");
    }

    const respuesta = await fetch(`${DIDIT_BASE_URL}/session/`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": DIDIT_API_KEY.value(),
      },
      body: JSON.stringify({
        workflow_id: DIDIT_WORKFLOW_ID.value(),
        vendor_data: uid,
      }),
    });
    const datos = (await respuesta.json()) as Record<string, unknown>;

    if (!respuesta.ok) {
      logger.error(
        `crearSesionVerificacion: Didit respondió uid=${uid} ${JSON.stringify(datos)}`
      );
      throw new HttpsError("internal", "No se pudo iniciar la verificación.");
    }

    await db.collection("users").doc(uid).update({
      estadoVerificacion: "pendiente",
      kycSessionId: datos.session_id ?? null,
    });

    logger.info(`crearSesionVerificacion: uid=${uid} session=${datos.session_id}`);

    const url = datos.url as string | undefined;
    if (!url) {
      throw new HttpsError("internal", "Didit no devolvió una URL de verificación.");
    }
    return { url };
  }
);

function mapearEstado(estadoDidit: string | undefined): string {
  switch ((estadoDidit ?? "").toLowerCase()) {
    case "approved":
      return "verificado";
    case "declined":
    case "rejected":
    case "abandoned":
      return "rechazado";
    default:
      // "in review", "not started", "in progress", etc. — sigue en curso.
      return "pendiente";
  }
}

/**
 * Confirma que el POST realmente vino de Didit: recalcula el HMAC-SHA256
 * del cuerpo crudo (sin parsear) con el secreto compartido del webhook y
 * lo compara contra el header `x-signature`. Sin esto, cualquiera podría
 * mandarle un POST a esta URL fingiendo que una cuenta quedó "verificada"
 * sin haber pasado por Didit en absoluto — es la única barrera real de
 * este endpoint, ya que es público por naturaleza (Didit necesita poder
 * llamarlo sin autenticarse).
 */
function firmaValida(rawBody: Buffer, firmaRecibida: string | undefined): boolean {
  if (!firmaRecibida) return false;
  const firmaCalculada = createHmac("sha256", DIDIT_WEBHOOK_SECRET.value())
    .update(rawBody)
    .digest("hex");
  const bufferRecibido = Buffer.from(firmaRecibida);
  const bufferCalculado = Buffer.from(firmaCalculada);
  if (bufferRecibido.length !== bufferCalculado.length) return false;
  return timingSafeEqual(bufferRecibido, bufferCalculado);
}

/**
 * Webhook de Didit: avisa cuando cambia el estado de una sesión de
 * verificación. Se identifica al usuario por `vendor_data` (el uid que
 * mandamos nosotros al crear la sesión), nunca por datos personales.
 */
export const diditWebhook = onRequest(
  { region: REGION, secrets: [DIDIT_WEBHOOK_SECRET] },
  async (req, res) => {
    const firmaRecibida = req.get("x-signature") ?? req.get("x-signature-v2");
    if (!firmaValida(req.rawBody, firmaRecibida)) {
      logger.warn("diditWebhook: firma inválida o ausente, se descarta el POST");
      res.status(401).send("firma inválida");
      return;
    }

    logger.info(`diditWebhook: body=${JSON.stringify(req.body)}`);

    try {
      const vendorData =
        (req.body?.vendor_data as string | undefined) ??
        (req.body?.metadata?.vendor_data as string | undefined);
      const estadoDidit = req.body?.status as string | undefined;
      const sessionId = req.body?.session_id as string | undefined;

      if (!vendorData) {
        res.status(200).send("ok");
        return;
      }

      const nuevoEstado = mapearEstado(estadoDidit);
      await db.collection("users").doc(vendorData).update({
        estadoVerificacion: nuevoEstado,
      });
      logger.info(
        `diditWebhook: uid=${vendorData} session=${sessionId} estadoDidit=${estadoDidit} -> ${nuevoEstado}`
      );

      res.status(200).send("ok");
    } catch (error) {
      logger.error(`diditWebhook: excepción ${error}`);
      res.status(200).send("ok");
    }
  }
);

import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { leerRespuestaMP } from "./mercadopago_http";

const db = getFirestore();

const REGION = "southamerica-east1";

// A diferencia de `crearPreferenciaPago` (que cobra con el access_token DE
// CADA VENDEDORA vía OAuth, split payment con marketplace_fee), esto es
// plata que va directo a la cuenta DE PASAMANOS — no hay split, así que
// usa un único access_token propio, no el flujo OAuth por vendedora.
const MP_ACCESS_TOKEN = defineSecret("MERCADOPAGO_ACCESS_TOKEN");

const PRECIO_DESTACADA = 3000;
const DIAS_DESTACADA = 7;

function urlWebhookDestacar(publicacionId: string): string {
  return `https://${REGION}-pasamanos-dev.cloudfunctions.net/destacarWebhook?publicacionId=${publicacionId}`;
}

/**
 * La vendedora la llama desde "Mi publicación" para pagar y destacarla.
 * Crea la preferencia de Checkout Pro con el access_token propio de
 * Pasamanos — el dinero cae directo en nuestra cuenta.
 */
export const crearPreferenciaDestacada = onCall(
  { region: REGION, secrets: [MP_ACCESS_TOKEN] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Iniciá sesión para destacar tu publicación.");
    }

    const publicacionId = request.data?.publicacionId as string | undefined;
    if (!publicacionId) {
      throw new HttpsError("invalid-argument", "Falta la publicación.");
    }

    const publicacionRef = db.collection("publicaciones").doc(publicacionId);
    const publicacionSnap = await publicacionRef.get();
    const publicacion = publicacionSnap.data();
    if (!publicacion) {
      throw new HttpsError("not-found", "No se encontró la publicación.");
    }
    if (publicacion.vendedorId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Solo la vendedora puede destacar esta publicación."
      );
    }

    const respuesta = await fetch(
      "https://api.mercadopago.com/checkout/preferences",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${MP_ACCESS_TOKEN.value()}`,
        },
        body: JSON.stringify({
          items: [
            {
              title: `Publicación destacada (${DIAS_DESTACADA} días) — ${publicacion.titulo ?? ""}`,
              quantity: 1,
              currency_id: "ARS",
              unit_price: PRECIO_DESTACADA,
            },
          ],
          external_reference: publicacionId,
          notification_url: urlWebhookDestacar(publicacionId),
        }),
      }
    );
    const preferencia = await leerRespuestaMP(respuesta);

    if (!respuesta.ok) {
      logger.error(
        `crearPreferenciaDestacada: MP respondió publicacionId=${publicacionId} status=${respuesta.status} ${JSON.stringify(preferencia)}`
      );
      throw new HttpsError("internal", "No se pudo generar el link de pago.");
    }

    const initPoint =
      (preferencia.sandbox_init_point as string | undefined) ??
      (preferencia.init_point as string | undefined);

    return { initPoint };
  }
);

/**
 * Mercado Pago llama acá cuando cambia el estado del pago de una
 * publicación destacada. Igual que `mpWebhook`: nunca confía en el
 * contenido de la notificación, siempre le pregunta a la API de Mercado
 * Pago el estado real del pago con el propio access_token de Pasamanos.
 */
export const destacarWebhook = onRequest(
  { region: REGION, secrets: [MP_ACCESS_TOKEN] },
  async (req, res) => {
    const publicacionId = req.query.publicacionId as string | undefined;
    const tipo = (req.query.type as string | undefined) ?? req.body?.type;
    const paymentId =
      (req.query["data.id"] as string | undefined) ?? req.body?.data?.id;

    if (tipo !== "payment" || !paymentId || !publicacionId) {
      res.status(200).send("ok");
      return;
    }

    try {
      const pagoResp = await fetch(
        `https://api.mercadopago.com/v1/payments/${paymentId}`,
        { headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN.value()}` } }
      );
      const pago = await leerRespuestaMP(pagoResp);
      if (!pagoResp.ok) {
        logger.error(
          `destacarWebhook: no se pudo leer el pago ${paymentId} status=${pagoResp.status}: ${JSON.stringify(pago)}`
        );
        res.status(200).send("ok");
        return;
      }

      if (pago.status === "approved") {
        const hasta = new Date();
        hasta.setDate(hasta.getDate() + DIAS_DESTACADA);
        await db.collection("publicaciones").doc(publicacionId).update({
          destacadaHasta: hasta,
          fechaUltimoPagoDestacada: FieldValue.serverTimestamp(),
        });
        logger.info(
          `destacarWebhook: publicacionId=${publicacionId} destacada hasta ${hasta.toISOString()}`
        );
      }

      res.status(200).send("ok");
    } catch (error) {
      logger.error(`destacarWebhook: excepción publicacionId=${publicacionId} ${error}`);
      res.status(200).send("ok");
    }
  }
);

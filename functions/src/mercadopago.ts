import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { defineSecret, defineString } from "firebase-functions/params";

const db = getFirestore();

const REGION = "southamerica-east1";

// Client ID no es secreto (viaja igual en la URL de autorización que arma
// la app). Client Secret sí lo es — vive solo en Secret Manager, se
// configura con `firebase functions:secrets:set MERCADOPAGO_CLIENT_SECRET`
// y nunca pasa por un archivo de texto ni por el cliente.
const MP_CLIENT_ID = defineString("MERCADOPAGO_CLIENT_ID");
const MP_CLIENT_SECRET = defineSecret("MERCADOPAGO_CLIENT_SECRET");

const PORCENTAJE_COMISION = 0.05;

function urlCallbackOAuth(): string {
  return `https://${REGION}-pasamanos-dev.cloudfunctions.net/mpOAuthCallback`;
}

function urlWebhook(acuerdoId: string): string {
  return `https://${REGION}-pasamanos-dev.cloudfunctions.net/mpWebhook?acuerdoId=${acuerdoId}`;
}

function paginaResultado(exito: boolean, mensaje: string): string {
  const color = exito ? "#2557D6" : "#B3261E";
  return `<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pasamanos</title></head>
<body style="font-family: sans-serif; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; background:#fff8f6;">
  <div style="text-align:center; padding:24px; max-width:360px;">
    <h2 style="color:${color};">${exito ? "¡Listo!" : "Ups"}</h2>
    <p>${mensaje}</p>
    <p style="color:#777;">Ya podés volver a la app de Pasamanos.</p>
  </div>
</body></html>`;
}

/**
 * Paso 2 del OAuth "conectar cuenta": Mercado Pago redirige acá con `code`
 * (autorización de una vendedora puntual) y `state` (el uid que mandamos
 * nosotros al armar la URL de autorización, para saber de quién es). Se
 * intercambia el code por el access_token/refresh_token DE ESA CUENTA y se
 * guarda — eso es lo que después permite crear cobros a nombre suyo con
 * el `marketplace_fee` de la plataforma. El token nunca llega al cliente:
 * vive solo en `mercadopago_privado`, una colección que las reglas de
 * Firestore bloquean por completo (ni lectura ni escritura desde la app).
 */
export const mpOAuthCallback = onRequest(
  { region: REGION, secrets: [MP_CLIENT_SECRET] },
  async (req, res) => {
    const code = req.query.code as string | undefined;
    const uid = req.query.state as string | undefined;
    const errorMp = req.query.error as string | undefined;

    if (errorMp) {
      logger.warn(`mpOAuthCallback: Mercado Pago devolvió error=${errorMp}`);
      res
        .status(400)
        .send(paginaResultado(false, "Mercado Pago no autorizó la conexión."));
      return;
    }
    if (!code || !uid) {
      res
        .status(400)
        .send(
          paginaResultado(false, "Faltan datos en la respuesta de Mercado Pago.")
        );
      return;
    }

    try {
      const respuesta = await fetch("https://api.mercadopago.com/oauth/token", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          client_id: MP_CLIENT_ID.value(),
          client_secret: MP_CLIENT_SECRET.value(),
          grant_type: "authorization_code",
          code,
          redirect_uri: urlCallbackOAuth(),
        }),
      });
      const datos = (await respuesta.json()) as Record<string, unknown>;

      if (!respuesta.ok) {
        logger.error(
          `mpOAuthCallback: token exchange falló uid=${uid} ${JSON.stringify(datos)}`
        );
        res
          .status(400)
          .send(paginaResultado(false, "No se pudo conectar la cuenta."));
        return;
      }

      await db.collection("mercadopago_privado").doc(uid).set({
        accessToken: datos.access_token,
        refreshToken: datos.refresh_token,
        userIdMP: datos.user_id,
        publicKey: datos.public_key,
        fechaConexion: FieldValue.serverTimestamp(),
      });
      await db.collection("mercadopago").doc(uid).set({
        conectado: true,
        fechaConexion: FieldValue.serverTimestamp(),
      });

      logger.info(`mpOAuthCallback: cuenta conectada uid=${uid}`);
      res
        .status(200)
        .send(
          paginaResultado(true, "Tu cuenta de Mercado Pago quedó conectada.")
        );
    } catch (error) {
      logger.error(`mpOAuthCallback: excepción uid=${uid} ${error}`);
      res
        .status(500)
        .send(paginaResultado(false, "Ocurrió un error. Intentá de nuevo."));
    }
  }
);

/**
 * La compradora la llama desde el chat, una vez que hay un acuerdo activo.
 * Crea la preferencia de Checkout Pro usando el access_token DE LA
 * VENDEDORA (no el de la plataforma) — eso es lo que hace que el dinero
 * caiga en su cuenta — con `marketplace_fee` para la comisión del 5% de
 * Pasamanos, que Mercado Pago retiene automáticamente.
 */
export const crearPreferenciaPago = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Iniciá sesión para pagar.");
    }

    const acuerdoId = request.data?.acuerdoId as string | undefined;
    if (!acuerdoId) {
      throw new HttpsError("invalid-argument", "Falta el acuerdo.");
    }

    const acuerdoRef = db.collection("acuerdos").doc(acuerdoId);
    const acuerdoSnap = await acuerdoRef.get();
    const acuerdo = acuerdoSnap.data();
    if (!acuerdo) {
      throw new HttpsError("not-found", "No se encontró el acuerdo.");
    }
    if (acuerdo.compradorId !== uid) {
      throw new HttpsError(
        "permission-denied",
        "Solo la compradora puede pagar este acuerdo."
      );
    }
    if (acuerdo.estado !== "activo") {
      throw new HttpsError(
        "failed-precondition",
        "Este acuerdo ya no está activo."
      );
    }

    const conexionSnap = await db
      .collection("mercadopago_privado")
      .doc(acuerdo.vendedorId)
      .get();
    const accessToken = conexionSnap.data()?.accessToken as string | undefined;
    if (!accessToken) {
      throw new HttpsError(
        "failed-precondition",
        "La vendedora todavía no conectó Mercado Pago."
      );
    }

    const publicacionSnap = await db
      .collection("publicaciones")
      .doc(acuerdo.publicacionId)
      .get();
    const titulo =
      (publicacionSnap.data()?.titulo as string | undefined) ??
      "Producto Pasamanos";

    const precio = Number(acuerdo.precioAcordado);
    const comision = Math.round(precio * PORCENTAJE_COMISION * 100) / 100;

    const respuesta = await fetch(
      "https://api.mercadopago.com/checkout/preferences",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify({
          items: [
            {
              title: titulo,
              quantity: 1,
              currency_id: "ARS",
              unit_price: precio,
            },
          ],
          marketplace_fee: comision,
          external_reference: acuerdoId,
          notification_url: urlWebhook(acuerdoId),
        }),
      }
    );
    const preferencia = (await respuesta.json()) as Record<string, unknown>;

    if (!respuesta.ok) {
      logger.error(
        `crearPreferenciaPago: MP respondió acuerdoId=${acuerdoId} ${JSON.stringify(preferencia)}`
      );
      throw new HttpsError("internal", "No se pudo generar el link de pago.");
    }

    await acuerdoRef.update({ preferenceId: preferencia.id });

    // Sandbox siempre: acá no hay forma de que esto termine cobrando algo
    // real mientras la cuenta conectada sea una cuenta de prueba de MP.
    const initPoint =
      (preferencia.sandbox_init_point as string | undefined) ??
      (preferencia.init_point as string | undefined);

    return { initPoint };
  }
);

async function avisarEnConversacion(
  conversacionId: string,
  emisorId: string,
  texto: string
): Promise<void> {
  const conversacionRef = db.collection("conversaciones").doc(conversacionId);
  await conversacionRef.collection("mensajes").add({
    emisorId,
    texto,
    timestamp: FieldValue.serverTimestamp(),
    leido: false,
    tipo: "sistema",
  });
  await conversacionRef.update({
    ultimoMensaje: texto,
    ultimoMensajeEmisorId: emisorId,
    fechaUltimoMensaje: FieldValue.serverTimestamp(),
    leidoPor: [emisorId],
  });
}

/**
 * Mercado Pago llama acá cuando cambia el estado de un pago. El
 * `acuerdoId` viaja en la propia `notification_url` (se lo agregamos
 * nosotros al crear la preferencia), así que no hace falta adivinar de
 * qué acuerdo/vendedora se trata: se lee derecho el acuerdo, se busca el
 * token de esa vendedora, y con ESE token se le pide a la API de Mercado
 * Pago el estado real del pago — nunca se confía en el contenido de la
 * notificación en sí, que cualquiera podría falsificar.
 */
export const mpWebhook = onRequest({ region: REGION }, async (req, res) => {
  const acuerdoId = req.query.acuerdoId as string | undefined;
  const tipo = (req.query.type as string | undefined) ?? req.body?.type;
  const paymentId =
    (req.query["data.id"] as string | undefined) ?? req.body?.data?.id;

  // Siempre 200: si respondemos otra cosa, Mercado Pago reintenta esta
  // misma notificación en loop durante días.
  if (tipo !== "payment" || !paymentId || !acuerdoId) {
    res.status(200).send("ok");
    return;
  }

  try {
    const acuerdoRef = db.collection("acuerdos").doc(acuerdoId);
    const acuerdoSnap = await acuerdoRef.get();
    const acuerdo = acuerdoSnap.data();
    if (!acuerdo) {
      logger.warn(`mpWebhook: acuerdo ${acuerdoId} no encontrado`);
      res.status(200).send("ok");
      return;
    }

    const conexionSnap = await db
      .collection("mercadopago_privado")
      .doc(acuerdo.vendedorId)
      .get();
    const accessToken = conexionSnap.data()?.accessToken as string | undefined;
    if (!accessToken) {
      logger.warn(`mpWebhook: sin token para vendedora ${acuerdo.vendedorId}`);
      res.status(200).send("ok");
      return;
    }

    const pagoResp = await fetch(
      `https://api.mercadopago.com/v1/payments/${paymentId}`,
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );
    const pago = (await pagoResp.json()) as Record<string, unknown>;
    if (!pagoResp.ok) {
      logger.error(
        `mpWebhook: no se pudo leer el pago ${paymentId}: ${JSON.stringify(pago)}`
      );
      res.status(200).send("ok");
      return;
    }

    const estadoPago = pago.status as string;
    await acuerdoRef.update({
      estadoPago,
      pagoId: String(paymentId),
      fechaActualizacionPago: FieldValue.serverTimestamp(),
    });
    logger.info(
      `mpWebhook: acuerdoId=${acuerdoId} paymentId=${paymentId} estado=${estadoPago}`
    );

    if (estadoPago === "approved") {
      await avisarEnConversacion(
        acuerdo.conversacionId,
        acuerdo.vendedorId,
        "¡Pago recibido! Mercado Pago confirmó el pago del trato."
      );
    } else if (estadoPago === "rejected") {
      await avisarEnConversacion(
        acuerdo.conversacionId,
        acuerdo.vendedorId,
        "El pago fue rechazado. La compradora puede intentar de nuevo."
      );
    }

    res.status(200).send("ok");
  } catch (error) {
    logger.error(`mpWebhook: excepción acuerdoId=${acuerdoId} ${error}`);
    res.status(200).send("ok");
  }
});

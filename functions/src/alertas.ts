import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { enviarNotificacion } from "./notificaciones";

const db = getFirestore();

/**
 * Avisa a quienes tienen guardada una alerta para esta combinación exacta
 * de categoría + talle, apenas se publica un producto nuevo que la
 * cumple. Categoría + talle es lo que identifica el talle de verdad (el
 * mismo string de talle significa algo distinto en ropa que en calzado),
 * así que la alerta se guarda con ambos campos y acá se busca por los dos.
 */
export const onNuevaPublicacionParaAlertas = onDocumentCreated(
  "publicaciones/{publicacionId}",
  async (event) => {
    const publicacion = event.data?.data();
    if (!publicacion) return;

    const categoria = publicacion.categoria as string | undefined;
    const talle = publicacion.talle as string | undefined;
    if (!categoria || !talle) return;

    const alertasSnap = await db
      .collection("alertas")
      .where("categoria", "==", categoria)
      .where("talle", "==", talle)
      .get();
    if (alertasSnap.empty) return;

    const titulo = publicacion.titulo as string | undefined;
    const vendedorId = publicacion.vendedorId as string | undefined;
    const cuerpo = titulo
      ? `Talle ${talle}: ${titulo}`
      : `Hay una publicación nueva de talle ${talle}`;

    await Promise.all(
      alertasSnap.docs.map((doc) => {
        const uid = doc.data().uid as string | undefined;
        // No tiene sentido avisarle a la propia vendedora de su publicación.
        if (!uid || uid === vendedorId) return Promise.resolve();
        return enviarNotificacion(uid, "Nueva publicación de tu talle", cuerpo);
      })
    );

    logger.info(
      `onNuevaPublicacionParaAlertas: categoria=${categoria} talle=${talle} avisos=${alertasSnap.size}`
    );
  }
);

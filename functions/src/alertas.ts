import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { enviarNotificacion } from "./notificaciones";

const db = getFirestore();

/**
 * Avisa a quienes tienen guardada una alerta para esta categoría, apenas
 * se publica un producto nuevo que la cumple. Categoría + talle es lo que
 * identifica el talle de verdad (el mismo string de talle significa algo
 * distinto en ropa que en calzado), así que la alerta se guarda con ambos
 * campos y acá se busca por los dos — pero una alerta también puede tener
 * `talle: null` ("cualquier talle de esta categoría", para categorías que
 * no usan talles como accesorios/juguetes/libros/bebé), así que esa
 * combinación se busca siempre, además del talle puntual si la
 * publicación tiene uno.
 */
export const onNuevaPublicacionParaAlertas = onDocumentCreated(
  "publicaciones/{publicacionId}",
  async (event) => {
    const publicacion = event.data?.data();
    if (!publicacion) return;

    const categoria = publicacion.categoria as string | undefined;
    const talle = (publicacion.talle as string | undefined) ?? null;
    if (!categoria) return;

    const consultas = [
      db
        .collection("alertas")
        .where("categoria", "==", categoria)
        .where("talle", "==", null)
        .get(),
    ];
    if (talle) {
      consultas.push(
        db
          .collection("alertas")
          .where("categoria", "==", categoria)
          .where("talle", "==", talle)
          .get()
      );
    }
    const snaps = await Promise.all(consultas);
    const docs = snaps.flatMap((snap) => snap.docs);
    if (docs.length === 0) return;

    // Si alguien tiene guardada tanto una alerta puntual (p. ej. "Ropa,
    // talle M") como una de "cualquier talle" para la misma categoría, las
    // dos consultas la traen por separado — sin este Set, le llegarían
    // dos notificaciones iguales por la misma publicación.
    const uidsNotificados = new Set<string>();

    const titulo = publicacion.titulo as string | undefined;
    const vendedorId = publicacion.vendedorId as string | undefined;
    const cuerpo = talle
      ? titulo
        ? `Talle ${talle}: ${titulo}`
        : `Hay una publicación nueva de talle ${talle}`
      : titulo
        ? titulo
        : "Hay una publicación nueva en esa categoría";

    await Promise.all(
      docs.map((doc) => {
        const uid = doc.data().uid as string | undefined;
        // No tiene sentido avisarle a la propia vendedora de su publicación.
        if (!uid || uid === vendedorId) return Promise.resolve();
        if (uidsNotificados.has(uid)) return Promise.resolve();
        uidsNotificados.add(uid);
        return enviarNotificacion(uid, "Nueva publicación de tu talle", cuerpo);
      })
    );

    logger.info(
      `onNuevaPublicacionParaAlertas: categoria=${categoria} talle=${talle} avisos=${docs.length}`
    );
  }
);

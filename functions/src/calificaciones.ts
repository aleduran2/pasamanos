import { getFirestore } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

const db = getFirestore();

/**
 * Recalcula la reputación de quien recibió una calificación nueva. Nunca lo
 * hace el cliente directamente (bloqueado en las reglas de `users` y
 * `perfiles_publicos`) para que nadie pueda inflar su propio promedio — acá
 * se guarda además `sumaCalificaciones`, un campo interno que no se expone
 * en el modelo del cliente, para no tener que releer todas las
 * calificaciones en cada actualización.
 */
export const onNuevaCalificacion = onDocumentCreated(
  "calificaciones/{calificacionId}",
  async (event) => {
    const calificacion = event.data?.data();
    if (!calificacion) return;

    const destinatarioId = calificacion.destinatarioId as string | undefined;
    const puntaje = calificacion.puntaje as number | undefined;
    if (!destinatarioId || typeof puntaje !== "number") return;

    const nuevosValores = await db.runTransaction(async (tx) => {
      const userRef = db.collection("users").doc(destinatarioId);
      const userSnap = await tx.get(userRef);
      const datos = userSnap.data() ?? {};
      const sumaAnterior = (datos.sumaCalificaciones as number) ?? 0;
      const cantidadAnterior = (datos.cantidadTransacciones as number) ?? 0;
      const nuevaSuma = sumaAnterior + puntaje;
      const nuevaCantidad = cantidadAnterior + 1;
      const nuevoPromedio = nuevaSuma / nuevaCantidad;

      tx.set(
        userRef,
        {
          sumaCalificaciones: nuevaSuma,
          cantidadTransacciones: nuevaCantidad,
          calificacionPromedio: nuevoPromedio,
        },
        { merge: true }
      );

      return { nuevaCantidad, nuevoPromedio };
    });

    // Mismo par de valores en la copia pública, para que quien mira una
    // publicación vea la reputación real de la vendedora sin poder leer el
    // resto de su perfil privado.
    await db.collection("perfiles_publicos").doc(destinatarioId).set(
      {
        cantidadTransacciones: nuevosValores.nuevaCantidad,
        calificacionPromedio: nuevosValores.nuevoPromedio,
      },
      { merge: true }
    );
  }
);

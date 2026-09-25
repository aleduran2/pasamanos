// `.json()` explota con "Unexpected end of JSON input" si el body viene
// vacío (pasa, por ejemplo, si Mercado Pago corta la conexión por un token
// inválido) — leer como texto primero evita que la función se caiga sin
// dejar rastro de qué respondió realmente la API. Compartido entre
// `mercadopago.ts` (split payments) y `destacar.ts` (publicación
// destacada), que hablan con la misma API por caminos distintos.
export async function leerRespuestaMP(
  respuesta: Response
): Promise<Record<string, unknown>> {
  const texto = await respuesta.text();
  if (!texto) return {};
  try {
    return JSON.parse(texto) as Record<string, unknown>;
  } catch {
    return { _rawBody: texto };
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

/// Solo lee/expone si la cuenta está conectada — el access_token en sí
/// vive en una colección separada (`mercadopago_privado`) que las reglas
/// de Firestore bloquean por completo; ni esta app ni ninguna otra lo
/// puede leer, solo las Cloud Functions con permisos de administrador.
abstract class MercadoPagoRepository {
  Future<bool> estaConectada(String uid);
}

class FirestoreMercadoPagoRepository implements MercadoPagoRepository {
  FirestoreMercadoPagoRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<bool> estaConectada(String uid) async {
    final doc = await _firestore.collection('mercadopago').doc(uid).get();
    return doc.data()?['conectado'] as bool? ?? false;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/alerta_model.dart';

class AlertaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'alertas';

  /// Obtener alertas activas de un condominio (para el guardia)
  static Stream<List<AlertaModel>> streamAlertasActivas(String condominio) {
    return _firestore
        .collection(_collection)
        .where('condominio', isEqualTo: condominio)
        .where('estado', isEqualTo: 'activa')
        .orderBy('creadoAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlertaModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Obtener historial de alertas atendidas de un condominio
  static Stream<List<AlertaModel>> streamHistorialAlertas(String condominio, {int limite = 50}) {
    return _firestore
        .collection(_collection)
        .where('condominio', isEqualTo: condominio)
        .where('estado', isEqualTo: 'atendida')
        .orderBy('creadoAt', descending: true)
        .limit(limite)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AlertaModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  /// Marcar alerta como atendida
  static Future<void> marcarComoAtendida({
    required String alertaId,
    required String guardiaId,
    required String guardiaNombre,
    String? notas,
  }) async {
    try {
      await _firestore.collection(_collection).doc(alertaId).update({
        'estado': 'atendida',
        'atendidaPor': guardiaId,
        'atendidaPorNombre': guardiaNombre,
        'atendidaAt': FieldValue.serverTimestamp(),
        'notas': notas,
      });
    } catch (e) {
      throw Exception('Error al marcar alerta como atendida: $e');
    }
  }

  /// Obtener cantidad de alertas activas (para badge)
  static Stream<int> streamCantidadAlertasActivas(String condominio) {
    return _firestore
        .collection(_collection)
        .where('condominio', isEqualTo: condominio)
        .where('estado', isEqualTo: 'activa')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Obtener alerta por ID
  static Future<AlertaModel?> obtenerPorId(String alertaId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(alertaId).get();
      if (doc.exists) {
        return AlertaModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener alerta: $e');
    }
  }
}

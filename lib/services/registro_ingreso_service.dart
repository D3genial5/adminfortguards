import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/registro_ingreso_model.dart';
import 'firebase_service.dart';

class RegistroIngresoService {
  static FirebaseFirestore get _firestore => FirebaseService.firestore;
  static const String _collection = 'registros_ingreso';

  static Future<void> registrarIngreso({
    required String guardiaId,
    required String guardiaNombre,
    required String condominio,
    required Map<String, dynamic> datosQR,
  }) async {
    try {
      final registro = RegistroIngresoModel(
        id: '',
        guardiaId: guardiaId,
        guardiaNombre: guardiaNombre,
        condominio: condominio,
        usuarioNombre: datosQR['visitante'] ?? 'Propietario',
        tipoUsuario: datosQR['visitante'] != null ? 'visitante' : 'propietario',
        casa: datosQR['casa']?.toString(),
        visitanteCI: datosQR['ci'],
        motivoVisita: datosQR['motivo'],
        fechaIngreso: DateTime.now(),
        estado: 'ingresado',
      );

      await _firestore.collection(_collection).add(registro.toFirestore());
    } catch (e) {
      throw Exception('Error al registrar ingreso: $e');
    }
  }

  static Future<void> registrarSalida(String registroId) async {
    try {
      await _firestore.collection(_collection).doc(registroId).update({
        'fechaSalida': Timestamp.fromDate(DateTime.now()),
        'estado': 'salido',
      });
    } catch (e) {
      throw Exception('Error al registrar salida: $e');
    }
  }

  static Stream<List<RegistroIngresoModel>> obtenerRegistrosActivos(String condominio) {
    return _firestore
        .collection(_collection)
        .where('condominio', isEqualTo: condominio)
        .where('estado', isEqualTo: 'ingresado')
        .orderBy('fechaIngreso', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RegistroIngresoModel.fromFirestore(doc))
            .toList());
  }

  static Stream<List<RegistroIngresoModel>> obtenerRegistrosPorCondominio(
    String condominio, {
    int? limite,
  }) {
    Query query = _firestore
        .collection(_collection)
        .where('condominio', isEqualTo: condominio)
        .orderBy('fechaIngreso', descending: true);

    if (limite != null) {
      query = query.limit(limite);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => RegistroIngresoModel.fromFirestore(doc))
        .toList());
  }

  static Future<List<RegistroIngresoModel>> obtenerRegistrosHoy(String condominio) async {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('condominio', isEqualTo: condominio)
          .where('fechaIngreso', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
          .where('fechaIngreso', isLessThanOrEqualTo: Timestamp.fromDate(finHoy))
          .orderBy('fechaIngreso', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => RegistroIngresoModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener registros de hoy: $e');
    }
  }

  static Future<Map<String, int>> obtenerEstadisticas(String condominio) async {
    try {
      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);

      final [activosSnapshot, hoySnapshot] = await Future.wait([
        _firestore
            .collection(_collection)
            .where('condominio', isEqualTo: condominio)
            .where('estado', isEqualTo: 'ingresado')
            .get(),
        _firestore
            .collection(_collection)
            .where('condominio', isEqualTo: condominio)
            .where('fechaIngreso', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
            .get(),
      ]);

      return {
        'activos': activosSnapshot.docs.length,
        'hoy': hoySnapshot.docs.length,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
}
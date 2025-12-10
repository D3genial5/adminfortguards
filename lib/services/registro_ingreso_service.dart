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

  /// Obtener registros por fecha específica
  static Future<List<RegistroIngresoModel>> obtenerRegistrosPorFecha(
    String condominio,
    DateTime fecha,
  ) async {
    final inicioFecha = DateTime(fecha.year, fecha.month, fecha.day);
    final finFecha = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('condominio', isEqualTo: condominio)
          .where('fechaIngreso', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioFecha))
          .where('fechaIngreso', isLessThanOrEqualTo: Timestamp.fromDate(finFecha))
          .get();

      final registros = snapshot.docs
          .map((doc) => RegistroIngresoModel.fromFirestore(doc))
          .toList();
      
      // Ordenar manualmente por fecha descendente
      registros.sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
      
      return registros;
    } catch (e) {
      throw Exception('Error al obtener registros por fecha: $e');
    }
  }

  /// Obtener registros de los últimos N meses
  static Future<List<RegistroIngresoModel>> obtenerRegistrosUltimosMeses(
    String condominio, {
    int meses = 3,
    int? limite,
  }) async {
    final ahora = DateTime.now();
    final fechaInicio = DateTime(ahora.year, ahora.month - meses, ahora.day);

    try {
      Query query = _firestore
          .collection(_collection)
          .where('condominio', isEqualTo: condominio)
          .where('fechaIngreso', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio));

      if (limite != null) {
        query = query.limit(limite);
      }

      final snapshot = await query.get();

      final registros = snapshot.docs
          .map((doc) => RegistroIngresoModel.fromFirestore(doc))
          .toList();
      
      // Ordenar manualmente por fecha descendente
      registros.sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
      
      return registros;
    } catch (e) {
      throw Exception('Error al obtener registros de los últimos meses: $e');
    }
  }

  /// Obtener estadísticas extendidas
  static Future<Map<String, int>> obtenerEstadisticasExtendidas(String condominio) async {
    try {
      final ahora = DateTime.now();
      final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      final inicioSemana = inicioHoy.subtract(Duration(days: inicioHoy.weekday - 1));

      final [hoySnapshot, semanaSnapshot, mesSnapshot] = await Future.wait([
        _firestore
            .collection(_collection)
            .where('condominio', isEqualTo: condominio)
            .where('fechaIngreso', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
            .get(),
        _firestore
            .collection(_collection)
            .where('condominio', isEqualTo: condominio)
            .where('fechaIngreso', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioSemana))
            .get(),
        _firestore
            .collection(_collection)
            .where('condominio', isEqualTo: condominio)
            .where('fechaIngreso', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
            .get(),
      ]);

      return {
        'hoy': hoySnapshot.docs.length,
        'semana': semanaSnapshot.docs.length,
        'mes': mesSnapshot.docs.length,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas extendidas: $e');
    }
  }

  /// Buscar registros por nombre o CI
  static Future<List<RegistroIngresoModel>> buscarRegistros(
    String condominio,
    String termino,
  ) async {
    try {
      // Firestore no soporta búsqueda de texto completo, 
      // así que obtenemos todos y filtramos en código
      final ahora = DateTime.now();
      final fechaInicio = DateTime(ahora.year, ahora.month - 3, ahora.day);
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('condominio', isEqualTo: condominio)
          .where('fechaIngreso', isGreaterThanOrEqualTo: Timestamp.fromDate(fechaInicio))
          .get();

      final terminoLower = termino.toLowerCase();
      
      final registros = snapshot.docs
          .map((doc) => RegistroIngresoModel.fromFirestore(doc))
          .where((r) => 
              r.usuarioNombre.toLowerCase().contains(terminoLower) ||
              (r.visitanteCI?.contains(termino) ?? false) ||
              (r.casa?.toLowerCase().contains(terminoLower) ?? false))
          .toList();
      
      // Ordenar por fecha descendente
      registros.sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
      
      return registros;
    } catch (e) {
      throw Exception('Error al buscar registros: $e');
    }
  }
}
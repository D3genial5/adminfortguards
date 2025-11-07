import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/turno_model.dart';

class TurnoService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'turnos';

  // Crear nuevo turno
  static Future<String> crear(TurnoModel turno) async {
    try {
      final docRef = await _firestore.collection(_collection).add(turno.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear turno: $e');
    }
  }

  // Obtener turno actual (activo en este momento)
  static Future<TurnoModel?> obtenerTurnoActual(String condominioId) async {
    try {
      final ahora = DateTime.now();
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .where('estado', isEqualTo: 'activo')
          .where('fechaInicio', isLessThanOrEqualTo: ahora)
          .where('fechaFin', isGreaterThan: ahora)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return TurnoModel.fromFirestore(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener turno actual: $e');
    }
  }

  // Stream del turno actual
  static Stream<TurnoModel?> streamTurnoActual(String condominioId) {
    final ahora = DateTime.now();
    return _firestore
        .collection(_collection)
        .where('condominioId', isEqualTo: condominioId)
        .where('estado', isEqualTo: 'activo')
        .where('fechaInicio', isLessThanOrEqualTo: ahora)
        .where('fechaFin', isGreaterThan: ahora)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            return TurnoModel.fromFirestore(doc.data(), doc.id);
          }
          return null;
        });
  }

  // Obtener turnos por fecha
  static Future<List<TurnoModel>> obtenerPorFecha(String condominioId, DateTime fecha) async {
    try {
      final inicioDia = DateTime(fecha.year, fecha.month, fecha.day);
      final finDia = inicioDia.add(const Duration(days: 1));

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .where('fechaInicio', isGreaterThanOrEqualTo: inicioDia)
          .where('fechaInicio', isLessThan: finDia)
          .get();

      final turnos = querySnapshot.docs
          .map((doc) => TurnoModel.fromFirestore(doc.data(), doc.id))
          .toList();
      
      // Ordenar por fecha de inicio
      turnos.sort((a, b) => a.fechaInicio.compareTo(b.fechaInicio));
      return turnos;
    } catch (e) {
      throw Exception('Error al obtener turnos por fecha: $e');
    }
  }

  // Obtener turnos de un guardia
  static Future<List<TurnoModel>> obtenerPorGuardia(String guardiaId, {int? limite}) async {
    try {
      var query = _firestore
          .collection(_collection)
          .where('guardiaId', isEqualTo: guardiaId);

      if (limite != null) {
        query = query.limit(limite);
      }

      final querySnapshot = await query.get();

      final turnos = querySnapshot.docs
          .map((doc) => TurnoModel.fromFirestore(doc.data(), doc.id))
          .toList();
      
      // Ordenar por fecha más reciente primero
      turnos.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
      return turnos;
    } catch (e) {
      throw Exception('Error al obtener turnos del guardia: $e');
    }
  }

  // Iniciar turno automático
  static Future<String> iniciarTurnoAutomatico(String guardiaId, String condominioId, String tipoTurno) async {
    try {
      final ahora = DateTime.now();
      DateTime fechaInicio, fechaFin;

      if (tipoTurno == 'diurno') {
        // Turno diurno: 6:00 AM a 6:00 PM
        fechaInicio = DateTime(ahora.year, ahora.month, ahora.day, 6, 0);
        fechaFin = DateTime(ahora.year, ahora.month, ahora.day, 18, 0);
        
        // Si ya pasaron las 6 PM, programar para mañana
        if (ahora.hour >= 18) {
          fechaInicio = fechaInicio.add(const Duration(days: 1));
          fechaFin = fechaFin.add(const Duration(days: 1));
        }
      } else {
        // Turno nocturno: 6:00 PM a 6:00 AM del día siguiente
        fechaInicio = DateTime(ahora.year, ahora.month, ahora.day, 18, 0);
        fechaFin = DateTime(ahora.year, ahora.month, ahora.day + 1, 6, 0);
        
        // Si ya pasaron las 6 AM, programar para esta noche
        if (ahora.hour >= 6 && ahora.hour < 18) {
          // Mantener fechas como están
        } else if (ahora.hour >= 18) {
          // Ya es de noche, usar fechas actuales
        } else {
          // Es muy temprano, programar para la noche anterior
          fechaInicio = fechaInicio.subtract(const Duration(days: 1));
          fechaFin = fechaFin.subtract(const Duration(days: 1));
        }
      }

      final turno = TurnoModel(
        id: '',
        guardiaId: guardiaId,
        condominioId: condominioId,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        estado: 'activo',
        reportes: [],
      );

      return await crear(turno);
    } catch (e) {
      throw Exception('Error al iniciar turno automático: $e');
    }
  }

  // Iniciar turno simple
  static Future<String> iniciarTurno(TurnoModel turno) async {
    try {
      return await crear(turno);
    } catch (e) {
      throw Exception('Error al iniciar turno: $e');
    }
  }

  // Finalizar turno
  static Future<void> finalizarTurno(String turnoId) async {
    try {
      await _firestore.collection(_collection).doc(turnoId).update({
        'estado': 'completado',
        'fechaFin': DateTime.now(), // Actualizar hora real de fin
      });
    } catch (e) {
      throw Exception('Error al finalizar turno: $e');
    }
  }

  // Cancelar turno
  static Future<void> cancelarTurno(String turnoId, String motivo) async {
    try {
      await _firestore.collection(_collection).doc(turnoId).update({
        'estado': 'cancelado',
        'motivoCancelacion': motivo,
      });
    } catch (e) {
      throw Exception('Error al cancelar turno: $e');
    }
  }

  // Agregar reporte de acceso
  static Future<void> agregarReporteAcceso(String turnoId, ReporteAcceso reporte) async {
    try {
      await _firestore.collection(_collection).doc(turnoId).update({
        'reportes': FieldValue.arrayUnion([reporte.toMap()]),
      });
    } catch (e) {
      throw Exception('Error al agregar reporte de acceso: $e');
    }
  }

  // Obtener estadísticas de turnos
  static Future<Map<String, dynamic>> obtenerEstadisticas(String condominioId, DateTime desde, DateTime hasta) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .where('fechaInicio', isGreaterThanOrEqualTo: desde)
          .where('fechaInicio', isLessThanOrEqualTo: hasta)
          .get();

      final turnos = querySnapshot.docs
          .map((doc) => TurnoModel.fromFirestore(doc.data(), doc.id))
          .toList();

      final totalTurnos = turnos.length;
      final turnosCompletados = turnos.where((t) => t.esCompletado).length;
      final turnosCancelados = turnos.where((t) => t.esCancelado).length;
      final totalAccesos = turnos.fold<int>(0, (total, turno) => total + turno.totalAccesos);

      return {
        'totalTurnos': totalTurnos,
        'completados': turnosCompletados,
        'cancelados': turnosCancelados,
        'activos': turnos.where((t) => t.esActivo).length,
        'totalAccesos': totalAccesos,
        'promedioAccesosPorTurno': totalTurnos > 0 ? (totalAccesos / totalTurnos).round() : 0,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
}

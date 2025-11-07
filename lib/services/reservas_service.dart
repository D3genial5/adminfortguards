import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/reserva_model.dart';
import 'firebase_service.dart';

class ReservasService {
  static FirebaseFirestore? get _db => FirebaseService.firestore;

  // Obtener todas las reservas de un condominio
  static Stream<List<ReservaModel>> streamReservas(String condominioId) {
    if (_db == null) {
      return Stream.value([]);
    }

    return _db!
        .collection('condominios')
        .doc(condominioId)
        .collection('reservas')
        .orderBy('fechaSolicitud', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ReservaModel.fromMap(data);
      }).toList();
    });
  }

  // Obtener reservas por estado
  static Stream<List<ReservaModel>> streamReservasPorEstado(
    String condominioId, 
    String estado
  ) {
    if (_db == null) {
      return Stream.value([]);
    }

    return _db!
        .collection('condominios')
        .doc(condominioId)
        .collection('reservas')
        .where('estado', isEqualTo: estado)
        .orderBy('fechaSolicitud', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return ReservaModel.fromMap(data);
      }).toList();
    });
  }

  // Crear nueva reserva
  static Future<void> crearReserva(ReservaModel reserva) async {
    if (_db == null) throw Exception('Firebase no inicializado');

    await _db!
        .collection('condominios')
        .doc(reserva.condominioId)
        .collection('reservas')
        .add(reserva.toMap());
  }

  // Aprobar reserva
  static Future<void> aprobarReserva(
    String condominioId,
    String reservaId,
    String aprobadoPor, {
    double? costoAdicional,
    String? observaciones,
  }) async {
    if (_db == null) throw Exception('Firebase no inicializado');

    await _db!
        .collection('condominios')
        .doc(condominioId)
        .collection('reservas')
        .doc(reservaId)
        .update({
      'estado': 'aprobada',
      'aprobadoPor': aprobadoPor,
      'fechaAprobacion': DateTime.now().toIso8601String(),
      'costoAdicional': costoAdicional,
      'observaciones': observaciones,
    });
  }

  // Rechazar reserva
  static Future<void> rechazarReserva(
    String condominioId,
    String reservaId,
    String aprobadoPor,
    String motivoRechazo,
  ) async {
    if (_db == null) throw Exception('Firebase no inicializado');

    await _db!
        .collection('condominios')
        .doc(condominioId)
        .collection('reservas')
        .doc(reservaId)
        .update({
      'estado': 'rechazada',
      'aprobadoPor': aprobadoPor,
      'fechaAprobacion': DateTime.now().toIso8601String(),
      'motivoRechazo': motivoRechazo,
    });
  }

  // Obtener áreas sociales
  static Stream<List<AreaSocialModel>> streamAreasSociales(String condominioId) {
    if (_db == null) {
      return Stream.value(_getDefaultAreasSociales());
    }

    return _db!
        .collection('condominios')
        .doc(condominioId)
        .collection('areas_sociales')
        .where('activa', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return _getDefaultAreasSociales();
      }
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AreaSocialModel.fromMap(data);
      }).toList();
    });
  }

  // Crear áreas sociales por defecto
  static Future<void> crearAreasSocialesDefault(String condominioId) async {
    if (_db == null) return;

    final areas = _getDefaultAreasSociales();
    final batch = _db!.batch();

    for (final area in areas) {
      final docRef = _db!
          .collection('condominios')
          .doc(condominioId)
          .collection('areas_sociales')
          .doc();
      
      batch.set(docRef, area.toMap());
    }

    await batch.commit();
  }

  // Áreas sociales por defecto
  static List<AreaSocialModel> _getDefaultAreasSociales() {
    return [
      AreaSocialModel(
        id: 'piscina',
        nombre: 'Piscina',
        descripcion: 'Área de piscina con zona de descanso',
        costoReserva: 50.0,
        horariosDisponibles: [
          '08:00-12:00',
          '14:00-18:00',
          '19:00-22:00',
        ],
        capacidadMaxima: 20,
        requiereAprobacion: true,
      ),
      AreaSocialModel(
        id: 'salon_eventos',
        nombre: 'Salón de Eventos',
        descripcion: 'Salón principal para celebraciones',
        costoReserva: 100.0,
        horariosDisponibles: [
          '10:00-14:00',
          '15:00-19:00',
          '20:00-24:00',
        ],
        capacidadMaxima: 50,
        requiereAprobacion: true,
      ),
      AreaSocialModel(
        id: 'cancha_deportiva',
        nombre: 'Cancha Deportiva',
        descripcion: 'Cancha multiusos para deportes',
        costoReserva: 30.0,
        horariosDisponibles: [
          '06:00-10:00',
          '16:00-20:00',
          '20:00-22:00',
        ],
        capacidadMaxima: 10,
        requiereAprobacion: false,
      ),
      AreaSocialModel(
        id: 'zona_bbq',
        nombre: 'Zona BBQ',
        descripcion: 'Área de parrillas y mesas',
        costoReserva: 25.0,
        horariosDisponibles: [
          '11:00-15:00',
          '17:00-21:00',
        ],
        capacidadMaxima: 15,
        requiereAprobacion: true,
      ),
    ];
  }

  // Verificar disponibilidad
  static Future<bool> verificarDisponibilidad(
    String condominioId,
    String areaSocial,
    DateTime fecha,
    String horaInicio,
    String horaFin,
  ) async {
    if (_db == null) return true;

    final reservasExistentes = await _db!
        .collection('condominios')
        .doc(condominioId)
        .collection('reservas')
        .where('areaSocial', isEqualTo: areaSocial)
        .where('fechaReserva', isEqualTo: fecha.toIso8601String().split('T')[0])
        .where('estado', whereIn: ['pendiente', 'aprobada'])
        .get();

    // Verificar conflictos de horario
    for (final doc in reservasExistentes.docs) {
      final data = doc.data();
      final inicioExistente = data['horaInicio'];
      final finExistente = data['horaFin'];

      // Lógica simple de verificación de conflictos
      if (_hayConflictoHorario(horaInicio, horaFin, inicioExistente, finExistente)) {
        return false;
      }
    }

    return true;
  }

  static bool _hayConflictoHorario(
    String inicio1, String fin1, 
    String inicio2, String fin2
  ) {
    final int inicio1Min = _horaAMinutos(inicio1);
    final int fin1Min = _horaAMinutos(fin1);
    final int inicio2Min = _horaAMinutos(inicio2);
    final int fin2Min = _horaAMinutos(fin2);

    return !(fin1Min <= inicio2Min || inicio1Min >= fin2Min);
  }

  static int _horaAMinutos(String hora) {
    final parts = hora.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

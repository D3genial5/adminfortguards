import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;
import '../models/notificacion_model.dart';
import 'firebase_service.dart';

class NotificacionService {
  static FirebaseFirestore? get _firestore => FirebaseService.firestore;
  static const String _collection = 'notificaciones';
  
  // Inicializar servicio de notificaciones
  static Future<void> inicializar() async {
    try {
      // Funcionalidad de notificaciones deshabilitada temporalmente
      dev.log('Servicio de notificaciones deshabilitado');
    } catch (e) {
      throw Exception('Error al inicializar notificaciones: $e');
    }
  }
  
  // Obtener token FCM
  static Future<String?> obtenerTokenFCM() async {
    try {
      // Funcionalidad de token deshabilitada
      return null;
    } catch (e) {
      throw Exception('Error al obtener token FCM: $e');
    }
  }
  
  // Suscribirse a tópico
  static Future<void> suscribirseATopic(String condominioId) async {
    try {
      // Funcionalidad de suscripción deshabilitada
      dev.log('Suscripción a tópico deshabilitada: $condominioId');
    } catch (e) {
      throw Exception('Error al suscribirse al tópico: $e');
    }
  }
  
  // Desuscribirse de tópico
  static Future<void> desuscribirseDeTopico(String condominioId) async {
    try {
      // Funcionalidad de desuscripción deshabilitada
      dev.log('Desuscripción de tópico deshabilitada: $condominioId');
    } catch (e) {
      throw Exception('Error al desuscribirse del tópico: $e');
    }
  }

  // Crear nueva notificación
  static Future<String> crear(NotificacionModel notificacion) async {
    if (_firestore == null) {
      throw Exception('Firebase no inicializado');
    }
    
    try {
      final docRef = await _firestore!.collection(_collection).add(notificacion.toFirestore());
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear notificación: $e');
    }
  }

  // Obtener notificación por ID
  static Future<NotificacionModel?> obtenerPorId(String id) async {
    if (_firestore == null) {
      throw Exception('Firebase no inicializado');
    }
    
    try {
      final doc = await _firestore!.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      
      return NotificacionModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Error al obtener notificación: $e');
    }
  }

  // Obtener todas las notificaciones de un condominio
  static Future<List<NotificacionModel>> obtenerPorCondominio(String condominioId, {int? limite}) async {
    if (_firestore == null) {
      return [];
    }
    
    try {
      Query query = _firestore!
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .orderBy('fechaCreacion', descending: true);
      
      if (limite != null) {
        query = query.limit(limite);
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => NotificacionModel.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener notificaciones: $e');
    }
  }

  // Stream de notificaciones por condominio
  static Stream<List<NotificacionModel>> streamPorCondominio(String condominioId) {
    if (_firestore == null) {
      return Stream.value([]);
    }
    
    return _firestore!
        .collection(_collection)
        .where('condominioId', isEqualTo: condominioId)
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificacionModel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Actualizar notificación
  static Future<void> actualizar(String id, Map<String, dynamic> datos) async {
    if (_firestore == null) {
      throw Exception('Firebase no inicializado');
    }
    
    try {
      await _firestore!.collection(_collection).doc(id).update(datos);
    } catch (e) {
      throw Exception('Error al actualizar notificación: $e');
    }
  }

  // Eliminar notificación
  static Future<void> eliminar(String id) async {
    if (_firestore == null) {
      throw Exception('Firebase no inicializado');
    }
    
    try {
      await _firestore!.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Error al eliminar notificación: $e');
    }
  }

  // Cancelar notificación
  static Future<void> cancelar(String id) async {
    try {
      await actualizar(id, {
        'estado': EstadoNotificacion.cancelada.toString(),
        'fechaCancelacion': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al cancelar notificación: $e');
    }
  }

  // Marcar como leída
  static Future<void> marcarComoLeida(String id) async {
    try {
      await actualizar(id, {
        'leida': true,
        'fechaLectura': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al marcar como leída: $e');
    }
  }

  // Marcar como enviada
  static Future<void> marcarComoEnviada(String id) async {
    try {
      await actualizar(id, {
        'estado': EstadoNotificacion.enviada.toString(),
        'fechaEnvio': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error al marcar como enviada: $e');
    }
  }

  // Obtener notificaciones no leídas
  static Future<List<NotificacionModel>> obtenerNoLeidas(String condominioId) async {
    if (_firestore == null) {
      return [];
    }
    
    try {
      final snapshot = await _firestore!
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .where('leida', isEqualTo: false)
          .orderBy('fechaCreacion', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => NotificacionModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener notificaciones no leídas: $e');
    }
  }

  // Obtener notificaciones por estado
  static Future<List<NotificacionModel>> obtenerPorEstado(String condominioId, EstadoNotificacion estado) async {
    if (_firestore == null) {
      return [];
    }
    
    try {
      final snapshot = await _firestore!
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .where('estado', isEqualTo: estado.toString())
          .orderBy('fechaCreacion', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => NotificacionModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener notificaciones por estado: $e');
    }
  }

  // Enviar notificación inmediata
  static Future<void> enviarInmediata(NotificacionModel notificacion) async {
    try {
      // Crear la notificación con estado enviada
      final notificacionEnviada = notificacion.copyWith(
        estado: EstadoNotificacion.enviada,
        fechaProgramada: DateTime.now(),
      );

      await crear(notificacionEnviada);
      dev.log('Notificación inmediata creada: ${notificacion.titulo}');
    } catch (e) {
      throw Exception('Error al enviar notificación inmediata: $e');
    }
  }

  // Programar notificación
  static Future<String> programar(NotificacionModel notificacion) async {
    try {
      final notificacionProgramada = notificacion.copyWith(
        estado: EstadoNotificacion.programada,
      );

      final id = await crear(notificacionProgramada);
      dev.log('Notificación programada creada: ${notificacion.titulo}');
      return id;
    } catch (e) {
      throw Exception('Error al programar notificación: $e');
    }
  }

  // Obtener estadísticas de notificaciones
  static Future<Map<String, int>> obtenerEstadisticas(String condominioId, DateTime desde, DateTime hasta) async {
    if (_firestore == null) {
      return {'total': 0, 'enviadas': 0, 'programadas': 0, 'canceladas': 0};
    }
    
    try {
      final snapshot = await _firestore!
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .where('fechaCreacion', isGreaterThanOrEqualTo: desde)
          .where('fechaCreacion', isLessThanOrEqualTo: hasta)
          .get();
      
      final notificaciones = snapshot.docs
          .map((doc) => NotificacionModel.fromFirestore(doc.data(), doc.id))
          .toList();
      
      return {
        'total': notificaciones.length,
        'enviadas': notificaciones.where((n) => n.estado == EstadoNotificacion.enviada).length,
        'programadas': notificaciones.where((n) => n.estado == EstadoNotificacion.programada).length,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }

  // Reprogramar notificación recurrente
  static Future<void> reprogramarRecurrente(NotificacionModel notificacion) async {
    try {
      dev.log('Reprogramación de notificación deshabilitada: ${notificacion.titulo}');
    } catch (e) {
      throw Exception('Error al reprogramar notificación recurrente: $e');
    }
  }

}

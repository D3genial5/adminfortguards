import '../core/app_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/access_info_model.dart';
import '../models/access_log_model.dart';

/// Servicio para autorizar/denegar accesos y registrar logs
class AccessService {
  static final _firestore = FirebaseFirestore.instance;

  /// Autoriza un acceso y registra el log
  static Future<Map<String, dynamic>> authorizeEntry({
    required AccessInfoModel accessInfo,
    required String guardiaId,
    required String guardiaNombre,
    String? observaciones,
  }) async {
    try {
      // Usar transacción para operación atómica
      return await _firestore.runTransaction((transaction) async {
        // 1. Referencia a la casa
        final casaRef = _firestore
            .collection('condominios')
            .doc(accessInfo.condominio)
            .collection('casas')
            .doc(accessInfo.casaNumero.toString());

        // 2. Leer datos actuales de la casa
        final casaDoc = await transaction.get(casaRef);
        
        if (!casaDoc.exists) {
          throw Exception('Casa no encontrada');
        }

        final casaData = casaDoc.data()!;
        int usosActuales = casaData['codigoUsos'] as int? ?? 999999;

        // 3. Validar que hay usos disponibles (si aplica)
        if (accessInfo.tipoAcceso == 'usos' && usosActuales <= 0) {
          throw Exception('Sin usos disponibles');
        }

        // 4. Validar tiempo (si aplica)
        if (accessInfo.tipoAcceso == 'tiempo') {
          final expiracion = casaData['codigoExpira'];
          if (expiracion != null) {
            final expiraDate = (expiracion as Timestamp).toDate();
            if (DateTime.now().isAfter(expiraDate)) {
              throw Exception('Acceso expirado por tiempo');
            }
          }
        }

        // 5. Decrementar usos solo si es por usos
        int? nuevosUsos;
        if (accessInfo.tipoAcceso == 'usos' && usosActuales < 999999) {
          nuevosUsos = usosActuales - 1;
          transaction.update(casaRef, {'codigoUsos': nuevosUsos});
          AppLog.log('✅ Usos decrementados: $usosActuales → $nuevosUsos', name: 'AccessService');
        }

        // 6. Crear log de acceso
        final log = AccessLogModel(
          condominio: accessInfo.condominio,
          casaNumero: accessInfo.casaNumero,
          guardiaId: guardiaId,
          guardiaNombre: guardiaNombre,
          resultado: 'permitido',
          tipoAcceso: accessInfo.tipo,
          visitanteCi: accessInfo.visitanteCi,
          visitanteNombre: accessInfo.visitanteNombre,
          timestamp: DateTime.now(),
          usosRestantes: nuevosUsos ?? usosActuales,
          observaciones: observaciones,
        );

        final logRef = _firestore.collection('access_logs').doc();
        transaction.set(logRef, log.toFirestore());

        AppLog.log('✅ Log de acceso creado', name: 'AccessService');

        // 7. Crear notificación para propietario
        await _createNotification(
          condominio: accessInfo.condominio,
          casaNumero: accessInfo.casaNumero,
          visitanteNombre: accessInfo.visitanteNombre,
          guardiaNombre: guardiaNombre,
        );

        return {
          'success': true,
          'message': 'Acceso autorizado correctamente',
          'usosRestantes': nuevosUsos ?? usosActuales,
          'logId': logRef.id,
        };
      });
    } catch (e) {
      AppLog.log('❌ Error autorizando acceso: $e', name: 'AccessService');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Deniega un acceso y registra el log
  static Future<Map<String, dynamic>> denyEntry({
    required AccessInfoModel accessInfo,
    required String guardiaId,
    required String guardiaNombre,
    required String motivo,
    String? observaciones,
  }) async {
    try {
      // Crear log de denegación
      final log = AccessLogModel(
        condominio: accessInfo.condominio,
        casaNumero: accessInfo.casaNumero,
        guardiaId: guardiaId,
        guardiaNombre: guardiaNombre,
        resultado: 'denegado',
        motivo: motivo,
        tipoAcceso: accessInfo.tipo,
        visitanteCi: accessInfo.visitanteCi,
        visitanteNombre: accessInfo.visitanteNombre,
        timestamp: DateTime.now(),
        usosRestantes: accessInfo.usosRestantes,
        observaciones: observaciones,
      );

      await _firestore.collection('access_logs').add(log.toFirestore());

      AppLog.log('📝 Acceso denegado registrado', name: 'AccessService');

      return {
        'success': true,
        'message': 'Acceso denegado registrado',
      };
    } catch (e) {
      AppLog.log('❌ Error registrando denegación: $e', name: 'AccessService');
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Crea una notificación para el propietario
  static Future<void> _createNotification({
    required String condominio,
    required int casaNumero,
    String? visitanteNombre,
    required String guardiaNombre,
  }) async {
    try {
      final titulo = visitanteNombre != null
          ? 'Invitado ha ingresado'
          : 'Ingreso registrado';
      
      final mensaje = visitanteNombre != null
          ? '$visitanteNombre ingresó a tu casa. Autorizado por $guardiaNombre.'
          : 'Se registró un ingreso a tu casa. Autorizado por $guardiaNombre.';

      await _firestore.collection('notificaciones').add({
        'condominio': condominio,
        'casaNumero': casaNumero,
        'titulo': titulo,
        'mensaje': mensaje,
        'tipo': 'privada',
        'fecha': Timestamp.now(),
        'visto': false,
      });

      AppLog.log('🔔 Notificación enviada al propietario', name: 'AccessService');
    } catch (e) {
      AppLog.log('⚠️ Error creando notificación: $e', name: 'AccessService');
      // No lanzar error, la notificación es secundaria
    }
  }

  /// Obtiene logs de acceso con filtros
  static Stream<List<AccessLogModel>> getAccessLogs({
    String? condominio,
    int? casaNumero,
    String? guardiaId,
    DateTime? desde,
    DateTime? hasta,
  }) {
    Query query = _firestore.collection('access_logs');

    if (condominio != null) {
      query = query.where('condominio', isEqualTo: condominio);
    }
    if (casaNumero != null) {
      query = query.where('casaNumero', isEqualTo: casaNumero);
    }
    if (guardiaId != null) {
      query = query.where('guardiaId', isEqualTo: guardiaId);
    }

    return query.snapshots().map((snapshot) {
      var logs = snapshot.docs
          .map((doc) => AccessLogModel.fromFirestore(doc))
          .toList();

      // Filtrar por fecha en código (evita índices compuestos)
      if (desde != null) {
        logs = logs.where((log) => log.timestamp.isAfter(desde)).toList();
      }
      if (hasta != null) {
        logs = logs.where((log) => log.timestamp.isBefore(hasta)).toList();
      }

      // Ordenar por fecha descendente
      logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return logs;
    });
  }

  /// Obtiene estadísticas de accesos
  static Future<Map<String, dynamic>> getAccessStats({
    required String condominio,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    try {
      Query query = _firestore
          .collection('access_logs')
          .where('condominio', isEqualTo: condominio);

      final snapshot = await query.get();
      var logs = snapshot.docs
          .map((doc) => AccessLogModel.fromFirestore(doc))
          .toList();

      // Filtrar por fecha
      if (desde != null) {
        logs = logs.where((log) => log.timestamp.isAfter(desde)).toList();
      }
      if (hasta != null) {
        logs = logs.where((log) => log.timestamp.isBefore(hasta)).toList();
      }

      final total = logs.length;
      final permitidos = logs.where((log) => log.resultado == 'permitido').length;
      final denegados = logs.where((log) => log.resultado == 'denegado').length;
      final invitados = logs.where((log) => log.tipoAcceso == 'invitado').length;
      final propietarios = logs.where((log) => log.tipoAcceso == 'propietario').length;

      return {
        'total': total,
        'permitidos': permitidos,
        'denegados': denegados,
        'invitados': invitados,
        'propietarios': propietarios,
        'tasaAprobacion': total > 0 ? (permitidos / total * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      AppLog.log('Error obteniendo estadísticas: $e', name: 'AccessService');
      return {
        'total': 0,
        'permitidos': 0,
        'denegados': 0,
        'invitados': 0,
        'propietarios': 0,
        'tasaAprobacion': '0.0',
      };
    }
  }
}

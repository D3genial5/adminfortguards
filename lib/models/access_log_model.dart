import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para registrar accesos/ingresos
class AccessLogModel {
  final String? id;
  final String condominio;
  final int casaNumero;
  final String guardiaId;
  final String guardiaNombre;
  final String resultado; // 'permitido' | 'denegado'
  final String? motivo; // Razón si fue denegado
  final String? tipoAcceso; // 'propietario' | 'invitado' | 'visitante'
  final String? visitanteCi;
  final String? visitanteNombre;
  final String? payloadHash; // Hash del payload del QR para auditoría
  final DateTime timestamp;
  final int? usosRestantes; // Usos que quedaron después del acceso
  final String? observaciones;

  AccessLogModel({
    this.id,
    required this.condominio,
    required this.casaNumero,
    required this.guardiaId,
    required this.guardiaNombre,
    required this.resultado,
    this.motivo,
    this.tipoAcceso,
    this.visitanteCi,
    this.visitanteNombre,
    this.payloadHash,
    required this.timestamp,
    this.usosRestantes,
    this.observaciones,
  });

  factory AccessLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AccessLogModel(
      id: doc.id,
      condominio: data['condominio'] as String,
      casaNumero: data['casaNumero'] as int,
      guardiaId: data['guardiaId'] as String,
      guardiaNombre: data['guardiaNombre'] as String,
      resultado: data['resultado'] as String,
      motivo: data['motivo'] as String?,
      tipoAcceso: data['tipoAcceso'] as String?,
      visitanteCi: data['visitanteCi'] as String?,
      visitanteNombre: data['visitanteNombre'] as String?,
      payloadHash: data['payloadHash'] as String?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      usosRestantes: data['usosRestantes'] as int?,
      observaciones: data['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'condominio': condominio,
      'casaNumero': casaNumero,
      'guardiaId': guardiaId,
      'guardiaNombre': guardiaNombre,
      'resultado': resultado,
      if (motivo != null) 'motivo': motivo,
      if (tipoAcceso != null) 'tipoAcceso': tipoAcceso,
      if (visitanteCi != null) 'visitanteCi': visitanteCi,
      if (visitanteNombre != null) 'visitanteNombre': visitanteNombre,
      if (payloadHash != null) 'payloadHash': payloadHash,
      'timestamp': Timestamp.fromDate(timestamp),
      if (usosRestantes != null) 'usosRestantes': usosRestantes,
      if (observaciones != null) 'observaciones': observaciones,
    };
  }

  AccessLogModel copyWith({
    String? id,
    String? condominio,
    int? casaNumero,
    String? guardiaId,
    String? guardiaNombre,
    String? resultado,
    String? motivo,
    String? tipoAcceso,
    String? visitanteCi,
    String? visitanteNombre,
    String? payloadHash,
    DateTime? timestamp,
    int? usosRestantes,
    String? observaciones,
  }) {
    return AccessLogModel(
      id: id ?? this.id,
      condominio: condominio ?? this.condominio,
      casaNumero: casaNumero ?? this.casaNumero,
      guardiaId: guardiaId ?? this.guardiaId,
      guardiaNombre: guardiaNombre ?? this.guardiaNombre,
      resultado: resultado ?? this.resultado,
      motivo: motivo ?? this.motivo,
      tipoAcceso: tipoAcceso ?? this.tipoAcceso,
      visitanteCi: visitanteCi ?? this.visitanteCi,
      visitanteNombre: visitanteNombre ?? this.visitanteNombre,
      payloadHash: payloadHash ?? this.payloadHash,
      timestamp: timestamp ?? this.timestamp,
      usosRestantes: usosRestantes ?? this.usosRestantes,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}

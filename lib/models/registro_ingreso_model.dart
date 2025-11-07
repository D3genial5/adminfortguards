import 'package:cloud_firestore/cloud_firestore.dart';

class RegistroIngresoModel {
  final String id;
  final String guardiaId;
  final String guardiaNombre;
  final String condominio;
  final String usuarioNombre;
  final String tipoUsuario;
  final String? casa;
  final String? visitanteCI;
  final String? motivoVisita;
  final DateTime fechaIngreso;
  final DateTime? fechaSalida;
  final String estado;

  RegistroIngresoModel({
    required this.id,
    required this.guardiaId,
    required this.guardiaNombre,
    required this.condominio,
    required this.usuarioNombre,
    required this.tipoUsuario,
    this.casa,
    this.visitanteCI,
    this.motivoVisita,
    required this.fechaIngreso,
    this.fechaSalida,
    required this.estado,
  });

  factory RegistroIngresoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RegistroIngresoModel(
      id: doc.id,
      guardiaId: data['guardiaId'] ?? '',
      guardiaNombre: data['guardiaNombre'] ?? '',
      condominio: data['condominio'] ?? '',
      usuarioNombre: data['usuarioNombre'] ?? '',
      tipoUsuario: data['tipoUsuario'] ?? '',
      casa: data['casa'],
      visitanteCI: data['visitanteCI'],
      motivoVisita: data['motivoVisita'],
      fechaIngreso: (data['fechaIngreso'] as Timestamp).toDate(),
      fechaSalida: data['fechaSalida'] != null 
          ? (data['fechaSalida'] as Timestamp).toDate() 
          : null,
      estado: data['estado'] ?? 'ingresado',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'guardiaId': guardiaId,
      'guardiaNombre': guardiaNombre,
      'condominio': condominio,
      'usuarioNombre': usuarioNombre,
      'tipoUsuario': tipoUsuario,
      'casa': casa,
      'visitanteCI': visitanteCI,
      'motivoVisita': motivoVisita,
      'fechaIngreso': Timestamp.fromDate(fechaIngreso),
      'fechaSalida': fechaSalida != null ? Timestamp.fromDate(fechaSalida!) : null,
      'estado': estado,
    };
  }

  String get fechaIngresoFormateada {
    return '${fechaIngreso.day.toString().padLeft(2, '0')}/${fechaIngreso.month.toString().padLeft(2, '0')}/${fechaIngreso.year} ${fechaIngreso.hour.toString().padLeft(2, '0')}:${fechaIngreso.minute.toString().padLeft(2, '0')}';
  }

  String get tiempoIngreso {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fechaIngreso);
    
    if (diferencia.inDays > 0) {
      return '${diferencia.inDays}d';
    } else if (diferencia.inHours > 0) {
      return '${diferencia.inHours}h';
    } else {
      return '${diferencia.inMinutes}m';
    }
  }
}
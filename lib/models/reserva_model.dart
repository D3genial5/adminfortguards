class ReservaModel {
  final String id;
  final String condominioId;
  final String casaNumero;
  final String propietario;
  final String areaSocial;
  final DateTime fechaReserva;
  final String horaInicio;
  final String horaFin;
  final String estado; // 'pendiente', 'aprobada', 'rechazada'
  final double? costoAdicional;
  final String? motivoRechazo;
  final String? observaciones;
  final DateTime fechaSolicitud;
  final String? aprobadoPor;
  final DateTime? fechaAprobacion;

  ReservaModel({
    required this.id,
    required this.condominioId,
    required this.casaNumero,
    required this.propietario,
    required this.areaSocial,
    required this.fechaReserva,
    required this.horaInicio,
    required this.horaFin,
    this.estado = 'pendiente',
    this.costoAdicional,
    this.motivoRechazo,
    this.observaciones,
    required this.fechaSolicitud,
    this.aprobadoPor,
    this.fechaAprobacion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'condominioId': condominioId,
      'casaNumero': casaNumero,
      'propietario': propietario,
      'areaSocial': areaSocial,
      'fechaReserva': fechaReserva.toIso8601String(),
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'estado': estado,
      'costoAdicional': costoAdicional,
      'motivoRechazo': motivoRechazo,
      'observaciones': observaciones,
      'fechaSolicitud': fechaSolicitud.toIso8601String(),
      'aprobadoPor': aprobadoPor,
      'fechaAprobacion': fechaAprobacion?.toIso8601String(),
    };
  }

  factory ReservaModel.fromMap(Map<String, dynamic> map) {
    return ReservaModel(
      id: map['id'] ?? '',
      condominioId: map['condominioId'] ?? '',
      casaNumero: map['casaNumero'] ?? '',
      propietario: map['propietario'] ?? '',
      areaSocial: map['areaSocial'] ?? '',
      fechaReserva: DateTime.parse(map['fechaReserva']),
      horaInicio: map['horaInicio'] ?? '',
      horaFin: map['horaFin'] ?? '',
      estado: map['estado'] ?? 'pendiente',
      costoAdicional: map['costoAdicional']?.toDouble(),
      motivoRechazo: map['motivoRechazo'],
      observaciones: map['observaciones'],
      fechaSolicitud: DateTime.parse(map['fechaSolicitud']),
      aprobadoPor: map['aprobadoPor'],
      fechaAprobacion: map['fechaAprobacion'] != null 
          ? DateTime.parse(map['fechaAprobacion']) 
          : null,
    );
  }

  ReservaModel copyWith({
    String? id,
    String? condominioId,
    String? casaNumero,
    String? propietario,
    String? areaSocial,
    DateTime? fechaReserva,
    String? horaInicio,
    String? horaFin,
    String? estado,
    double? costoAdicional,
    String? motivoRechazo,
    String? observaciones,
    DateTime? fechaSolicitud,
    String? aprobadoPor,
    DateTime? fechaAprobacion,
  }) {
    return ReservaModel(
      id: id ?? this.id,
      condominioId: condominioId ?? this.condominioId,
      casaNumero: casaNumero ?? this.casaNumero,
      propietario: propietario ?? this.propietario,
      areaSocial: areaSocial ?? this.areaSocial,
      fechaReserva: fechaReserva ?? this.fechaReserva,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      estado: estado ?? this.estado,
      costoAdicional: costoAdicional ?? this.costoAdicional,
      motivoRechazo: motivoRechazo ?? this.motivoRechazo,
      observaciones: observaciones ?? this.observaciones,
      fechaSolicitud: fechaSolicitud ?? this.fechaSolicitud,
      aprobadoPor: aprobadoPor ?? this.aprobadoPor,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
    );
  }
}

class AreaSocialModel {
  final String id;
  final String nombre;
  final String descripcion;
  final double? costoReserva;
  final List<String> horariosDisponibles;
  final int capacidadMaxima;
  final bool requiereAprobacion;
  final bool activa;

  AreaSocialModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.costoReserva,
    required this.horariosDisponibles,
    required this.capacidadMaxima,
    this.requiereAprobacion = true,
    this.activa = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'costoReserva': costoReserva,
      'horariosDisponibles': horariosDisponibles,
      'capacidadMaxima': capacidadMaxima,
      'requiereAprobacion': requiereAprobacion,
      'activa': activa,
    };
  }

  factory AreaSocialModel.fromMap(Map<String, dynamic> map) {
    return AreaSocialModel(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      descripcion: map['descripcion'] ?? '',
      costoReserva: map['costoReserva']?.toDouble(),
      horariosDisponibles: List<String>.from(map['horariosDisponibles'] ?? []),
      capacidadMaxima: map['capacidadMaxima'] ?? 0,
      requiereAprobacion: map['requiereAprobacion'] ?? true,
      activa: map['activa'] ?? true,
    );
  }
}

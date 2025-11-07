enum PrioridadNotificacion { baja, media, alta, urgente }
enum TipoRepeticion { ninguna, diaria, semanal, mensual }
enum EstadoNotificacion { programada, enviada, cancelada }

class NotificacionModel {
  final String id;
  final String condominioId;
  final String titulo;
  final String mensaje;
  final PrioridadNotificacion prioridad;
  final DateTime fechaCreacion;
  final DateTime? fechaProgramada;
  final TipoRepeticion repeticion;
  final EstadoNotificacion estado;
  final List<String> destinatarios; // 'todos', 'propietarios', 'residentes', o IDs específicos
  final String creadoPor; // ID del admin que creó la notificación

  NotificacionModel({
    required this.id,
    required this.condominioId,
    required this.titulo,
    required this.mensaje,
    required this.prioridad,
    required this.fechaCreacion,
    this.fechaProgramada,
    required this.repeticion,
    required this.estado,
    required this.destinatarios,
    required this.creadoPor,
  });

  // Convertir desde Firestore
  factory NotificacionModel.fromFirestore(Map<String, dynamic> data, String id) {
    return NotificacionModel(
      id: id,
      condominioId: data['condominioId'] ?? '',
      titulo: data['titulo'] ?? '',
      mensaje: data['mensaje'] ?? '',
      prioridad: PrioridadNotificacion.values.firstWhere(
        (p) => p.name == data['prioridad'],
        orElse: () => PrioridadNotificacion.media,
      ),
      fechaCreacion: data['fechaCreacion']?.toDate() ?? DateTime.now(),
      fechaProgramada: data['fechaProgramada']?.toDate(),
      repeticion: TipoRepeticion.values.firstWhere(
        (r) => r.name == data['repeticion'],
        orElse: () => TipoRepeticion.ninguna,
      ),
      estado: EstadoNotificacion.values.firstWhere(
        (e) => e.name == data['estado'],
        orElse: () => EstadoNotificacion.programada,
      ),
      destinatarios: List<String>.from(data['destinatarios'] ?? []),
      creadoPor: data['creadoPor'] ?? '',
    );
  }

  // Convertir a Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'condominioId': condominioId,
      'titulo': titulo,
      'mensaje': mensaje,
      'prioridad': prioridad.name,
      'fechaCreacion': fechaCreacion,
      'fechaProgramada': fechaProgramada,
      'repeticion': repeticion.name,
      'estado': estado.name,
      'destinatarios': destinatarios,
      'creadoPor': creadoPor,
    };
  }

  // Getters útiles
  bool get esProgramada => fechaProgramada != null;
  bool get esInmediata => fechaProgramada == null;
  bool get tieneRepeticion => repeticion != TipoRepeticion.ninguna;
  bool get estaEnviada => estado == EstadoNotificacion.enviada;
  bool get estaCancelada => estado == EstadoNotificacion.cancelada;
  bool get estaPendiente => estado == EstadoNotificacion.programada;

  String get prioridadDisplay {
    switch (prioridad) {
      case PrioridadNotificacion.baja:
        return 'Baja';
      case PrioridadNotificacion.media:
        return 'Media';
      case PrioridadNotificacion.alta:
        return 'Alta';
      case PrioridadNotificacion.urgente:
        return 'Urgente';
    }
  }

  String get repeticionDisplay {
    switch (repeticion) {
      case TipoRepeticion.ninguna:
        return 'Sin repetición';
      case TipoRepeticion.diaria:
        return 'Diaria';
      case TipoRepeticion.semanal:
        return 'Semanal';
      case TipoRepeticion.mensual:
        return 'Mensual';
    }
  }

  String get estadoDisplay {
    switch (estado) {
      case EstadoNotificacion.programada:
        return 'Programada';
      case EstadoNotificacion.enviada:
        return 'Enviada';
      case EstadoNotificacion.cancelada:
        return 'Cancelada';
    }
  }

  String get destinatariosDisplay {
    if (destinatarios.contains('todos')) {
      return 'Todos los usuarios';
    } else if (destinatarios.contains('propietarios')) {
      return 'Solo propietarios';
    } else if (destinatarios.contains('residentes')) {
      return 'Solo residentes';
    } else {
      return '${destinatarios.length} usuarios específicos';
    }
  }

  // Copia con cambios
  NotificacionModel copyWith({
    String? id,
    String? condominioId,
    String? titulo,
    String? mensaje,
    PrioridadNotificacion? prioridad,
    DateTime? fechaCreacion,
    DateTime? fechaProgramada,
    TipoRepeticion? repeticion,
    EstadoNotificacion? estado,
    List<String>? destinatarios,
    String? creadoPor,
  }) {
    return NotificacionModel(
      id: id ?? this.id,
      condominioId: condominioId ?? this.condominioId,
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      prioridad: prioridad ?? this.prioridad,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaProgramada: fechaProgramada ?? this.fechaProgramada,
      repeticion: repeticion ?? this.repeticion,
      estado: estado ?? this.estado,
      destinatarios: destinatarios ?? this.destinatarios,
      creadoPor: creadoPor ?? this.creadoPor,
    );
  }
}

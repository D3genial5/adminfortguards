class TurnoModel {
  final String id;
  final String guardiaId;
  final String condominioId;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado; // 'activo' | 'completado' | 'cancelado'
  final List<ReporteAcceso> reportes;

  TurnoModel({
    required this.id,
    required this.guardiaId,
    required this.condominioId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    required this.reportes,
  });

  // Convertir desde Firestore
  factory TurnoModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TurnoModel(
      id: id,
      guardiaId: data['guardiaId'] ?? '',
      condominioId: data['condominioId'] ?? '',
      fechaInicio: data['fechaInicio']?.toDate() ?? DateTime.now(),
      fechaFin: data['fechaFin']?.toDate() ?? DateTime.now(),
      estado: data['estado'] ?? 'activo',
      reportes: (data['reportes'] as List<dynamic>?)
          ?.map((r) => ReporteAcceso.fromMap(r))
          .toList() ?? [],
    );
  }

  // Convertir a Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'guardiaId': guardiaId,
      'condominioId': condominioId,
      'fechaInicio': fechaInicio,
      'fechaFin': fechaFin,
      'estado': estado,
      'reportes': reportes.map((r) => r.toMap()).toList(),
    };
  }

  // Getters útiles
  bool get esActivo => estado == 'activo';
  bool get esCompletado => estado == 'completado';
  bool get esCancelado => estado == 'cancelado';
  
  Duration get duracion => fechaFin.difference(fechaInicio);
  
  int get totalAccesos => reportes.length;
  
  bool get esTurnoActual {
    final ahora = DateTime.now();
    return esActivo && ahora.isAfter(fechaInicio) && ahora.isBefore(fechaFin);
  }
}

class ReporteAcceso {
  final String id;
  final String turnoId;
  final String visitante;
  final String casa;
  final DateTime horaEntrada;
  final String motivo;
  final String tipoVisita;
  final String observaciones;
  final DateTime fechaHora;

  ReporteAcceso({
    required this.id,
    required this.turnoId,
    required this.visitante,
    required this.casa,
    required this.horaEntrada,
    required this.motivo,
    required this.tipoVisita,
    required this.observaciones,
    required this.fechaHora,
  });

  // Constructor alternativo para compatibilidad
  ReporteAcceso.simple({
    required this.visitante,
    required this.casa,
    required this.horaEntrada,
    required this.motivo,
  }) : id = '',
       turnoId = '',
       tipoVisita = 'Visitante',
       observaciones = '',
       fechaHora = DateTime.now();

  // Convertir desde Map
  factory ReporteAcceso.fromMap(Map<String, dynamic> data) {
    return ReporteAcceso(
      id: data['id'] ?? '',
      turnoId: data['turnoId'] ?? '',
      visitante: data['visitante'] ?? '',
      casa: data['casa'] ?? '',
      horaEntrada: data['horaEntrada']?.toDate() ?? DateTime.now(),
      motivo: data['motivo'] ?? '',
      tipoVisita: data['tipoVisita'] ?? 'Visitante',
      observaciones: data['observaciones'] ?? '',
      fechaHora: data['fechaHora']?.toDate() ?? DateTime.now(),
    );
  }

  // Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'turnoId': turnoId,
      'visitante': visitante,
      'casa': casa,
      'horaEntrada': horaEntrada,
      'motivo': motivo,
      'tipoVisita': tipoVisita,
      'observaciones': observaciones,
      'fechaHora': fechaHora,
    };
  }

  // Getter útil
  String get horaFormateada {
    return '${horaEntrada.hour.toString().padLeft(2, '0')}:${horaEntrada.minute.toString().padLeft(2, '0')}';
  }

  // Getter para fecha formateada
  String get fechaFormateada {
    return '${fechaHora.day.toString().padLeft(2, '0')}/${fechaHora.month.toString().padLeft(2, '0')}/${fechaHora.year}';
  }
}

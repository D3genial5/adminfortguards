class SolicitudModel {
  final String nombre;
  final String apellidos;
  final String ci;
  final String condominio;
  final int casaNumero;
  final DateTime fecha;
  final String estado; // 'pendiente', 'aceptada', 'rechazada'

  SolicitudModel({
    required this.nombre,
    required this.apellidos,
    required this.ci,
    required this.condominio,
    required this.casaNumero,
    required this.fecha,
    required this.estado,
  });

  factory SolicitudModel.fromJson(Map<String, dynamic> json) {
    return SolicitudModel(
      nombre: json['nombre'],
      apellidos: json['apellidos'],
      ci: json['ci'],
      condominio: json['condominio'],
      casaNumero: json['casaNumero'],
      fecha: DateTime.parse(json['fecha']),
      estado: json['estado'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'apellidos': apellidos,
      'ci': ci,
      'condominio': condominio,
      'casaNumero': casaNumero,
      'fecha': fecha.toIso8601String(),
      'estado': estado,
    };
  }
}

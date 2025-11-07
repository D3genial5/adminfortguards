class GuardiaModel {
  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final String telefono;
  final String condominioId;
  final String turno; // 'diurno' | 'nocturno'
  final String tipoPerfil; // 'recepcion' | 'vigilancia'
  final bool activo;
  final DateTime fechaIngreso;

  GuardiaModel({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.telefono,
    required this.condominioId,
    required this.turno,
    required this.tipoPerfil,
    required this.activo,
    required this.fechaIngreso,
  });

  // Convertir desde Firestore
  factory GuardiaModel.fromFirestore(Map<String, dynamic> data, String id) {
    return GuardiaModel(
      id: id,
      nombre: data['nombre'] ?? '',
      apellido: data['apellido'] ?? '',
      email: data['email'] ?? '',
      telefono: data['telefono'] ?? '',
      condominioId: data['condominioId'] ?? '',
      turno: data['turno'] ?? 'diurno',
      tipoPerfil: data['tipoPerfil'] ?? 'recepcion',
      activo: data['activo'] ?? true,
      fechaIngreso: data['fechaIngreso']?.toDate() ?? DateTime.now(),
    );
  }

  // Convertir a Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'telefono': telefono,
      'condominioId': condominioId,
      'turno': turno,
      'tipoPerfil': tipoPerfil,
      'activo': activo,
      'fechaIngreso': fechaIngreso,
    };
  }

  // Copia con cambios
  GuardiaModel copyWith({
    String? id,
    String? nombre,
    String? apellido,
    String? email,
    String? telefono,
    String? condominioId,
    String? turno,
    String? tipoPerfil,
    bool? activo,
    DateTime? fechaIngreso,
  }) {
    return GuardiaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      condominioId: condominioId ?? this.condominioId,
      turno: turno ?? this.turno,
      tipoPerfil: tipoPerfil ?? this.tipoPerfil,
      activo: activo ?? this.activo,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
    );
  }

  // Getters útiles
  bool get esDiurno => turno == 'diurno';
  bool get esNocturno => turno == 'nocturno';
  
  String get turnoDisplay => esDiurno ? 'Diurno (6:00 - 18:00)' : 'Nocturno (18:00 - 6:00)';
}

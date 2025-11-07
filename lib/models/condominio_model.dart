// models/condominio_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'casa_model.dart';

// Modelo para representar un administrador/secretaria
class AdministradorModel {
  final String nombre;
  final String apellido;
  final String telefono;
  final String email;
  final String cargo; // 'Administrador', 'Secretaria', 'Conserje', etc.
  final bool esActivo;

  AdministradorModel({
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.email,
    required this.cargo,
    this.esActivo = true,
  });

  String get nombreCompleto => '$nombre $apellido';

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'email': email,
        'cargo': cargo,
        'esActivo': esActivo,
      };

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'email': email,
        'cargo': cargo,
        'esActivo': esActivo,
      };

  factory AdministradorModel.fromJson(Map<String, dynamic> json) {
    return AdministradorModel(
      nombre: json['nombre'] ?? '',
      apellido: json['apellido'] ?? '',
      telefono: json['telefono'] ?? '',
      email: json['email'] ?? '',
      cargo: json['cargo'] ?? 'Administrador',
      esActivo: json['esActivo'] ?? true,
    );
  }

  factory AdministradorModel.fromFirestore(Map<String, dynamic> data) {
    return AdministradorModel(
      nombre: data['nombre'] ?? '',
      apellido: data['apellido'] ?? '',
      telefono: data['telefono'] ?? '',
      email: data['email'] ?? '',
      cargo: data['cargo'] ?? 'Administrador',
      esActivo: data['esActivo'] ?? true,
    );
  }
}

// Modelo principal del condominio
class CondominioModel {
  final String id;
  final String nombre;
  final String direccion;
  final String ciudad;
  final String telefono;
  final String emailContacto;
  
  // Información del responsable/dueño
  final String nombreResponsable;
  final String apellidoResponsable;
  final String telefonoResponsable;
  final String emailResponsable;
  final String cedulaResponsable;
  
  // Administradores y personal
  final List<AdministradorModel> administradores;
  
  // Información adicional
  final DateTime fechaCreacion;
  final String? notas;
  final bool esActivo;
  
  final List<CasaModel> casas;

  CondominioModel({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.ciudad,
    required this.telefono,
    required this.emailContacto,
    required this.nombreResponsable,
    required this.apellidoResponsable,
    required this.telefonoResponsable,
    required this.emailResponsable,
    required this.cedulaResponsable,
    this.administradores = const [],
    DateTime? fechaCreacion,
    this.notas,
    this.esActivo = true,
    required this.casas,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  String get nombreCompletoResponsable => '$nombreResponsable $apellidoResponsable';
  
  String get resumenContacto => '$emailContacto • $telefono';
  
  int get totalCasas => casas.length;
  
  int get totalAdministradores => administradores.where((a) => a.esActivo).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'direccion': direccion,
        'ciudad': ciudad,
        'telefono': telefono,
        'emailContacto': emailContacto,
        'nombreResponsable': nombreResponsable,
        'apellidoResponsable': apellidoResponsable,
        'telefonoResponsable': telefonoResponsable,
        'emailResponsable': emailResponsable,
        'cedulaResponsable': cedulaResponsable,
        'administradores': administradores.map((e) => e.toJson()).toList(),
        'fechaCreacion': fechaCreacion.toIso8601String(),
        'notas': notas,
        'esActivo': esActivo,
        'casas': casas.map((e) => e.toJson()).toList(),
      };

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'direccion': direccion,
        'ciudad': ciudad,
        'telefono': telefono,
        'emailContacto': emailContacto,
        'nombreResponsable': nombreResponsable,
        'apellidoResponsable': apellidoResponsable,
        'telefonoResponsable': telefonoResponsable,
        'emailResponsable': emailResponsable,
        'cedulaResponsable': cedulaResponsable,
        'administradores': administradores.map((e) => e.toFirestore()).toList(),
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
        'notas': notas,
        'esActivo': esActivo,
      };

  factory CondominioModel.fromJson(Map<String, dynamic> json) {
    return CondominioModel(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      direccion: json['direccion'] ?? '',
      ciudad: json['ciudad'] ?? '',
      telefono: json['telefono'] ?? '',
      emailContacto: json['emailContacto'] ?? '',
      nombreResponsable: json['nombreResponsable'] ?? '',
      apellidoResponsable: json['apellidoResponsable'] ?? '',
      telefonoResponsable: json['telefonoResponsable'] ?? '',
      emailResponsable: json['emailResponsable'] ?? '',
      cedulaResponsable: json['cedulaResponsable'] ?? '',
      administradores: json['administradores'] != null
          ? (json['administradores'] as List)
              .map((e) => AdministradorModel.fromJson(e))
              .toList()
          : [],
      fechaCreacion: json['fechaCreacion'] != null
          ? DateTime.parse(json['fechaCreacion'])
          : DateTime.now(),
      notas: json['notas'],
      esActivo: json['esActivo'] ?? true,
      casas: json['casas'] != null
          ? (json['casas'] as List)
              .map((e) => CasaModel.fromJson(e))
              .toList()
          : [],
    );
  }

  factory CondominioModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CondominioModel(
      id: id,
      nombre: data['nombre'] ?? '',
      direccion: data['direccion'] ?? '',
      ciudad: data['ciudad'] ?? '',
      telefono: data['telefono'] ?? '',
      emailContacto: data['emailContacto'] ?? '',
      nombreResponsable: data['nombreResponsable'] ?? '',
      apellidoResponsable: data['apellidoResponsable'] ?? '',
      telefonoResponsable: data['telefonoResponsable'] ?? '',
      emailResponsable: data['emailResponsable'] ?? '',
      cedulaResponsable: data['cedulaResponsable'] ?? '',
      administradores: data['administradores'] != null
          ? (data['administradores'] as List)
              .map((e) => AdministradorModel.fromFirestore(e))
              .toList()
          : [],
      fechaCreacion: data['fechaCreacion'] != null
          ? (data['fechaCreacion'] as Timestamp).toDate()
          : DateTime.now(),
      notas: data['notas'],
      esActivo: data['esActivo'] ?? true,
      casas: [], // Las casas se cargan por separado
    );
  }

  CondominioModel copyWith({
    String? id,
    String? nombre,
    String? direccion,
    String? ciudad,
    String? telefono,
    String? emailContacto,
    String? nombreResponsable,
    String? apellidoResponsable,
    String? telefonoResponsable,
    String? emailResponsable,
    String? cedulaResponsable,
    List<AdministradorModel>? administradores,
    DateTime? fechaCreacion,
    String? notas,
    bool? esActivo,
    List<CasaModel>? casas,
  }) {
    return CondominioModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      telefono: telefono ?? this.telefono,
      emailContacto: emailContacto ?? this.emailContacto,
      nombreResponsable: nombreResponsable ?? this.nombreResponsable,
      apellidoResponsable: apellidoResponsable ?? this.apellidoResponsable,
      telefonoResponsable: telefonoResponsable ?? this.telefonoResponsable,
      emailResponsable: emailResponsable ?? this.emailResponsable,
      cedulaResponsable: cedulaResponsable ?? this.cedulaResponsable,
      administradores: administradores ?? this.administradores,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      notas: notas ?? this.notas,
      esActivo: esActivo ?? this.esActivo,
      casas: casas ?? this.casas,
    );
  }
}

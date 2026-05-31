import 'package:cloud_firestore/cloud_firestore.dart';

// models/casa_model.dart
class CasaModel {
  final String id;
  final String nombre;
  final String propietario;
  final List<String> residentes;
  final bool expensasPagadas;
  final double montoExpensas;
  final DateTime? fechaPago;
  final DateTime fechaCreacion;

  CasaModel({
    required this.id,
    required this.nombre, 
    required this.propietario, 
    this.residentes = const [],
    this.expensasPagadas = false,
    this.montoExpensas = 0.0,
    this.fechaPago,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'propietario': propietario,
        'residentes': residentes,
        'expensasPagadas': expensasPagadas,
        'montoExpensas': montoExpensas,
        'fechaPago': fechaPago?.toIso8601String(),
        'fechaCreacion': fechaCreacion.toIso8601String(),
      };

  Map<String, dynamic> toFirestore() => {
        'nombre': nombre,
        'propietario': propietario,
        'residentes': residentes,
        'expensasPagadas': expensasPagadas,
        'montoExpensas': montoExpensas,
        'fechaPago': fechaPago != null ? Timestamp.fromDate(fechaPago!) : null,
        'fechaCreacion': Timestamp.fromDate(fechaCreacion),
      };

  factory CasaModel.fromJson(Map<String, dynamic> json) {
    return CasaModel(
      id: json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      propietario: json['propietario'] ?? '',
      residentes: json['residentes'] != null 
          ? List<String>.from(json['residentes']) 
          : [json['propietario'] ?? ''],
      expensasPagadas: json['expensasPagadas'] ?? false,
      montoExpensas: (json['montoExpensas'] ?? 0.0).toDouble(),
      fechaPago: json['fechaPago'] != null ? DateTime.parse(json['fechaPago']) : null,
      fechaCreacion: json['fechaCreacion'] != null 
          ? DateTime.parse(json['fechaCreacion']) 
          : DateTime.now(),
    );
  }

  factory CasaModel.fromFirestore(Map<String, dynamic> data, String id) {
    // Leer estado de expensa de forma robusta.
    // En datos históricos existen variantes como: "pagada", "Pagado", "PAGADA".
    final estadoExpensaRaw = data['estadoExpensa']?.toString().trim().toLowerCase() ?? '';
    final expensasPagadasFlag = data['expensasPagadas'] == true;
    final mesesAdelantados = (data['mesesAdelantados'] as num?)?.toInt() ?? 0;

    final expensasPagadas = estadoExpensaRaw.contains('pagad') ||
        estadoExpensaRaw.contains('adelant') ||
        expensasPagadasFlag ||
        mesesAdelantados > 0;
    
    return CasaModel(
      id: id,
      nombre: (data['nombre'] as String?) ?? '',
      propietario: (data['propietario'] as String?) ?? '',
      residentes: data['residentes'] != null 
          ? List<String>.from(data['residentes']) 
          : [(data['propietario'] as String?) ?? ''],
      expensasPagadas: expensasPagadas,
      montoExpensas: (data['montoPagado'] ?? (data['montoExpensas'] as num?)?.toInt() ?? 0.0).toDouble(),
      fechaPago: data['fechaPago'] != null 
          ? (data['fechaPago'] as Timestamp).toDate() 
          : null,
      fechaCreacion: data['fechaCreacion'] != null 
          ? (data['fechaCreacion'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  CasaModel copyWith({
    String? id,
    String? nombre,
    String? propietario,
    List<String>? residentes,
    bool? expensasPagadas,
    double? montoExpensas,
    DateTime? fechaPago,
    DateTime? fechaCreacion,
  }) {
    return CasaModel(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      propietario: propietario ?? this.propietario,
      residentes: residentes ?? this.residentes,
      expensasPagadas: expensasPagadas ?? this.expensasPagadas,
      montoExpensas: montoExpensas ?? this.montoExpensas,
      fechaPago: fechaPago ?? this.fechaPago,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  String get estadoPago => expensasPagadas ? 'Pagado' : 'Pendiente';
  
  String get fechaPagoFormateada {
    if (fechaPago == null) return 'No pagado';
    return '${fechaPago!.day}/${fechaPago!.month}/${fechaPago!.year}';
  }
}

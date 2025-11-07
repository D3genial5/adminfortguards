import 'package:cloud_firestore/cloud_firestore.dart';

class ConfiguracionModel {
  final bool notificacionesActivadas;
  final bool sonidoActivado;
  final bool vibracionActivada;
  final bool modoOscuroAutomatico;
  final String idioma;
  final DateTime? ultimoBackup;
  final String version;

  const ConfiguracionModel({
    this.notificacionesActivadas = true,
    this.sonidoActivado = true,
    this.vibracionActivada = true,
    this.modoOscuroAutomatico = false,
    this.idioma = 'es',
    this.ultimoBackup,
    this.version = '1.0.0',
  });

  // Crear desde Map (SharedPreferences)
  factory ConfiguracionModel.fromMap(Map<String, dynamic> map) {
    return ConfiguracionModel(
      notificacionesActivadas: map['notificacionesActivadas'] ?? true,
      sonidoActivado: map['sonidoActivado'] ?? true,
      vibracionActivada: map['vibracionActivada'] ?? true,
      modoOscuroAutomatico: map['modoOscuroAutomatico'] ?? false,
      idioma: map['idioma'] ?? 'es',
      ultimoBackup: map['ultimoBackup'] != null 
          ? DateTime.parse(map['ultimoBackup']) 
          : null,
      version: map['version'] ?? '1.0.0',
    );
  }

  // Convertir a Map (SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'notificacionesActivadas': notificacionesActivadas,
      'sonidoActivado': sonidoActivado,
      'vibracionActivada': vibracionActivada,
      'modoOscuroAutomatico': modoOscuroAutomatico,
      'idioma': idioma,
      'ultimoBackup': ultimoBackup?.toIso8601String(),
      'version': version,
    };
  }

  // Crear desde Firestore (opcional para sincronización)
  factory ConfiguracionModel.fromFirestore(Map<String, dynamic> data) {
    return ConfiguracionModel(
      notificacionesActivadas: data['notificacionesActivadas'] ?? true,
      sonidoActivado: data['sonidoActivado'] ?? true,
      vibracionActivada: data['vibracionActivada'] ?? true,
      modoOscuroAutomatico: data['modoOscuroAutomatico'] ?? false,
      idioma: data['idioma'] ?? 'es',
      ultimoBackup: data['ultimoBackup'] != null 
          ? (data['ultimoBackup'] as Timestamp).toDate()
          : null,
      version: data['version'] ?? '1.0.0',
    );
  }

  // Convertir a Firestore (opcional para sincronización)
  Map<String, dynamic> toFirestore() {
    return {
      'notificacionesActivadas': notificacionesActivadas,
      'sonidoActivado': sonidoActivado,
      'vibracionActivada': vibracionActivada,
      'modoOscuroAutomatico': modoOscuroAutomatico,
      'idioma': idioma,
      'ultimoBackup': ultimoBackup != null ? Timestamp.fromDate(ultimoBackup!) : null,
      'version': version,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    };
  }

  // CopyWith para actualizaciones
  ConfiguracionModel copyWith({
    bool? notificacionesActivadas,
    bool? sonidoActivado,
    bool? vibracionActivada,
    bool? modoOscuroAutomatico,
    String? idioma,
    DateTime? ultimoBackup,
    String? version,
  }) {
    return ConfiguracionModel(
      notificacionesActivadas: notificacionesActivadas ?? this.notificacionesActivadas,
      sonidoActivado: sonidoActivado ?? this.sonidoActivado,
      vibracionActivada: vibracionActivada ?? this.vibracionActivada,
      modoOscuroAutomatico: modoOscuroAutomatico ?? this.modoOscuroAutomatico,
      idioma: idioma ?? this.idioma,
      ultimoBackup: ultimoBackup ?? this.ultimoBackup,
      version: version ?? this.version,
    );
  }

  @override
  String toString() {
    return 'ConfiguracionModel(notificaciones: $notificacionesActivadas, sonido: $sonidoActivado, vibracion: $vibracionActivada, modoOscuro: $modoOscuroAutomatico, idioma: $idioma, version: $version)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfiguracionModel &&
        other.notificacionesActivadas == notificacionesActivadas &&
        other.sonidoActivado == sonidoActivado &&
        other.vibracionActivada == vibracionActivada &&
        other.modoOscuroAutomatico == modoOscuroAutomatico &&
        other.idioma == idioma &&
        other.ultimoBackup == ultimoBackup &&
        other.version == version;
  }

  @override
  int get hashCode {
    return Object.hash(
      notificacionesActivadas,
      sonidoActivado,
      vibracionActivada,
      modoOscuroAutomatico,
      idioma,
      ultimoBackup,
      version,
    );
  }
}

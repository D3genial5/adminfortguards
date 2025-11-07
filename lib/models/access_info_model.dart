/// Información de acceso para mostrar en UI del guardia
class AccessInfoModel {
  final String tipo; // 'propietario' | 'invitado'
  final String condominio;
  final int casaNumero;
  final String propietarioNombre;
  final String? visitanteNombre;
  final String? visitanteCi;
  final String? tipoAcceso; // 'usos' | 'tiempo' | 'indefinido'
  final int? usosRestantes;
  final int? minutosRestantes; // Para acceso por tiempo
  final DateTime? fechaExpiracion;
  final String estado; // 'vigente' | 'expirado' | 'sin_usos' | 'invalido'
  final String? motivoInvalido;
  final bool firmaValida;
  final String codigoCasa;

  AccessInfoModel({
    required this.tipo,
    required this.condominio,
    required this.casaNumero,
    required this.propietarioNombre,
    this.visitanteNombre,
    this.visitanteCi,
    this.tipoAcceso,
    this.usosRestantes,
    this.minutosRestantes,
    this.fechaExpiracion,
    required this.estado,
    this.motivoInvalido,
    required this.firmaValida,
    required this.codigoCasa,
  });

  /// El acceso es válido y puede permitirse
  bool get puedePermitir {
    return firmaValida && 
           estado == 'vigente' && 
           (usosRestantes == null || usosRestantes! > 0);
  }

  /// Color para UI basado en estado
  String get colorEstado {
    if (!firmaValida || estado == 'invalido') return 'rojo';
    if (estado == 'expirado') return 'rojo';
    if (estado == 'sin_usos') return 'ambar';
    if (estado == 'vigente') return 'verde';
    return 'gris';
  }

  /// Mensaje descriptivo del estado
  String get mensajeEstado {
    if (!firmaValida) return 'Firma inválida - QR no autorizado';
    if (estado == 'invalido' && motivoInvalido != null) return motivoInvalido!;
    if (estado == 'expirado') return 'QR expirado';
    if (estado == 'sin_usos') return 'Sin usos restantes';
    if (estado == 'vigente') {
      if (tipoAcceso == 'indefinido') return 'Acceso indefinido';
      if (tipoAcceso == 'tiempo' && minutosRestantes != null) {
        if (minutosRestantes! > 60) {
          final horas = (minutosRestantes! / 60).floor();
          return 'Válido por $horas hora${horas > 1 ? 's' : ''}';
        }
        return 'Válido por $minutosRestantes minuto${minutosRestantes! > 1 ? 's' : ''}';
      }
      if (tipoAcceso == 'usos' && usosRestantes != null) {
        return '$usosRestantes uso${usosRestantes! > 1 ? 's' : ''} restante${usosRestantes! > 1 ? 's' : ''}';
      }
      return 'QR válido';
    }
    return 'Estado desconocido';
  }

  /// Información de titular para mostrar
  String get titularInfo {
    if (tipo == 'invitado' && visitanteNombre != null) {
      return '$visitanteNombre\nCI: ${visitanteCi ?? 'N/A'}';
    }
    return propietarioNombre;
  }

  /// Iniciales para avatar
  String get iniciales {
    final nombre = visitanteNombre ?? propietarioNombre;
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.substring(0, 1).toUpperCase();
  }
}

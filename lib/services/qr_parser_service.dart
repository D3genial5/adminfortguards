import 'dart:convert';

/// Servicio para parsear múltiples formatos de QR
class QrParserService {
  /// Parsea el contenido del QR y retorna QrData o null si no es válido
  static QrData? parse(String raw) {
    try {
      final s = raw.trim();

      // 1) Formato actual de fortguardsapp: "CONDO:xxx|CASA:yyy|CODIGO:zzz" o "CONDO:xxx|CASA:yyy"
      if (s.contains('CONDO:') && s.contains('CASA:')) {
        final parts = s.split('|');
        String? cond;
        String? casa;
        String? codigo;

        for (final part in parts) {
          if (part.startsWith('CONDO:')) {
            cond = part.substring(6).trim();
          } else if (part.startsWith('CASA:')) {
            casa = part.substring(5).trim();
          } else if (part.startsWith('CODIGO:')) {
            codigo = part.substring(7).trim();
          }
        }

        if (cond != null && cond.isNotEmpty && casa != null && casa.isNotEmpty) {
          // El identificador puede ser numérico ("21") o texto ("Acacia 21").
          // Si viene con prefijo "Casa ", se quita.
          final casaId = casa.replaceFirst(RegExp(r'^[Cc]asa\s+'), '').trim();
          if (casaId.isNotEmpty) {
            return QrData(
              condominioId: cond,
              casaNumero: casaId,
              codigo: codigo ?? '',
              source: 'fortguardsapp_pipe',
            );
          }
        }
      }

      // 2) Formato JSON (con firma HMAC)
      if (s.startsWith('{')) {
        final m = jsonDecode(s) as Map<String, dynamic>;

        // Formato con tipo "fg_pass"
        if ((m['type'] ?? '') == 'fg_pass') {
          final cond = (m['condominio'] ?? '').toString();
          final casa = (m['casa'] ?? '').toString().trim();
          final cod = (m['codigo'] ?? '').toString();
          if (cond.isNotEmpty && casa.isNotEmpty && cod.length == 3 && RegExp(r'^\d{3}$').hasMatch(cod)) {
            return QrData(
              condominioId: cond,
              casaNumero: casa,
              codigo: cod,
              source: 'json_fg_pass',
              signature: m['hmac'] as String?,
              timestamp: m['ts'] as int?,
            );
          }
        }

        // Formato JSON genérico
        final cond = (m['condominio'] ?? '').toString();
        final casa = (m['casa'] ?? m['casaNumero'] ?? '').toString().trim();
        final cod = (m['codigo'] ?? m['codigoCasa'] ?? '').toString();

        if (cond.isNotEmpty && casa.isNotEmpty) {
          return QrData(
            condominioId: cond,
            casaNumero: casa,
            codigo: cod,
            source: 'json_generic',
            signature: m['hmac'] as String?,
            timestamp: m['ts'] as int?,
          );
        }
      }

      // 3) Formato URL: fortguards://pass?condominio=<id>&casa=<num>&codigo=<3dig>
      if (s.startsWith('fortguards://') || s.startsWith('http')) {
        final uri = Uri.parse(s);
        final cond = uri.queryParameters['condominio'] ?? '';
        final casa = (uri.queryParameters['casa'] ?? '').trim();
        final cod = uri.queryParameters['codigo'] ?? '';
        if (cond.isNotEmpty && casa.isNotEmpty && (cod.isEmpty || RegExp(r'^\d{3}$').hasMatch(cod))) {
          return QrData(
            condominioId: cond,
            casaNumero: casa,
            codigo: cod,
            source: 'url',
          );
        }
      }

      // 4) Formato compacto: FG:<c>:<n>:<code>
      if (s.startsWith('FG:')) {
        final parts = s.split(':');
        if (parts.length >= 3) {
          final cond = parts[1];
          final casa = parts[2].trim();
          final cod = parts.length >= 4 ? parts[3] : '';
          if (cond.isNotEmpty && casa.isNotEmpty && (cod.isEmpty || RegExp(r'^\d{3}$').hasMatch(cod))) {
            return QrData(
              condominioId: cond,
              casaNumero: casa,
              codigo: cod,
              source: 'compact',
            );
          }
        }
      }

      // 5) Solo código de 3 dígitos (requiere contexto adicional)
      if (RegExp(r'^\d{3}$').hasMatch(s)) {
        // Retorna null porque necesita condominio/casa del contexto
        return null;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Datos parseados del QR
class QrData {
  final String condominioId;
  final String casaNumero;
  final String codigo;
  final String source;
  final String? signature;
  final int? timestamp;

  QrData({
    required this.condominioId,
    required this.casaNumero,
    required this.codigo,
    required this.source,
    this.signature,
    this.timestamp,
  });

  @override
  String toString() => 'QrData(condo=$condominioId, casa=$casaNumero, codigo=$codigo, source=$source)';
}

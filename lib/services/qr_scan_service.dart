import 'dart:convert';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qr_payload_model.dart';
import '../models/access_info_model.dart';
import 'qr_parser_service.dart';

/// Servicio para escanear y verificar QRs
class QrScanService {
  static final _firestore = FirebaseFirestore.instance;
  static const _defaultSecret = 'fortguards_secret_2024_v1';

  /// Escanea y verifica un QR, retornando información de acceso
  static Future<AccessInfoModel> verifyAndFetch(String qrData) async {
    try {
      dev.log('========== QR RECIBIDO ==========', name: 'QrScan');
      dev.log('QR raw completo: "$qrData"', name: 'QrScan');
      dev.log('QR length: ${qrData.length}', name: 'QrScan');
      dev.log('QR contiene CONDO: ${qrData.contains('CONDO:')}', name: 'QrScan');
      dev.log('QR contiene CASA: ${qrData.contains('CASA:')}', name: 'QrScan');
      dev.log('QR contiene CODIGO: ${qrData.contains('CODIGO:')}', name: 'QrScan');

      // 1. Intentar parsear con el nuevo parser robusto
      final parsed = QrParserService.parse(qrData);
      
      dev.log('Resultado del parser: ${parsed != null ? "SUCCESS" : "NULL"}', name: 'QrScan');
      if (parsed != null) {
        dev.log('Parsed - Condo: ${parsed.condominioId}, Casa: ${parsed.casaNumero}, Codigo: ${parsed.codigo}', name: 'QrScan');
        // Parser nuevo exitoso - validar contra Firestore
        return await _validateSimpleQr(parsed);
      }

      dev.log('Intentando formato JSON legacy...', name: 'QrScan');
      // 2. Fallback: intentar formato JSON con firma (legacy)
      final Map<String, dynamic> jsonData = jsonDecode(qrData);
      final payload = QrPayloadModel.fromJson(jsonData);

      dev.log('QR escaneado: ${payload.condominio} casa ${payload.casaNumero}', name: 'QrScan');

      // 2. Obtener secret del condominio
      final secret = await _getCondominioSecret(payload.condominio);

      // 3. Verificar firma HMAC
      final firmaValida = payload.verifySignature(secret);
      if (!firmaValida) {
        dev.log('⚠️ Firma HMAC inválida', name: 'QrScan');
        return AccessInfoModel(
          tipo: 'invalido',
          condominio: payload.condominio,
          casaNumero: payload.casaNumero,
          propietarioNombre: 'Desconocido',
          estado: 'invalido',
          motivoInvalido: 'Firma digital inválida',
          firmaValida: false,
          codigoCasa: payload.codigoCasa,
        );
      }

      // 4. Verificar expiración
      if (payload.isExpired) {
        dev.log('⏰ QR expirado', name: 'QrScan');
        return await _buildInfoFromPayload(
          payload,
          estado: 'expirado',
          firmaValida: true,
        );
      }

      // 5. Leer datos de Firestore
      final casaDoc = await _firestore
          .collection('condominios')
          .doc(payload.condominio)
          .collection('casas')
          .doc(payload.casaNumero.toString())
          .get();

      if (!casaDoc.exists) {
        return AccessInfoModel(
          tipo: 'invalido',
          condominio: payload.condominio,
          casaNumero: payload.casaNumero,
          propietarioNombre: 'Desconocido',
          estado: 'invalido',
          motivoInvalido: 'Casa no encontrada',
          firmaValida: true,
          codigoCasa: payload.codigoCasa,
        );
      }

      final casaData = casaDoc.data()!;

      // 6. Verificar código de casa
      if (casaData['codigoCasa'] != payload.codigoCasa) {
        return AccessInfoModel(
          tipo: 'invalido',
          condominio: payload.condominio,
          casaNumero: payload.casaNumero,
          propietarioNombre: casaData['propietario'] ?? 'Desconocido',
          estado: 'invalido',
          motivoInvalido: 'Código de casa no coincide',
          firmaValida: true,
          codigoCasa: payload.codigoCasa,
        );
      }

      // 7. Verificar usos disponibles
      final usosDisponibles = casaData['codigoUsos'] as int? ?? 999999;
      if (usosDisponibles <= 0) {
        return await _buildInfoFromPayload(
          payload,
          casaData: casaData,
          estado: 'sin_usos',
          firmaValida: true,
        );
      }

      // 8. Verificar si es invitado
      String? visitanteNombre;
      String? visitanteCi;
      String? tipoAcceso;
      int? minutosRestantes;
      DateTime? fechaExpiracion;

      if (payload.visitanteCiHash != null) {
        // Buscar en access_requests
        final invitadoInfo = await _findInvitadoInfo(
          payload.condominio,
          payload.casaNumero,
          payload.visitanteCiHash!,
        );

        if (invitadoInfo != null) {
          visitanteNombre = invitadoInfo['nombre'];
          visitanteCi = invitadoInfo['ci'];
          tipoAcceso = invitadoInfo['tipoAcceso'];
          
          if (tipoAcceso == 'tiempo') {
            fechaExpiracion = invitadoInfo['fechaExpiracion'];
            if (fechaExpiracion != null) {
              final diff = fechaExpiracion.difference(DateTime.now());
              minutosRestantes = diff.inMinutes > 0 ? diff.inMinutes : 0;
            }
          }
        }
      }

      // 9. Todo válido - construir info
      return AccessInfoModel(
        tipo: payload.visitanteCiHash != null ? 'invitado' : 'propietario',
        condominio: payload.condominio,
        casaNumero: payload.casaNumero,
        propietarioNombre: casaData['propietario'] ?? 'Propietario',
        visitanteNombre: visitanteNombre,
        visitanteCi: visitanteCi,
        tipoAcceso: tipoAcceso ?? (payload.usosMaximos != null ? 'usos' : 'tiempo'),
        usosRestantes: payload.usosMaximos ?? usosDisponibles,
        minutosRestantes: minutosRestantes ?? payload.minutesRemaining,
        fechaExpiracion: fechaExpiracion,
        estado: 'vigente',
        firmaValida: true,
        codigoCasa: payload.codigoCasa,
      );
    } catch (e) {
      dev.log('❌ Error verificando QR: $e', name: 'QrScan');
      return AccessInfoModel(
        tipo: 'invalido',
        condominio: 'Desconocido',
        casaNumero: 0,
        propietarioNombre: 'Error',
        estado: 'invalido',
        motivoInvalido: 'Error al procesar QR: ${e.toString()}',
        firmaValida: false,
        codigoCasa: '',
      );
    }
  }

  /// Busca información del invitado en access_requests
  static Future<Map<String, dynamic>?> _findInvitadoInfo(
    String condominio,
    int casaNumero,
    String ciHash,
  ) async {
    try {
      // Buscar todas las solicitudes aceptadas de esta casa
      final query = await _firestore
          .collection('access_requests')
          .where('condominio', isEqualTo: condominio)
          .where('casaNumero', isEqualTo: casaNumero)
          .where('estado', isEqualTo: 'aceptada')
          .get();

      // Verificar hash del CI
      for (final doc in query.docs) {
        final data = doc.data();
        final ci = data['ci'] as String?;
        if (ci != null) {
          final testHash = QrPayloadModel.hashVisitanteCi(ci, condominio);
          if (testHash == ciHash) {
            return {
              'nombre': data['nombre'],
              'ci': ci,
              'tipoAcceso': data['tipoAcceso'],
              'fechaExpiracion': data['fechaExpiracion'] != null
                  ? DateTime.parse(data['fechaExpiracion'] as String)
                  : null,
            };
          }
        }
      }

      return null;
    } catch (e) {
      dev.log('Error buscando invitado: $e', name: 'QrScan');
      return null;
    }
  }

  /// Construye AccessInfo desde payload y datos opcionales
  static Future<AccessInfoModel> _buildInfoFromPayload(
    QrPayloadModel payload, {
    Map<String, dynamic>? casaData,
    required String estado,
    required bool firmaValida,
  }) async {
    String propietarioNombre = 'Desconocido';

    if (casaData == null && firmaValida) {
      // Intentar obtener datos de casa
      try {
        final doc = await _firestore
            .collection('condominios')
            .doc(payload.condominio)
            .collection('casas')
            .doc(payload.casaNumero.toString())
            .get();

        if (doc.exists) {
          casaData = doc.data();
        }
      } catch (e) {
        dev.log('Error obteniendo datos de casa: $e', name: 'QrScan');
      }
    }

    if (casaData != null) {
      propietarioNombre = casaData['propietario'] ?? 'Propietario';
    }

    return AccessInfoModel(
      tipo: payload.visitanteCiHash != null ? 'invitado' : 'propietario',
      condominio: payload.condominio,
      casaNumero: payload.casaNumero,
      propietarioNombre: propietarioNombre,
      estado: estado,
      firmaValida: firmaValida,
      codigoCasa: payload.codigoCasa,
      usosRestantes: payload.usosMaximos,
      minutosRestantes: payload.minutesRemaining,
    );
  }

  /// Obtiene el secret del condominio
  static Future<String> _getCondominioSecret(String condominio) async {
    try {
      final doc = await _firestore
          .collection('condominios')
          .doc(condominio)
          .get();

      if (doc.exists) {
        final secret = doc.data()?['qrSecret'] as String?;
        if (secret != null && secret.isNotEmpty) {
          return secret;
        }
      }

      return _defaultSecret;
    } catch (e) {
      dev.log('Error obteniendo secret: $e', name: 'QrScan');
      return _defaultSecret;
    }
  }

  /// Valida QR simple parseado (sin firma HMAC)
  static Future<AccessInfoModel> _validateSimpleQr(QrData qrData) async {
    try {
      dev.log('Validando QR: condo=${qrData.condominioId}, casa=${qrData.casaNumero}, codigo=${qrData.codigo}', name: 'QrScan');

      // 1. Leer datos de la casa en Firestore
      final casaDoc = await _firestore
          .collection('condominios')
          .doc(qrData.condominioId)
          .collection('casas')
          .doc(qrData.casaNumero.toString())
          .get();

      if (!casaDoc.exists) {
        return AccessInfoModel(
          tipo: 'invalido',
          condominio: qrData.condominioId,
          casaNumero: qrData.casaNumero,
          propietarioNombre: 'Desconocido',
          estado: 'invalido',
          motivoInvalido: 'Casa no encontrada en el sistema',
          firmaValida: false,
          codigoCasa: qrData.codigo,
        );
      }

      final casaData = casaDoc.data()!;
      final propietarioNombre = casaData['propietario'] as String? ?? 'Propietario';
      final residentes = (casaData['residentes'] as List?)?.cast<String>() ?? <String>[];
      final codigoCasa = casaData['codigoCasa'] as String? ?? '';
      final codigoExpira = casaData['codigoExpira'] as Timestamp?;
      final codigoUsos = casaData['codigoUsos'] as int? ?? 999999;

      // 2. Si el QR tiene código, validarlo
      if (qrData.codigo.isNotEmpty) {
        if (codigoCasa != qrData.codigo) {
          return AccessInfoModel(
            tipo: 'invalido',
            condominio: qrData.condominioId,
            casaNumero: qrData.casaNumero,
            propietarioNombre: propietarioNombre,
            estado: 'invalido',
            motivoInvalido: 'Código de casa no coincide. Se esperaba: $codigoCasa',
            firmaValida: false,
            codigoCasa: qrData.codigo,
          );
        }

        // 3. Validar expiración
        if (codigoExpira != null && DateTime.now().isAfter(codigoExpira.toDate())) {
          return AccessInfoModel(
            tipo: 'propietario',
            condominio: qrData.condominioId,
            casaNumero: qrData.casaNumero,
            propietarioNombre: propietarioNombre,
            estado: 'expirado',
            firmaValida: true,
            codigoCasa: codigoCasa,
          );
        }

        // 4. Validar usos
        if (codigoUsos <= 0) {
          return AccessInfoModel(
            tipo: 'propietario',
            condominio: qrData.condominioId,
            casaNumero: qrData.casaNumero,
            propietarioNombre: propietarioNombre,
            estado: 'sin_usos',
            firmaValida: true,
            codigoCasa: codigoCasa,
          );
        }
      }

      // 5. Todo válido - retornar info completa
      return AccessInfoModel(
        tipo: 'propietario',
        condominio: qrData.condominioId,
        casaNumero: qrData.casaNumero,
        propietarioNombre: residentes.isNotEmpty ? residentes.first : propietarioNombre,
        estado: 'vigente',
        firmaValida: true,
        codigoCasa: codigoCasa.isNotEmpty ? codigoCasa : qrData.codigo,
        usosRestantes: codigoUsos,
      );
    } catch (e) {
      dev.log('Error validando QR simple: $e', name: 'QrScan');
      return AccessInfoModel(
        tipo: 'invalido',
        condominio: qrData.condominioId,
        casaNumero: qrData.casaNumero,
        propietarioNombre: 'Error',
        estado: 'invalido',
        motivoInvalido: 'Error al validar: ${e.toString()}',
        firmaValida: false,
        codigoCasa: qrData.codigo,
      );
    }
  }
}

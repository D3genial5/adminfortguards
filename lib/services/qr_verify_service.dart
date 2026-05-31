import 'dart:async';
import 'dart:convert';
import '../core/app_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Resultado seguro del escaneo de un QR.
class QrVerifyResult {
  final bool valid;
  final String? reason;
  final String? condominio;
  final int? casaNumero;
  final String? casa;
  final String? visitanteNombre;
  final String? visitanteCi;
  final String? tipoAcceso;
  final int? usosRestantes;
  final String? solicitudId;
  final String? codigoQr;
  final String? sessionId;
  final String? tipoQr; // ENTRADA/SALIDA si lo declara el QR
  final bool origenCodigoCasa;
  final String? fotoCarnetFrente;
  final String? fotoCarnetReverso;
  final String? fotoPlaca;
  final String? placa;
  final bool signedByServer;

  const QrVerifyResult({
    required this.valid,
    this.reason,
    this.condominio,
    this.casaNumero,
    this.casa,
    this.visitanteNombre,
    this.visitanteCi,
    this.tipoAcceso,
    this.usosRestantes,
    this.solicitudId,
    this.codigoQr,
    this.sessionId,
    this.tipoQr,
    this.origenCodigoCasa = false,
    this.fotoCarnetFrente,
    this.fotoCarnetReverso,
    this.fotoPlaca,
    this.placa,
    this.signedByServer = false,
  });

  factory QrVerifyResult.invalid(String reason) =>
      QrVerifyResult(valid: false, reason: reason);

  Map<String, dynamic> toQrInfo() => {
        'condominio': condominio,
        'casa': casa ?? 'Casa $casaNumero',
        'casaNumero': casaNumero,
        'visitante': visitanteNombre ?? 'Visitante',
        'ci': visitanteCi,
        'tipoAcceso': tipoAcceso,
        'usosRestantes': usosRestantes,
        'codigoQr': codigoQr,
        'solicitudId': solicitudId,
        'sessionId': sessionId,
        'tipoQr': tipoQr,
        'origenCodigoCasa': origenCodigoCasa,
        'fotoCarnetFrente': fotoCarnetFrente,
        'fotoCarnetReverso': fotoCarnetReverso,
        'fotoPlaca': fotoPlaca,
        'placa': placa,
        'signedByServer': signedByServer,
      };
}

/// Verificador seguro de QR — única puerta de entrada al pipeline de escaneo.
///
/// Rechaza QRs que NO se puedan respaldar contra Firestore o verificar por
/// HMAC server-side. El código antiguo aceptaba `CONDO:X|CASA:Y` directamente
/// y leía el código de la casa sin chequear que existiera un access_request
/// activo. Esta clase obliga a una de tres rutas:
///
///   1. Código único en `access_requests` (visitas aprobadas por el propietario)
///   2. Pipe-format `CONDO:|CASA:|CI:|NOMBRE:` => DEBE encontrarse un
///      access_request `aceptada` para `(condominio, casaNumero, ci)`.
///   3. JSON con firma => verificado por la Cloud Function `verifyQrPayload`.
class QrVerifyService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Verifica el QR raw contra el condominio asignado al guardia.
  static Future<QrVerifyResult> verify(
    String raw, {
    required String condominioGuardia,
  }) async {
    final s = raw.trim();
    if (s.isEmpty) return QrVerifyResult.invalid('QR vacío');

    // 1. Código único de access_request — el path más seguro
    if (!s.startsWith('{') && !s.contains('CONDO:')) {
      return _verifyByUniqueCode(s, condominioGuardia: condominioGuardia);
    }

    // 2. JSON firmado server-side
    if (s.startsWith('{')) {
      return _verifySignedJson(s, condominioGuardia: condominioGuardia);
    }

    // 3. Pipe-format → DEBE existir access_request o casa con código vigente
    return _verifyPipeFormat(s, condominioGuardia: condominioGuardia);
  }

  // ===========================================================================
  // Path 1: código único
  // ===========================================================================
  static Future<QrVerifyResult> _verifyByUniqueCode(
    String code, {
    required String condominioGuardia,
  }) async {
    final query = await _db
        .collection('access_requests')
        .where('codigoQr', isEqualTo: code)
        .where('estado', isEqualTo: 'aceptada')
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return QrVerifyResult.invalid('QR no válido o no autorizado');
    }
    final doc = query.docs.first;
    final data = doc.data();

    if (data['condominio'] != condominioGuardia) {
      return QrVerifyResult.invalid('Este QR es de otro condominio');
    }

    final tipoAcceso = data['tipoAcceso'] as String?;
    final usosRestantes = data['usosRestantes'] as int?;
    if (tipoAcceso != 'indefinido' &&
        usosRestantes != null &&
        usosRestantes <= 0) {
      return QrVerifyResult.invalid('QR sin usos restantes');
    }

    final fechaExp = data['fechaExpiracion'];
    DateTime? expiracion;
    if (fechaExp is Timestamp) {
      expiracion = fechaExp.toDate();
    } else if (fechaExp is String) {
      expiracion = DateTime.tryParse(fechaExp);
    }
    if (expiracion != null && DateTime.now().isAfter(expiracion)) {
      return QrVerifyResult.invalid('QR expirado');
    }

    // Datos de visitante (foto carnet etc.)
    final ci = data['ci'] as String?;
    Map<String, dynamic>? visitanteData;
    if (ci != null && ci.isNotEmpty) {
      final v = await _db.collection('visitantes').doc(ci).get();
      if (v.exists) visitanteData = v.data();
    }

    return QrVerifyResult(
      valid: true,
      condominio: data['condominio'] as String?,
      casaNumero: data['casaNumero'] as int?,
      casa: 'Casa ${data['casaNumero']}',
      visitanteNombre: data['nombre'] as String? ?? 'Visitante',
      visitanteCi: ci,
      tipoAcceso: tipoAcceso,
      usosRestantes: usosRestantes,
      solicitudId: doc.id,
      codigoQr: code,
      fotoCarnetFrente: visitanteData?['fotoCarnetFrente'] as String?,
      fotoCarnetReverso: visitanteData?['fotoCarnetReverso'] as String?,
      fotoPlaca: visitanteData?['fotoPlaca'] as String?,
      placa: (visitanteData?['placa'] ?? data['placa']) as String?,
      signedByServer: false,
    );
  }

  // ===========================================================================
  // Path 2: JSON con firma (HMAC server-side)
  // ===========================================================================
  static Future<QrVerifyResult> _verifySignedJson(
    String raw, {
    required String condominioGuardia,
  }) async {
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return QrVerifyResult.invalid('QR JSON inválido');
    }

    // Verificación server-side
    try {
      final callable = _functions.httpsCallable(
        'verifyQrPayload',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
      );
      final result = await callable.call(<String, dynamic>{'qr': payload});
      final r = result.data as Map?;
      if (r == null || r['valid'] != true) {
        return QrVerifyResult.invalid(
          _humanReason(r?['reason']?.toString()),
        );
      }
      final cond = r['condominio'] as String?;
      if (cond != condominioGuardia) {
        return QrVerifyResult.invalid('Este QR es de otro condominio');
      }
      return QrVerifyResult(
        valid: true,
        condominio: cond,
        casaNumero: r['casaNumero'] as int?,
        casa: 'Casa ${r['casaNumero']}',
        visitanteNombre: r['propietario'] as String? ?? 'Propietario',
        tipoAcceso: r['tipo'] == 'inv' ? 'invitado' : 'propietario',
        usosRestantes: r['usosRestantes'] as int?,
        signedByServer: true,
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) AppLog.log('verifyQrPayload error: ${e.code}', name: 'QrVerify');
      return QrVerifyResult.invalid('Error verificando firma');
    }
  }

  static String _humanReason(String? code) {
    switch (code) {
      case 'expired':
        return 'QR expirado';
      case 'bad_signature':
        return 'Firma inválida';
      case 'wrong_condominio':
        return 'QR de otro condominio';
      case 'casa_not_found':
        return 'Casa no encontrada';
      case 'code_mismatch':
        return 'Código de casa no coincide';
      default:
        return 'QR inválido';
    }
  }

  // ===========================================================================
  // Path 3: Pipe-format (visitante walk-up) — exige access_request o código casa vigente
  // ===========================================================================
  static Future<QrVerifyResult> _verifyPipeFormat(
    String raw, {
    required String condominioGuardia,
  }) async {
    final parts = raw.split('|');
    String? tipoQr;
    String? sessionId;
    String? ciFromQr;
    String? nombreFromQr;
    bool origenCodigoCasa = false;
    String? condominio;
    String? casaStr;

    for (final part in parts) {
      if (part == 'ENTRADA' || part == 'SALIDA') {
        tipoQr = part;
      } else if (part.startsWith('SESSION:')) {
        sessionId = part.substring(8);
      } else if (part == 'ORIGEN:CASA') {
        origenCodigoCasa = true;
      } else if (part.startsWith('CI:')) {
        ciFromQr = part.substring(3);
      } else if (part.startsWith('NOMBRE:')) {
        try {
          nombreFromQr = Uri.decodeComponent(part.substring(7));
        } catch (_) {
          nombreFromQr = part.substring(7);
        }
      } else if (part.startsWith('CONDO:')) {
        condominio = part.substring(6);
      } else if (part.startsWith('CASA:')) {
        casaStr = part.substring(5);
      }
    }

    if (condominio == null || casaStr == null) {
      return QrVerifyResult.invalid('Formato QR no válido');
    }
    if (condominio != condominioGuardia) {
      return QrVerifyResult.invalid('QR de otro condominio');
    }

    final casaNumMatch = RegExp(r'(\d+)').firstMatch(casaStr);
    if (casaNumMatch == null) {
      return QrVerifyResult.invalid('No se pudo identificar la casa');
    }
    final casaNum = int.parse(casaNumMatch.group(1)!);

    // Caso A: visitante walk-up con CI — debe haber access_request 'aceptada'
    if (ciFromQr != null && ciFromQr.isNotEmpty) {
      final reqQuery = await _db
          .collection('access_requests')
          .where('condominio', isEqualTo: condominio)
          .where('casaNumero', isEqualTo: casaNum)
          .where('ci', isEqualTo: ciFromQr)
          .where('estado', isEqualTo: 'aceptada')
          .limit(1)
          .get();

      if (reqQuery.docs.isEmpty) {
        return QrVerifyResult.invalid(
          'Sin solicitud aprobada para este visitante',
        );
      }

      final reqDoc = reqQuery.docs.first;
      final reqData = reqDoc.data();

      // Validar expiración / usos
      final tipoAcceso = reqData['tipoAcceso'] as String?;
      final usosRestantes = reqData['usosRestantes'] as int?;
      if (tipoAcceso != 'indefinido' &&
          usosRestantes != null &&
          usosRestantes <= 0) {
        return QrVerifyResult.invalid('Sin usos restantes');
      }
      final fechaExp = reqData['fechaExpiracion'];
      DateTime? expiracion;
      if (fechaExp is Timestamp) {
        expiracion = fechaExp.toDate();
      } else if (fechaExp is String) {
        expiracion = DateTime.tryParse(fechaExp);
      }
      if (expiracion != null && DateTime.now().isAfter(expiracion)) {
        return QrVerifyResult.invalid('QR expirado');
      }

      Map<String, dynamic>? visitanteData;
      final v = await _db.collection('visitantes').doc(ciFromQr).get();
      if (v.exists) visitanteData = v.data();

      return QrVerifyResult(
        valid: true,
        condominio: condominio,
        casaNumero: casaNum,
        casa: 'Casa $casaNum',
        visitanteNombre: nombreFromQr ?? reqData['nombre'] as String? ?? 'Visitante',
        visitanteCi: ciFromQr,
        tipoAcceso: tipoAcceso ?? 'usos',
        usosRestantes: usosRestantes,
        solicitudId: reqDoc.id,
        sessionId: sessionId,
        tipoQr: tipoQr,
        origenCodigoCasa: origenCodigoCasa,
        fotoCarnetFrente: visitanteData?['fotoCarnetFrente'] as String?,
        fotoCarnetReverso: visitanteData?['fotoCarnetReverso'] as String?,
        fotoPlaca: visitanteData?['fotoPlaca'] as String?,
        placa: (visitanteData?['placa'] ?? reqData['placa']) as String?,
        signedByServer: false,
      );
    }

    // Caso B: QR generado desde "Código de casa" (origenCodigoCasa) — solo
    // permitido si la casa tiene un código vigente con usos > 0.
    if (origenCodigoCasa) {
      final casaDoc = await _db
          .collection('condominios')
          .doc(condominio)
          .collection('casas')
          .doc(casaNum.toString())
          .get();
      if (!casaDoc.exists) {
        return QrVerifyResult.invalid('Casa no encontrada');
      }
      final data = casaDoc.data()!;
      final usos = data['codigoUsos'] as int?;
      final expiraCasa = data['codigoExpira'] as Timestamp?;

      if (usos == null || usos <= 0) {
        return QrVerifyResult.invalid('El código de la casa no tiene usos');
      }
      if (expiraCasa != null && DateTime.now().isAfter(expiraCasa.toDate())) {
        return QrVerifyResult.invalid('El código de la casa expiró');
      }

      return QrVerifyResult(
        valid: true,
        condominio: condominio,
        casaNumero: casaNum,
        casa: 'Casa $casaNum',
        visitanteNombre: data['ultimoVisitanteNombre'] as String? ?? 'Visitante',
        visitanteCi: data['ultimoVisitanteCI'] as String?,
        tipoAcceso: 'usos',
        usosRestantes: usos,
        sessionId: sessionId,
        tipoQr: tipoQr,
        origenCodigoCasa: true,
        fotoCarnetFrente: data['ultimoVisitanteFotoFrente'] as String?,
        fotoCarnetReverso: data['ultimoVisitanteFotoReverso'] as String?,
      );
    }

    return QrVerifyResult.invalid('QR sin CI ni código de casa válido');
  }
}

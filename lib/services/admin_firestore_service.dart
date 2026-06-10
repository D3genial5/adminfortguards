import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_log.dart';
import 'auth_service.dart';

/// Servicio centralizado para tareas que realiza el administrador de un condominio.
class AdminFirestoreService {
  static final _db = FirebaseFirestore.instance;

  /// Stream de todas las casas de un condominio
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamCasas(String condominioId) {
    return _db.collection('condominios').doc(condominioId).collection('casas').snapshots();
  }

  /// Obtiene todas las casas de un condominio (snapshot único)
  static Future<QuerySnapshot<Map<String, dynamic>>> obtenerCasas(String condominioId) async {
    return await _db.collection('condominios').doc(condominioId).collection('casas').get();
  }

  /// Crea o actualiza una casa.
  /// El identificador puede ser numérico ("101") o texto ("Acacia 21").
  /// Si [numeroAnterior] difiere de [numero], la casa se renombra: se copian
  /// los datos (incluida la contraseña) al nuevo documento y se borra el viejo.
  static Future<void> guardarCasa({
    required String condominioId,
    required String numero,
    required String propietario,
    required List<String> residentes,
    String? numeroAnterior,
    String? direccion,
    String? cedulaPropietario,
    String? telefonoPropietario,
    String? emailPropietario,
    String? cedulaResidente,
    String? telefonoResidente,
  }) async {
    final casas = _db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas');
    final casaRef = casas.doc(numero);

    final esRenombre = numeroAnterior != null &&
        numeroAnterior.isNotEmpty &&
        numeroAnterior != numero;

    // Verificar si la casa ya existe para determinar si es nueva
    final casaSnapshot = await casaRef.get();
    final isNuevaCasa = !casaSnapshot.exists && !esRenombre;

    final data = <String, dynamic>{
      'numero': numero,
      'propietario': propietario,
      'residentes': residentes,
      'fechaActualizacion': FieldValue.serverTimestamp(),
    };

    // Agregar campos opcionales solo si tienen valor
    if (direccion != null && direccion.isNotEmpty) {
      data['direccion'] = direccion;
    }
    if (cedulaPropietario != null && cedulaPropietario.isNotEmpty) {
      data['cedulaPropietario'] = cedulaPropietario;
    }
    if (telefonoPropietario != null && telefonoPropietario.isNotEmpty) {
      data['telefonoPropietario'] = telefonoPropietario;
    }
    if (emailPropietario != null && emailPropietario.isNotEmpty) {
      data['emailPropietario'] = emailPropietario;
    }
    if (cedulaResidente != null && cedulaResidente.isNotEmpty) {
      data['cedulaResidente'] = cedulaResidente;
    }
    if (telefonoResidente != null && telefonoResidente.isNotEmpty) {
      data['telefonoResidente'] = telefonoResidente;
    }

    if (esRenombre) {
      // Renombre: el ID del documento es el número de casa, así que se copia
      // el doc viejo completo (contraseña, expensa, etc.) al nuevo ID y se
      // borra el anterior para no dejar casas duplicadas.
      final viejaRef = casas.doc(numeroAnterior);
      final viejaSnap = await viejaRef.get();
      final base = viejaSnap.data() ?? <String, dynamic>{};
      data['estadoExpensa'] = base['estadoExpensa'] ?? 'pendiente';
      await casaRef.set({...base, ...data}, SetOptions(merge: true));
      if (viejaSnap.exists) {
        await viejaRef.delete();
      }
      AppLog.log('Casa $numeroAnterior renombrada a $numero');
    } else if (isNuevaCasa) {
      data['estadoExpensa'] = 'pendiente';
      // Generar contraseña hasheada para el propietario
      final password = AuthService.generarPasswordSeguro(length: 10);
      final salt = AuthService.generarPasswordSeguro(length: 16);
      final hash = AuthService.hashWithSalt(password, salt);
      data['passwordHash'] = hash;
      data['passwordSalt'] = salt;

      await casaRef.set(data, SetOptions(merge: true));

      // La contraseña temporal se devuelve para mostrar una sola vez
      AppLog.log('Casa $numero creada para propietario: $propietario');
    } else {
      // Edición: solo actualizar datos (no tocar password ni expensa)
      await casaRef.set(data, SetOptions(merge: true));
      AppLog.log('Casa $numero actualizada');
    }
  }

  /// Elimina una casa por su identificador (numérico o texto).
  static Future<void> eliminarCasa({
    required String condominioId,
    required String numero,
  }) async {
    await _db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(numero)
        .delete();
    AppLog.log('Casa $numero eliminada de $condominioId');
  }

  /// Cambia el estado de la expensa a 'pagada' o 'pendiente'
  /// Sincroniza con la colección compartida para que la app de propietarios vea el cambio
  static Future<void> actualizarEstadoExpensa({
    required String condominioId,
    required String numero,
    required bool pagada,
    double? montoPagado,
  }) async {
    final updateData = <String, dynamic>{
      'estadoExpensa': pagada ? 'pagada' : 'pendiente',
    };
    
    if (pagada && montoPagado != null) {
      updateData['montoPagado'] = montoPagado;
      updateData['fechaPago'] = FieldValue.serverTimestamp();
    } else if (!pagada) {
      // Si se marca como pendiente, limpiar los campos de pago
      updateData['montoPagado'] = FieldValue.delete();
      updateData['fechaPago'] = FieldValue.delete();
    }
    
    // Actualizar en la colección de casas del condominio
    await _db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(numero)
        .update(updateData);
    
    // Sincronizar con colección de expensas compartida para propietarios
    await _sincronizarExpensaConPropietarios(
      condominioId: condominioId,
      casaNumero: numero,
      pagada: pagada,
      montoPagado: montoPagado,
    );
  }
  
  /// Sincroniza el estado de expensa con la colección compartida
  static Future<void> _sincronizarExpensaConPropietarios({
    required String condominioId,
    required String casaNumero,
    required bool pagada,
    double? montoPagado,
  }) async {
    try {
      final mesActual = DateTime.now();
      final periodoId = '${mesActual.year}-${mesActual.month.toString().padLeft(2, '0')}';
      
      final expensaRef = _db
          .collection('expensas')
          .doc('${condominioId}_${casaNumero}_$periodoId');
      
      final data = {
        'condominioId': condominioId,
        'casaNumero': casaNumero,
        'periodo': periodoId,
        'estado': pagada ? 'pagada' : 'pendiente',
        'montoPagado': montoPagado ?? 0,
        'fechaActualizacion': FieldValue.serverTimestamp(),
      };
      
      if (pagada) {
        data['fechaPago'] = FieldValue.serverTimestamp();
      }
      
      await expensaRef.set(data, SetOptions(merge: true));
      AppLog.log('✅ Expensa sincronizada: Casa $casaNumero - ${pagada ? "Pagada" : "Pendiente"}');
    } catch (e) {
      AppLog.log('⚠️ Error al sincronizar expensa: $e');
    }
  }
  
  /// Stream de expensas para escuchar cambios en tiempo real
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamExpensas(String condominioId) {
    return _db
        .collection('expensas')
        .where('condominioId', isEqualTo: condominioId)
        .snapshots();
  }

  /// Stream del documento del condominio (para escuchar expensasHabilitadas)
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamCondominio(String condominioId) {
    return _db.collection('condominios').doc(condominioId).snapshots();
  }

  /// Lee si las expensas están habilitadas para un condominio
  static Future<bool> expensasHabilitadas(String condominioId) async {
    final doc = await _db.collection('condominios').doc(condominioId).get();
    if (!doc.exists) return true;
    return doc.data()?['expensasHabilitadas'] ?? true;
  }

  /// Activa o desactiva las expensas para un condominio
  static Future<void> setExpensasHabilitadas({
    required String condominioId,
    required bool habilitadas,
  }) async {
    await _db.collection('condominios').doc(condominioId).set(
      {'expensasHabilitadas': habilitadas},
      SetOptions(merge: true),
    );
    AppLog.log('${habilitadas ? '✅' : '🚫'} Expensas ${habilitadas ? 'habilitadas' : 'inhabilitadas'} para $condominioId');
  }

  /// Actualiza datos del administrador en Firestore (sin contraseñas).
  /// El cambio de contraseña se maneja vía Firebase Auth.
  static Future<void> actualizarDatosAdmin({
    required String email,
    required String nombre,
    required String condominioId,
  }) async {
    try {
      final query = await _db
          .collection('administradores')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'nombre': nombre,
          'condominio': condominioId,
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      AppLog.log('Error al actualizar datos admin: $e');
      throw Exception('Error al actualizar datos: $e');
    }
  }

  /// Envía una notificación a un propietario

  /// Verifica que el documento del condominio exista.
  static Future<void> ensureCondominioExists(String condominioId) async {
    final docRef = _db.collection('condominios').doc(condominioId);
    await docRef.set({'nombre': condominioId}, SetOptions(merge: true));
  }

  static Future<void> enviarNotificacion({
    required String condominioId,
    required String numero,
    required String titulo,
    required String mensaje,
  }) async {
    await _db.collection('notificaciones').add({
      'condominio': condominioId,
      'casaNumero': numero,
      'titulo': titulo,
      'mensaje': mensaje,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:developer' as dev;
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

  /// Crea o actualiza una casa
  static Future<void> guardarCasa({
    required String condominioId,
    required int numero,
    required String propietario,
    required List<String> residentes,
    String? direccion,
    String? cedulaPropietario,
    String? telefonoPropietario,
    String? emailPropietario,
    String? cedulaResidente,
    String? telefonoResidente,
  }) async {
    final casaRef = _db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(numero.toString());
    
    // Verificar si la casa ya existe para determinar si es nueva
    final casaSnapshot = await casaRef.get();
    final isNuevaCasa = !casaSnapshot.exists;
    
    final data = {
      'numero': numero,
      'propietario': propietario,
      'residentes': residentes,
      'estadoExpensa': isNuevaCasa ? 'pendiente' : (casaSnapshot.data()?['estadoExpensa'] ?? 'pendiente'),
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

    // Si es una casa nueva, generar contraseña y crear credenciales
    if (isNuevaCasa) {
      // Generar contraseña para el propietario
      final password = AuthService.generarPasswordPropietario(numero.toString());
      data['password'] = password;
      
      // Guardar la casa
      await casaRef.set(data, SetOptions(merge: true));
      
      try {
        // Registrar la casa en el sistema de autenticación
        await AuthService.registrarCasa(
          condominioId: condominioId,
          casaId: numero.toString(),
          password: password,
        );
        
        // Guardar las credenciales del propietario en la colección 'credenciales'
        await _db.collection('credenciales').add({
          'tipo': 'propietario',
          'condominio': condominioId,
          'casa': numero.toString(),
          'password': password,
          'propietario': propietario,
          'email': emailPropietario ?? '',
          'telefono': telefonoPropietario ?? '',
          'cedula': cedulaPropietario ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        dev.log('✅ Casa $numero creada con credenciales para propietario: $propietario');
      } catch (e) {
        dev.log('⚠️ Error al crear credenciales para casa $numero', error: e);
        // La casa ya fue guardada, el error en credenciales no debe bloquear
      }
    } else {
      // Si es una edición, solo actualizar los datos (mantener password existente)
      await casaRef.set(data, SetOptions(merge: true));
      
      // Actualizar las credenciales existentes si hay cambios en el propietario
      try {
        final credQuery = await _db
            .collection('credenciales')
            .where('condominio', isEqualTo: condominioId)
            .where('casa', isEqualTo: numero.toString())
            .where('tipo', isEqualTo: 'propietario')
            .limit(1)
            .get();
        
        if (credQuery.docs.isNotEmpty) {
          await credQuery.docs.first.reference.update({
            'propietario': propietario,
            'email': emailPropietario ?? '',
            'telefono': telefonoPropietario ?? '',
            'cedula': cedulaPropietario ?? '',
            'fechaActualizacion': FieldValue.serverTimestamp(),
          });
          dev.log('✅ Credenciales actualizadas para casa $numero');
        }
      } catch (e) {
        dev.log('⚠️ Error al actualizar credenciales para casa $numero', error: e);
      }
    }
  }

  /// Cambia el estado de la expensa a 'pagada' o 'pendiente'
  static Future<void> actualizarEstadoExpensa({
    required String condominioId,
    required int numero,
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
    
    await _db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(numero.toString())
        .update(updateData);
  }

  /// Actualiza las credenciales de un administrador en el sistema
  static Future<void> actualizarCredencialesAdmin({
    required String email,
    required String nuevaContrasena,
  }) async {
    try {
      // Buscar el documento del administrador en la colección credenciales
      // Primero intentar con tipo "administrador"
      var query = await _db
          .collection('credenciales')
          .where('email', isEqualTo: email)
          .where('tipo', isEqualTo: 'administrador')
          .limit(1)
          .get();

      // Si no encuentra, intentar con tipo "admin"
      if (query.docs.isEmpty) {
        query = await _db
            .collection('credenciales')
            .where('email', isEqualTo: email)
            .where('tipo', isEqualTo: 'admin')
            .limit(1)
            .get();
      }

      // Si aún no encuentra, buscar solo por email
      if (query.docs.isEmpty) {
        query = await _db
            .collection('credenciales')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        // Actualizar la contraseña en el documento encontrado
        await query.docs.first.reference.update({
          'password': nuevaContrasena,
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
        
        debugPrint('✅ Credenciales actualizadas para: $email');
        debugPrint('📄 Documento actualizado: ${query.docs.first.id}');
      } else {
        debugPrint('⚠️ No se encontró documento de credenciales para: $email');
        
        // Buscar en todos los documentos para debug
        final allDocs = await _db.collection('credenciales').get();
        debugPrint('📋 Total documentos en credenciales: ${allDocs.docs.length}');
        for (var doc in allDocs.docs) {
          final data = doc.data();
          debugPrint('  - ID: ${doc.id}');
          debugPrint('    Email: ${data['email']}');
          debugPrint('    Tipo: ${data['tipo']}');
          debugPrint('    Nombre: ${data['nombre']}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error al actualizar credenciales: $e');
      throw Exception('Error al actualizar credenciales: $e');
    }
  }

  /// Envía una notificación a un propietario

  /// Si el condominio no tiene casas, crear datos de prueba
  static Future<void> seedIfEmpty(String condominioId) async {
    final docRef = _db.collection('condominios').doc(condominioId);
    // asegurar que el documento del condominio existe
    await docRef.set({'nombre': condominioId}, SetOptions(merge: true));

    final col = docRef.collection('casas');
    final snap = await col.limit(1).get();
    if (snap.docs.isNotEmpty) return; // ya tiene datos

    final seed = _seedData[condominioId] ?? [];
    for (final casa in seed) {
      await col.doc(casa['numero'].toString()).set(casa);
    }
  }

  static final _seedData = {
    'Los Alamos': [
      {
        'numero': 1,
        'propietario': 'Juan Pérez',
        'residentes': ['Juan Pérez', 'Ana Gómez'],
        'estadoExpensa': 'pagada',
      },
      {
        'numero': 2,
        'propietario': 'Laura Rojas',
        'residentes': ['Laura Rojas', 'Miguel Rojas'],
        'estadoExpensa': 'pendiente',
      },
    ],
    'El Bosque': [
      {
        'numero': 1,
        'propietario': 'Carlos Acosta',
        'residentes': ['Carlos Acosta', 'Lucía Romero'],
        'estadoExpensa': 'pagada',
      },
      {
        'numero': 2,
        'propietario': 'María Torres',
        'residentes': ['María Torres'],
        'estadoExpensa': 'pendiente',
      },
    ],
    'Villa del Rocio': [
      {
        'numero': 1,
        'propietario': 'Fernando Bustamante',
        'residentes': ['Fernando Bustamante', 'Elena Vargas'],
        'estadoExpensa': 'pagada',
      },
      {
        'numero': 2,
        'propietario': 'Jorge Ramírez',
        'residentes': ['Jorge Ramírez', 'Claudia Torrez', 'Mateo Ramírez'],
        'estadoExpensa': 'pendiente',
      },
    ],
  };

  static Future<void> enviarNotificacion({
    required String condominioId,
    required int numero,
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

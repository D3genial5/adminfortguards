import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/condominio_model.dart';
import 'auth_service.dart';
import '../models/casa_model.dart';
import 'dart:developer' as dev;

class CondominioService {
  static final _db = FirebaseFirestore.instance;

  /// Stream de todos los condominios con sus casas desde Firestore.
  static Stream<List<CondominioModel>> streamTodos() {
    return _db.collection('condominios').snapshots().asyncMap((snap) async {
      final list = <CondominioModel>[];
      for (final d in snap.docs) {
        final casasSnap = await d.reference.collection('casas').get();
        final casas = casasSnap.docs
            .map((c) => CasaModel.fromFirestore(c.data(), c.id))
            .toList();
        list.add(CondominioModel.fromFirestore(d.data(), d.id).copyWith(
          casas: casas,
        ));
      }
      return list;
    });
  }

  /// Crea un condominio y sus casas en Firestore.
  /// También genera automáticamente contraseñas para acceso de propietarios.
  static Future<void> agregar(CondominioModel condominio) async {
    final doc = _db.collection('condominios').doc(condominio.nombre);
    
    // Usar toFirestore del modelo actualizado
    final condominioData = condominio.toFirestore();
    condominioData['id'] = condominio.id;
    condominioData['createdAt'] = FieldValue.serverTimestamp();
    
    await doc.set(condominioData);
    
    // 2. Registrar administrador
    final adminEmail = AuthService.generarEmailAdmin(condominio.nombre);
    final adminPassword = AuthService.generarPasswordAdmin(condominio.nombre);
    
    try {
      // Registrar administrador en la colección administradores (con hash)
      await AuthService.registrarAdmin(
        email: adminEmail,
        password: adminPassword,
        nombre: 'Administrador de ${condominio.nombre}',
        condominioId: condominio.nombre,
      );
      
      // Guardar credenciales en colección separada para UI
      await _db.collection('credenciales').add({
        'tipo': 'administrador',
        'email': adminEmail,
        'password': adminPassword, // Solo para mostrar en UI
        'nombre': 'Administrador de ${condominio.nombre}',
        'condominio': condominio.nombre,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      dev.log('Error al crear cuenta de administrador', error: e);
    }
    
    // Crear las casas y sus contraseñas
    for (final casa in condominio.casas) {
      // Generar contraseña para la casa
      final password = AuthService.generarPasswordPropietario(casa.nombre);
      
      // Usar toFirestore del modelo de casa
      final casaData = casa.toFirestore();
      casaData['numero'] = int.tryParse(casa.nombre) ?? casa.nombre;
      casaData['estadoExpensa'] = 'pendiente';
      casaData['password'] = password; // Guardar contraseña en la casa directamente
      
      // Guardar casa en Firestore
      await doc.collection('casas').doc(casa.nombre).set(casaData);
      
      try {
        // Registrar formalmente la contraseña de la casa
        await AuthService.registrarCasa(
          condominioId: condominio.nombre,
          casaId: casa.nombre,
          password: password,
        );
        
        // Guardar las credenciales del propietario en una colección separada
        await _db.collection('credenciales').add({
          'tipo': 'propietario',
          'condominio': condominio.nombre,
          'casa': casa.nombre,
          'password': password,
          'propietario': casa.propietario,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Si falla la creación de credenciales, seguimos con el siguiente
        dev.log('Error al registrar credenciales para casa ${casa.nombre}', error: e);
      }
    }
  }

  /// Migra condominios existentes (ya creados previamente) a la nueva
  /// estructura asegurando que tengan administrador, contraseñas y campos
  /// actualizados.
  static Future<void> migrarExistentes() async {
    final snap = await _db.collection('condominios').get();
    for (final doc in snap.docs) {
      final nombreCondo = (doc.data()['nombre'] ?? doc.id).toString();

      // 0. Asegurar campos base (id y createdAt)
      final dataDoc = doc.data();
      final updates = <String, dynamic>{};
      if (!(dataDoc.containsKey('id'))) {
        updates['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      }
      if (!(dataDoc.containsKey('createdAt'))) {
        updates['createdAt'] = FieldValue.serverTimestamp();
      }
      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
      }

      // 1. Asegurar administrador
      final adminQuery = await _db
          .collection('credenciales')
          .where('tipo', isEqualTo: 'administrador')
          .where('condominio', isEqualTo: nombreCondo)
          .limit(1)
          .get();
      if (adminQuery.docs.isEmpty) {
        final email = AuthService.generarEmailAdmin(nombreCondo);
        final password = AuthService.generarPasswordAdmin(nombreCondo);
        final adminEmail = AuthService.generarEmailAdmin(doc.id);
        final adminPassword = AuthService.generarPasswordAdmin(doc.id);
        await AuthService.registrarAdmin(
          email: adminEmail,
          password: adminPassword,
          nombre: 'Administrador de ${doc.id}',
          condominioId: doc.id,
        );
        await _db.collection('credenciales').add({
          'tipo': 'administrador',
          'email': email,
          'password': password,
          'nombre': 'Administrador de $nombreCondo',
          'condominio': nombreCondo,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Procesar casas
      final casasSnap = await doc.reference.collection('casas').get();
      for (final casaDoc in casasSnap.docs) {
        final casaId = casaDoc.id;
        final datos = casaDoc.data();
        final tienePassword = datos.containsKey('password');
        if (!tienePassword) {
          final password = AuthService.generarPasswordPropietario(casaId);
          await casaDoc.reference.update({'password': password});

          // Registrar credencial propietario si falta
          final credQuery = await _db
              .collection('credenciales')
              .where('tipo', isEqualTo: 'propietario')
              .where('condominio', isEqualTo: nombreCondo)
              .where('casa', isEqualTo: casaId)
              .limit(1)
              .get();
          if (credQuery.docs.isEmpty) {
            await _db.collection('credenciales').add({
              'tipo': 'propietario',
              'condominio': nombreCondo,
              'casa': casaId,
              'password': password,
              'propietario': datos['propietario'] ?? '',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }
  }

  /// Elimina un condominio y todas sus casas de Firestore.
  static Future<void> eliminar(String condominioId) async {
    // Obtener referencia al documento del condominio
    final docRef = _db.collection('condominios').doc(condominioId);
    
    // Primero eliminar todas las subcollecciones
    // 1. Eliminar todas las casas
    final casasSnap = await docRef.collection('casas').get();
    final batch = _db.batch();
    
    for (final casaDoc in casasSnap.docs) {
      batch.delete(casaDoc.reference);
    }
    
    // Ejecutar el batch para eliminar todas las casas
    await batch.commit();
    
    // 2. Eliminar credenciales asociadas (administrador y propietarios)
    final credSnap = await _db
        .collection('credenciales')
        .where('condominio', isEqualTo: condominioId)
        .get();
    final credBatch = _db.batch();
    for (final c in credSnap.docs) {
      credBatch.delete(c.reference);
    }
    await credBatch.commit();

    // 3. Eliminar administradores asociados
    final adminSnap = await _db
        .collection('administradores')
        .where('condominio', isEqualTo: condominioId)
        .get();
    final adminBatch = _db.batch();
    for (final a in adminSnap.docs) {
      adminBatch.delete(a.reference);
    }
    await adminBatch.commit();

    // 4. Eliminar el documento del condominio
    await docRef.delete();
  }
}

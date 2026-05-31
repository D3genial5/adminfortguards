import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/condominio_model.dart';
import 'auth_service.dart';
import '../models/casa_model.dart';
import '../core/app_log.dart';

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
  /// Genera contraseñas seguras hasheadas. Las contraseñas temporales se
  /// devuelven en el resultado para mostrarlas una sola vez al admin.
  static Future<Map<String, List<Map<String, String>>>> agregar(
      CondominioModel condominio) async {
    final doc = _db.collection('condominios').doc(condominio.nombre);

    final condominioData = condominio.toFirestore();
    condominioData['id'] = condominio.id;
    condominioData['createdAt'] = FieldValue.serverTimestamp();

    await doc.set(condominioData);

    // Credenciales temporales para mostrar una sola vez
    final credencialesGeneradas = <Map<String, String>>[];

    // 1. Registrar administrador con Firebase Auth
    final adminEmail = AuthService.generarEmailAdmin(condominio.nombre);
    final adminPassword = AuthService.generarPasswordSeguro();

    try {
      await AuthService.registrarAdmin(
        email: adminEmail,
        password: adminPassword,
        nombre: 'Administrador de ${condominio.nombre}',
        condominioId: condominio.nombre,
      );
      credencialesGeneradas.add({
        'tipo': 'administrador',
        'email': adminEmail,
        'password': adminPassword,
        'condominio': condominio.nombre,
      });
    } catch (e) {
      AppLog.log('Error al crear cuenta de administrador', error: e);
    }

    // 2. Crear las casas con contraseñas hasheadas
    for (final casa in condominio.casas) {
      final password = AuthService.generarPasswordSeguro(length: 10);
      final realSalt = AuthService.generarPasswordSeguro(length: 16);
      final hash = AuthService.hashWithSalt(password, realSalt);

      final casaData = casa.toFirestore();
      casaData['numero'] = int.tryParse(casa.nombre) ?? casa.nombre;
      casaData['estadoExpensa'] = 'pendiente';
      casaData['passwordHash'] = hash;
      casaData['passwordSalt'] = realSalt;
      // No almacenar password en texto plano

      await doc.collection('casas').doc(casa.nombre).set(casaData);

      credencialesGeneradas.add({
        'tipo': 'propietario',
        'casa': casa.nombre,
        'password': password,
        'condominio': condominio.nombre,
        'propietario': casa.propietario,
      });
    }

    return {'credenciales': credencialesGeneradas};
  }

  /// Migra condominios existentes: asegura campos base y hashea passwords legacy.
  /// NO crea credenciales en colección separada (ese flujo fue eliminado).
  static Future<void> migrarExistentes() async {
    final snap = await _db.collection('condominios').get();
    for (final doc in snap.docs) {
      // 0. Asegurar campos base
      final dataDoc = doc.data();
      final updates = <String, dynamic>{};
      if (!dataDoc.containsKey('id')) {
        updates['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      }
      if (!dataDoc.containsKey('createdAt')) {
        updates['createdAt'] = FieldValue.serverTimestamp();
      }
      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
      }

      // 1. Migrar contraseñas de casas: plain-text → hash con sal
      final casasSnap = await doc.reference.collection('casas').get();
      for (final casaDoc in casasSnap.docs) {
        final datos = casaDoc.data();
        final hasLegacyPassword = datos.containsKey('password') && !datos.containsKey('passwordHash');
        if (hasLegacyPassword) {
          final plainPassword = datos['password'] as String;
          final salt = AuthService.generarPasswordSeguro(length: 16);
          final hash = AuthService.hashWithSalt(plainPassword, salt);
          await casaDoc.reference.update({
            'passwordHash': hash,
            'passwordSalt': salt,
            'password': FieldValue.delete(),
          });
          AppLog.log('Migrada casa ${casaDoc.id} en ${doc.id} a hash con sal');
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
    
    // 2. Eliminar administradores asociados
    final adminSnap = await _db
        .collection('administradores')
        .where('condominio', isEqualTo: condominioId)
        .get();
    final adminBatch = _db.batch();
    for (final a in adminSnap.docs) {
      adminBatch.delete(a.reference);
    }
    await adminBatch.commit();

    // 3. Eliminar el documento del condominio
    await docRef.delete();
  }
}

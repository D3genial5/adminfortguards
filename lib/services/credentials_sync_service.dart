import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Servicio para sincronizar contraseñas entre administradores y credenciales
/// 
/// Este servicio NO modifica la colección 'administradores', solo sincroniza
/// los cambios hacia la colección 'credenciales' para mantener consistencia.
class CredentialsSyncService {
  final FirebaseFirestore _db;

  CredentialsSyncService({FirebaseFirestore? db}) 
      : _db = db ?? FirebaseFirestore.instance;

  /// Sincroniza la contraseña del administrador en la colección 'credenciales'
  /// 
  /// Esta función debe llamarse DESPUÉS de que el cambio de contraseña en
  /// 'administradores' haya sido exitoso.
  /// 
  /// Parámetros:
  /// - [condominio]: Nombre del condominio (ej. "Ventura")
  /// - [email]: Email del administrador (ej. "admin.ventura@fortguards.com")
  /// - [newPassword]: Nueva contraseña en texto plano
  /// - [adminUid]: UID del administrador que realiza el cambio (para auditoría)
  /// - [createIfMissing]: Si es true, crea la credencial si no existe (default: true)
  /// 
  /// Nota sobre índice compuesto:
  /// Esta query requiere un índice compuesto en Firestore:
  /// Collection: credenciales
  /// Fields: tipo (Ascending), email (Ascending), condominio (Ascending)
  /// 
  /// Si Firestore muestra un error de índice faltante, sigue el link que proporciona
  /// o créalo manualmente en Firebase Console > Firestore > Indexes
  Future<void> updateAdminPasswordAndSyncCredentials({
    required String condominio,
    required String email,
    required String newPassword,
    required String adminUid,
    bool createIfMissing = true,
  }) async {
    final col = _db.collection('credenciales');

    try {
      debugPrint('🔄 Sincronizando credencial para: $email en $condominio');

      // 1) Buscar documentos de credenciales del administrador
      // Intento principal con índice compuesto
      QuerySnapshot<Map<String, dynamic>> q;
      List<QueryDocumentSnapshot<Map<String, dynamic>>> matches = [];
      try {
        q = await col
            .where('tipo', isEqualTo: 'administrador')
            .where('email', isEqualTo: email)
            .where('condominio', isEqualTo: condominio)
            .get(const GetOptions(source: Source.serverAndCache));
        matches = q.docs;
      } on FirebaseException catch (e) {
        // Fallback si falta índice
        if (e.code == 'failed-precondition' || e.message?.contains('index') == true) {
          debugPrint('⚠️ Faltó índice compuesto, usando fallback por email y filtrando en memoria');
          final emailOnly = await col
              .where('email', isEqualTo: email)
              .get(const GetOptions(source: Source.serverAndCache));
          matches = emailOnly.docs.where((d) {
            final data = d.data();
            return (data['tipo'] == 'administrador') && (data['condominio'] == condominio);
          }).toList();
        } else {
          rethrow;
        }
      }

      debugPrint('📊 Documentos encontrados: ${matches.length}');

      final batch = _db.batch();
      int operaciones = 0;

      if (matches.isEmpty && createIfMissing) {
        // 2) Crear credencial si no existe (Opción A - por defecto)
        debugPrint('➕ Creando credencial faltante...');
        final docRef = col.doc();
        
        batch.set(docRef, {
          'condominio': condominio,
          'email': email,
          'nombre': 'Administrador de $condominio',
          'password': newPassword, // Texto plano según requerimiento
          'tipo': 'administrador',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': adminUid,
        });

        // Crear entrada en historial
        batch.set(docRef.collection('historial').doc(), {
          'accion': 'password_update',
          'by': adminUid,
          'at': FieldValue.serverTimestamp(),
          'detalle': 'Credencial creada y sincronizada automáticamente',
        });

        operaciones++;
        debugPrint('✅ Credencial creada: ${docRef.id}');

        // Opción B (comentada): No crear, solo notificar
        // throw CredentialNotFoundException(
        //   'No se encontró credencial para $email en $condominio'
        // );
      } else {
        // 3) Actualizar todos los documentos coincidentes
        debugPrint('🔄 Actualizando ${matches.length} credencial(es)...');
        
        for (final doc in matches) {
          batch.update(doc.reference, {
            'password': newPassword,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': adminUid,
          });

          // Crear entrada en historial para auditoría
          batch.set(doc.reference.collection('historial').doc(), {
            'accion': 'password_update',
            'by': adminUid,
            'at': FieldValue.serverTimestamp(),
            'detalle': 'Contraseña actualizada',
          });

          operaciones++;
          debugPrint('✅ Actualizada credencial: ${doc.id}');
        }
      }

      // 4) Ejecutar todas las operaciones en batch (atómico)
      await batch.commit();
      debugPrint('✅ Sincronización completada: $operaciones operación(es)');

    } on FirebaseException catch (e) {
      // Error específico de Firebase
      debugPrint('❌ Error Firebase al sincronizar: ${e.code} - ${e.message}');
      
      if (e.code == 'failed-precondition' || e.message?.contains('index') == true) {
        throw Exception(
          'Se requiere crear un índice compuesto en Firestore.\n'
          'Sigue el enlace que aparece en la consola o créalo manualmente:\n'
          'Collection: credenciales\n'
          'Fields: tipo (Asc), email (Asc), condominio (Asc)'
        );
      }
      
      throw Exception('No se pudo sincronizar la credencial: ${e.message}');
    } catch (e) {
      // Error genérico
      debugPrint('❌ Error inesperado al sincronizar: $e');
      throw Exception('Error inesperado al sincronizar credenciales: $e');
    }
  }

  /// Verifica si existe una credencial para el administrador
  /// Útil para debugging o validación previa
  Future<bool> existsCredentialForAdmin({
    required String condominio,
    required String email,
  }) async {
    try {
      final q = await _db
          .collection('credenciales')
          .where('tipo', isEqualTo: 'administrador')
          .where('email', isEqualTo: email)
          .where('condominio', isEqualTo: condominio)
          .limit(1)
          .get();

      return q.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error verificando credencial: $e');
      return false;
    }
  }

  /// Obtiene el historial de cambios de una credencial
  /// Útil para auditoría
  Future<List<Map<String, dynamic>>> getCredentialHistory({
    required String credentialId,
    int limit = 10,
  }) async {
    try {
      final snapshot = await _db
          .collection('credenciales')
          .doc(credentialId)
          .collection('historial')
          .orderBy('at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error obteniendo historial: $e');
      return [];
    }
  }
}

/// Excepción personalizada para cuando no se encuentra una credencial
class CredentialNotFoundException implements Exception {
  final String message;
  CredentialNotFoundException(this.message);

  @override
  String toString() => 'CredentialNotFoundException: $message';
}

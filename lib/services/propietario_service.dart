import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:developer' as dev;

/// Servicio para gestionar propietarios y sus credenciales
class PropietarioService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene los datos del propietario de una casa
  static Future<Map<String, dynamic>?> obtenerPropietario({
    required String condominio,
    required String casa,
  }) async {
    try {
      final query = await _db
          .collection('credenciales')
          .where('tipo', isEqualTo: 'propietario')
          .where('condominio', isEqualTo: condominio)
          .where('casa', isEqualTo: casa)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }
      return null;
    } catch (e) {
      dev.log('❌ Error obteniendo propietario: $e');
      return null;
    }
  }

  /// Cambia la contraseña del propietario
  /// Actualiza tanto en 'credenciales' como en 'casas'
  static Future<bool> cambiarPasswordPropietario({
    required String condominio,
    required String casa,
    required String nuevaPassword,
    required String adminUid,
    bool createIfMissing = true,
  }) async {
    try {
      dev.log('🔄 Cambiando contraseña para propietario de casa $casa');

      // 1. Buscar credencial del propietario
      final credQuery = await _db
          .collection('credenciales')
          .where('tipo', isEqualTo: 'propietario')
          .where('condominio', isEqualTo: condominio)
          .where('casa', isEqualTo: casa)
          .limit(1)
          .get();

      final batch = _db.batch();

      if (credQuery.docs.isEmpty) {
        if (!createIfMissing) {
          dev.log('⚠️ No se encontró credencial para propietario de casa $casa');
          return false;
        }

        // Crear credencial si no existe
        final condoDoc = _db.collection('condominios').doc(condominio);
        final casaRef = condoDoc.collection('casas').doc(casa);
        final casaSnap = await casaRef.get();
        final propietario = (casaSnap.data() ?? {})['propietario'] ?? '';

        final credRef = _db.collection('credenciales').doc();

        // Set de credencial mínima
        batch.set(credRef, {
          'tipo': 'propietario',
          'condominio': condominio,
          'casa': casa,
          'password': nuevaPassword,
          'propietario': propietario,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': adminUid,
        });

        // Historial
        batch.set(credRef.collection('historial').doc(), {
          'accion': 'password_update',
          'by': adminUid,
          'at': FieldValue.serverTimestamp(),
          'detalle': 'Credencial creada y contraseña actualizada por administrador',
        });

        // Actualizar también en 'casas' si existe
        if (casaSnap.exists) {
          batch.update(casaRef, {
            'password': nuevaPassword,
            'fechaActualizacion': FieldValue.serverTimestamp(),
          });
          dev.log('✅ Contraseña actualizada en casas');
        }

        await batch.commit();
        dev.log('✅ Credencial creada y contraseña del propietario actualizada');
        return true;
      }

      // 2. Actualizar en credenciales
      final credRef = credQuery.docs.first.reference;
      batch.update(credRef, {
        'password': nuevaPassword,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': adminUid,
      });

      // 3. Registrar en historial de credenciales
      batch.set(credRef.collection('historial').doc(), {
        'accion': 'password_update',
        'by': adminUid,
        'at': FieldValue.serverTimestamp(),
        'detalle': 'Contraseña actualizada por administrador',
      });

      // 4. Actualizar también en la colección 'casas' si existe
      try {
        final condoDoc = _db.collection('condominios').doc(condominio);
        final casaRef = condoDoc.collection('casas').doc(casa);
        final casaSnap = await casaRef.get();

        if (casaSnap.exists) {
          batch.update(casaRef, {
            'password': nuevaPassword,
            'fechaActualizacion': FieldValue.serverTimestamp(),
          });
          dev.log('✅ Contraseña actualizada en casas');
        }
      } catch (e) {
        dev.log('⚠️ No se pudo actualizar en casas: $e');
        // Continuar de todas formas, lo importante es credenciales
      }

      // 5. Ejecutar batch
      await batch.commit();
      dev.log('✅ Contraseña del propietario actualizada exitosamente');
      return true;

    } catch (e) {
      dev.log('❌ Error al cambiar contraseña: $e');
      return false;
    }
  }

  /// Obtiene el historial de cambios de contraseña de un propietario
  static Future<List<Map<String, dynamic>>> obtenerHistorialPropietario({
    required String condominio,
    required String casa,
  }) async {
    try {
      final query = await _db
          .collection('credenciales')
          .where('tipo', isEqualTo: 'propietario')
          .where('condominio', isEqualTo: condominio)
          .where('casa', isEqualTo: casa)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return [];

      final credRef = query.docs.first.reference;
      final historialSnap = await credRef
          .collection('historial')
          .orderBy('at', descending: true)
          .limit(5)
          .get();

      return historialSnap.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      dev.log('Error obteniendo historial: $e');
      return [];
    }
  }

  /// Valida que la nueva contraseña cumpla con requisitos mínimos
  static bool validarPassword(String password) {
    if (password.isEmpty) return false;
    if (password.length < 4) return false;
    return true;
  }

  /// Obtiene mensaje de error para validación
  static String? obtenerErrorPassword(String password) {
    if (password.isEmpty) return 'La contraseña no puede estar vacía';
    if (password.length < 4) return 'La contraseña debe tener al menos 4 caracteres';
    return null;
  }
}

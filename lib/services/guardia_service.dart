import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guardia_model.dart';
import 'auth_service.dart';
import 'dart:developer' as dev;

class GuardiaService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'guardias';

  // Crear nuevo guardia
  static Future<String> crear(GuardiaModel guardia) async {
    try {
      final docRef = await _firestore.collection(_collection).add(guardia.toFirestore());
      
      // Generar credenciales automáticamente
      final email = AuthService.generarEmailGuardia(guardia.nombre, guardia.apellido, guardia.condominioId);
      final password = AuthService.generarPasswordGuardia(guardia.nombre, guardia.apellido);
      
      try {
        // Registrar credenciales del guardia
        await AuthService.registrarGuardia(
          guardiaId: docRef.id,
          email: email,
          password: password,
          nombre: guardia.nombre,
          apellido: guardia.apellido,
          condominioId: guardia.condominioId,
        );
        
        // Guardar credenciales en colección separada para UI
        await _firestore.collection('credenciales').add({
          'tipo': 'guardia',
          'nombre': '${guardia.nombre} ${guardia.apellido}',
          'email': email,
          'password': password,
          'condominio': guardia.condominioId,
          'guardiaId': docRef.id,
          'perfil': guardia.tipoPerfil,
          'turno': guardia.turno,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        dev.log('Credenciales generadas para guardia: $email');
      } catch (e) {
        dev.log('Error al crear credenciales de guardia', error: e);
        // No fallar la creación del guardia por error en credenciales
      }
      
      return docRef.id;
    } catch (e) {
      throw Exception('Error al crear guardia: $e');
    }
  }

  // Obtener guardias por condominio
  static Future<List<GuardiaModel>> obtenerPorCondominio(String condominioId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .get();

      final guardias = querySnapshot.docs
          .map((doc) => GuardiaModel.fromFirestore(doc.data(), doc.id))
          .toList();
      
      // Ordenar en código
      guardias.sort((a, b) => a.nombre.compareTo(b.nombre));
      return guardias;
    } catch (e) {
      throw Exception('Error al obtener guardias: $e');
    }
  }

  // Stream de guardias por condominio
  static Stream<List<GuardiaModel>> streamPorCondominio(String condominioId) {
    return _firestore
        .collection(_collection)
        .where('condominioId', isEqualTo: condominioId)
        .snapshots()
        .map((snapshot) {
          final guardias = snapshot.docs
              .map((doc) => GuardiaModel.fromFirestore(doc.data(), doc.id))
              .toList();
          // Ordenar en código
          guardias.sort((a, b) => a.nombre.compareTo(b.nombre));
          return guardias;
        });
  }

  // Obtener guardias activos por turno
  static Future<List<GuardiaModel>> obtenerActivosPorTurno(String condominioId, String turno) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('condominioId', isEqualTo: condominioId)
          .where('turno', isEqualTo: turno)
          .where('activo', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => GuardiaModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener guardias activos: $e');
    }
  }

  // Actualizar guardia
  static Future<void> actualizar(String id, GuardiaModel guardia) async {
    try {
      await _firestore.collection(_collection).doc(id).update(guardia.toFirestore());
    } catch (e) {
      throw Exception('Error al actualizar guardia: $e');
    }
  }

  // Activar/Desactivar guardia
  static Future<void> cambiarEstado(String id, bool activo) async {
    try {
      await _firestore.collection(_collection).doc(id).update({'activo': activo});
    } catch (e) {
      throw Exception('Error al cambiar estado del guardia: $e');
    }
  }

  // Eliminar guardia
  static Future<void> eliminar(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Error al eliminar guardia: $e');
    }
  }

  // Obtener guardia por ID
  static Future<GuardiaModel?> obtenerPorId(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return GuardiaModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener guardia: $e');
    }
  }

  // Verificar si email ya existe
  static Future<bool> emailExiste(String email, String condominioId, {String? excludeId}) async {
    try {
      var query = _firestore
          .collection(_collection)
          .where('email', isEqualTo: email)
          .where('condominioId', isEqualTo: condominioId);

      final querySnapshot = await query.get();
      
      if (excludeId != null) {
        return querySnapshot.docs.any((doc) => doc.id != excludeId);
      }
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error al verificar email: $e');
    }
  }

  // Obtener guardias por tipo de turno
  static Future<List<GuardiaModel>> obtenerGuardiasPorTurno(String tipoTurno) async {
    try {
      final bool esDiurno = tipoTurno.toLowerCase() == 'diurno';
      
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('activo', isEqualTo: true)
          .where('turno', isEqualTo: esDiurno ? 'diurno' : 'nocturno')
          .get();

      return querySnapshot.docs
          .map((doc) => GuardiaModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener guardias por turno: $e');
    }
  }

  // Obtener estadísticas de guardias
  static Future<Map<String, int>> obtenerEstadisticas(String condominioId) async {
    try {
      final guardias = await obtenerPorCondominio(condominioId);
      
      return {
        'total': guardias.length,
        'activos': guardias.where((g) => g.activo).length,
        'diurnos': guardias.where((g) => g.esDiurno && g.activo).length,
        'nocturnos': guardias.where((g) => g.esNocturno && g.activo).length,
      };
    } catch (e) {
      throw Exception('Error al obtener estadísticas: $e');
    }
  }
}

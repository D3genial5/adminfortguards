import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio para purgar datos huérfanos o inconsistentes
class PurgarService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Purga credenciales que no tienen condominio asociado
  static Future<int> purgarCredencialesHuerfanas() async {
    int eliminadas = 0;
    
    // Obtener todas las credenciales
    final credSnap = await _db.collection('credenciales').get();
    
    // Obtener todos los condominios existentes
    final condominiosSnap = await _db.collection('condominios').get();
    final condominiosExistentes = condominiosSnap.docs.map((doc) => doc.id).toSet();
    
    final batch = _db.batch();
    
    for (final credDoc in credSnap.docs) {
      final data = credDoc.data();
      final condominio = data['condominio']?.toString();
      
      if (condominio == null || !condominiosExistentes.contains(condominio)) {
        batch.delete(credDoc.reference);
        eliminadas++;
      }
    }
    
    if (eliminadas > 0) {
      await batch.commit();
    }
    
    return eliminadas;
  }

  /// Purga administradores que no tienen condominio asociado
  static Future<int> purgarAdministradoresHuerfanos() async {
    int eliminados = 0;
    
    // Obtener todos los administradores
    final adminSnap = await _db.collection('administradores').get();
    
    // Obtener todos los condominios existentes
    final condominiosSnap = await _db.collection('condominios').get();
    final condominiosExistentes = condominiosSnap.docs.map((doc) => doc.id).toSet();
    
    final batch = _db.batch();
    
    for (final adminDoc in adminSnap.docs) {
      final data = adminDoc.data();
      final condominio = data['condominio']?.toString();
      
      if (condominio == null || !condominiosExistentes.contains(condominio)) {
        batch.delete(adminDoc.reference);
        eliminados++;
      }
    }
    
    if (eliminados > 0) {
      await batch.commit();
    }
    
    return eliminados;
  }

  /// Purga todo: credenciales y administradores huérfanos
  static Future<Map<String, int>> purgarTodo() async {
    final credenciales = await purgarCredencialesHuerfanas();
    final administradores = await purgarAdministradoresHuerfanos();
    
    return {
      'credenciales': credenciales,
      'administradores': administradores,
    };
  }
}

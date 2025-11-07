import 'package:cloud_firestore/cloud_firestore.dart';

/// Script para limpiar credenciales duplicadas
/// Ejecutar una sola vez desde main.dart o una pantalla de debug
Future<void> limpiarCredencialiesDuplicadas() async {
  print('🧹 Iniciando limpieza de duplicados...');
  
  try {
    final firestore = FirebaseFirestore.instance;
    final credencialesSnapshot = await firestore.collection('credenciales').get();
    
    // Agrupar por email
    final Map<String, List<QueryDocumentSnapshot>> porEmail = {};
    
    for (var doc in credencialesSnapshot.docs) {
      final data = doc.data();
      final email = data['email']?.toString().toLowerCase() ?? '';
      
      if (email.isNotEmpty) {
        if (!porEmail.containsKey(email)) {
          porEmail[email] = [];
        }
        porEmail[email]!.add(doc);
      }
    }
    
    // Encontrar y eliminar duplicados
    int eliminados = 0;
    
    for (var entry in porEmail.entries) {
      final email = entry.key;
      final docs = entry.value;
      
      if (docs.length > 1) {
        print('⚠️ Duplicado encontrado: $email (${docs.length} registros)');
        
        // Ordenar por fecha de creación (si existe) o mantener el primero
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aCreated = aData?['createdAt'] as Timestamp?;
          final bCreated = bData?['createdAt'] as Timestamp?;
          
          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;
          
          return aCreated.compareTo(bCreated);
        });
        
        // Mantener el primero (más antiguo), eliminar el resto
        for (int i = 1; i < docs.length; i++) {
          print('   🗑️ Eliminando duplicado: ${docs[i].id}');
          await docs[i].reference.delete();
          eliminados++;
        }
        
        print('   ✅ Mantenido: ${docs[0].id}');
      }
    }
    
    print('✅ Limpieza completada: $eliminados duplicados eliminados');
    
  } catch (e) {
    print('❌ Error al limpiar duplicados: $e');
  }
}

/// Función para eliminar un credencial específico por ID
Future<void> eliminarCredencialPorId(String docId) async {
  try {
    await FirebaseFirestore.instance
        .collection('credenciales')
        .doc(docId)
        .delete();
    print('✅ Credencial $docId eliminado');
  } catch (e) {
    print('❌ Error al eliminar: $e');
  }
}

/// Función para listar todas las credenciales
Future<void> listarCredenciales() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('credenciales')
        .get();
    
    print('📋 Total credenciales: ${snapshot.docs.length}');
    print('━' * 60);
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      print('ID: ${doc.id}');
      print('Email: ${data['email']}');
      print('Tipo: ${data['tipo']}');
      print('Password: ${data['password']}');
      print('Condominio: ${data['condominio']}');
      if (data['casa'] != null) {
        print('Casa: ${data['casa']}');
      }
      print('━' * 60);
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

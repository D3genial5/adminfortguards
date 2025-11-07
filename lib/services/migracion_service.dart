import '../models/condominio_model.dart';
import 'condominio_service.dart';
import 'auth_service.dart';

/// Servicio de utilidades para migraciones puntuales.
///
/// Uso previsto: ejecutar desde un comando temporal en la app o
/// desde un script independiente enviando la lista de condominios
/// que quieras migrar. Aprovecha el método agregar() ya existente
/// para garantizar que la estructura y credenciales se generan
/// exactamente igual que para los condominios nuevos.
import 'package:cloud_firestore/cloud_firestore.dart';

class MigracionService {
  /// Migrar condominios existentes a la nueva estructura.
  ///
  /// Recorre la lista y llama a CondominioService.agregar() para cada
  /// elemento. Si el condominio ya existe, lo omite (para evitar duplicados).
  /// Ejecuta la migración sólo la primera vez.
  ///
  /// Verifica en la colección `config/migracion` si ya se marcó como
  /// completada. Si no, llama a `CondominioService.migrarExistentes()` y
  /// establece el flag. El proceso es idempotente; sólo se marcará como
  /// hecho cuando termine sin lanzar excepciones.
  static Future<void> runOnce() async {
    final db = FirebaseFirestore.instance;
    final docRef = db.collection('config').doc('migracion');
    final doc = await docRef.get();
    final hecha = doc.exists && (doc.data()?['hecha'] ?? false) == true;

    if (hecha) return; // Ya migrado anteriormente

    // Migrar estructuras de condominios
    await CondominioService.migrarExistentes();

    // Migrar hashes de administradores (contraseñas planas -> hash)
    await AuthService.migrarPasswordsAHash();

    await docRef.set({
      'hecha': true,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> migrarCondominios(List<CondominioModel> existentes) async {
    for (final condo in existentes) {
      try {
        await CondominioService.agregar(condo);
      } catch (e) {
        // Si falla la inserción (por ejemplo si ya existe) simplemente seguimos
        // con el siguiente para no detener la migración completa.
        // En una migración real podrías registrar un log más detallado.
        // ignore: avoid_print
        print('Error migrando ${condo.nombre}: $e');
      }
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/app_log.dart';
import 'auth_service.dart';

/// Servicio para gestionar propietarios desde la app de admin.
/// Los datos viven en condominios/{id}/casas/{id} — no en credenciales.
class PropietarioService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Obtiene los datos del propietario de una casa
  static Future<Map<String, dynamic>?> obtenerPropietario({
    required String condominio,
    required String casa,
  }) async {
    try {
      final casaDoc = await _db
          .collection('condominios')
          .doc(condominio)
          .collection('casas')
          .doc(casa)
          .get();

      if (!casaDoc.exists) return null;

      return {
        'id': casaDoc.id,
        ...casaDoc.data()!,
      };
    } catch (e) {
      AppLog.log('Error obteniendo propietario: $e');
      return null;
    }
  }

  /// Resetea la contraseña del propietario (genera una nueva temporal).
  /// Devuelve la contraseña temporal para mostrar una sola vez.
  static Future<String?> resetPasswordPropietario({
    required String condominio,
    required String casa,
  }) async {
    try {
      final newPassword = await AuthService.resetPasswordPropietario(
        condominioId: condominio,
        casaId: casa,
      );
      AppLog.log('Password reseteada para casa $casa en $condominio');
      return newPassword;
    } catch (e) {
      AppLog.log('Error al resetear password: $e');
      return null;
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

  /// Cambia la contraseña del propietario a una elegida por el admin.
  /// Seguro: delega en AuthService que guarda solo el hash PBKDF2 (sin texto
  /// plano). [adminUid] y [createIfMissing] se mantienen por compatibilidad.
  static Future<bool> cambiarPasswordPropietario({
    required String condominio,
    required String casa,
    required String nuevaPassword,
    String? adminUid,
    bool createIfMissing = false,
  }) async {
    try {
      await AuthService.changePasswordPropietario(
        condominioId: condominio,
        casaId: casa,
        newPassword: nuevaPassword,
      );
      return true;
    } catch (e) {
      AppLog.log('Error cambiando password de propietario: $e');
      return false;
    }
  }

  /// Historial de cambios de contraseña.
  /// En v2 no se conserva historial de contraseñas en texto plano, por lo que
  /// devuelve una lista vacía (la UI lo trata como "sin historial").
  static Future<List<Map<String, dynamic>>> obtenerHistorialPropietario({
    required String condominio,
    required String casa,
  }) async {
    return <Map<String, dynamic>>[];
  }
}

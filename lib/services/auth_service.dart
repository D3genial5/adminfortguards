import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../core/app_log.dart';
import 'dart:math' as math;

/// Servicio de autenticación seguro para FortGuards.
///
/// - Admin y guardia: Firebase Auth (con migración automática desde hash legacy).
/// - Propietario: SHA256 + salt almacenado en Firestore (sin email individual).
class AuthService {
  static FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      AppLog.log('Firebase no inicializado', error: e);
      return null;
    }
  }

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // ──────────────────────────────────────────────
  // Hashing utilities
  // ──────────────────────────────────────────────

  /// Hash SHA256 sin sal — solo para verificar contraseñas legacy durante migración.
  static String _hashLegacy(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Hash SHA256 con sal — usado para propietarios.
  static String hashWithSalt(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  static String _generateSalt() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Genera una contraseña aleatoria segura.
  static String generarPasswordSeguro({int length = 12}) {
    const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = math.Random.secure();
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ══════════════════════════════════════════════
  // ADMIN — Firebase Auth
  // ══════════════════════════════════════════════

  /// Registra un administrador en Firebase Auth + Firestore.
  static Future<void> registrarAdmin({
    required String email,
    required String password,
    required String nombre,
    required String condominioId,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final db = _db;
      if (db == null || credential.user == null) return;

      await db.collection('administradores').doc(credential.user!.uid).set({
        'email': email,
        'nombre': nombre,
        'condominio': condominioId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        AppLog.log('Admin ya registrado en Firebase Auth: $email');
        return;
      }
      rethrow;
    } catch (e) {
      AppLog.log('Error al registrar administrador', error: e);
      rethrow;
    }
  }

  /// Login de administrador.
  /// 1. Intenta Firebase Auth.
  /// 2. Si falla, verifica hash legacy en Firestore y migra a Firebase Auth.
  static Future<Map<String, dynamic>?> loginAdmin({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Firebase Auth
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential.user != null) {
          // Asegura que el custom claim (superadmin/admin) esté seteado y en el
          // token. No dependemos del trigger syncAdminClaims (que puede no
          // dispararse en bases recién creadas): refreshMyClaims lo setea
          // server-side desde el doc, y forzamos refresh del token.
          await _sincronizarClaims(credential.user!);
          return await _getAdminData(credential.user!.uid, email);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found' &&
            e.code != 'wrong-password' &&
            e.code != 'invalid-credential') {
          AppLog.log('Firebase Auth error: ${e.code}', error: e);
        }
      }

      // 2. Legacy migration
      final db = _db;
      if (db == null) return null;

      final querySnapshot = await db
          .collection('administradores')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final adminDoc = querySnapshot.docs.first;
        final adminData = adminDoc.data();
        final storedHash = adminData['passwordHash'] as String?;

        if (storedHash != null && _hashLegacy(password) == storedHash) {
          // Hash legacy coincide → migrar a Firebase Auth
          try {
            final credential = await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            if (credential.user != null) {
              final cleanData = Map<String, dynamic>.from(adminData);
              cleanData.remove('passwordHash');
              cleanData.remove('password');
              cleanData['migratedAt'] = FieldValue.serverTimestamp();

              await db
                  .collection('administradores')
                  .doc(credential.user!.uid)
                  .set(cleanData);

              if (adminDoc.id != credential.user!.uid) {
                await adminDoc.reference.delete();
              }
              AppLog.log('Admin migrado a Firebase Auth: $email');
              return {
                'id': credential.user!.uid,
                ...cleanData,
              };
            }
          } on FirebaseAuthException catch (e) {
            if (e.code == 'email-already-in-use') {
              // Ya existe en Firebase Auth pero no pudimos loguear — posible
              // desincronización. Devolvemos datos legacy.
              AppLog.log('Admin existe en Auth pero fallo login, devolviendo legacy');
            }
          }

          return {'id': adminDoc.id, ...adminData};
        }
      }

      return null;
    } catch (e) {
      AppLog.log('Error en login admin', error: e);
      return null;
    }
  }

  /// Llama a la Cloud Function refreshMyClaims (setea el custom claim
  /// role/condominio desde el doc del usuario) y fuerza refresh del ID token
  /// para que el claim quede disponible en esta sesión. No bloquea el login si
  /// falla (ej. red): el claim puede sincronizarse en el próximo intento.
  static Future<void> _sincronizarClaims(User user) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      await functions.httpsCallable('refreshMyClaims').call();
      await user.getIdToken(true); // refresca el token con el claim nuevo
    } catch (e) {
      AppLog.log('No se pudo sincronizar claims (no bloquea login)', error: e);
    }
  }

  static Future<Map<String, dynamic>?> _getAdminData(
      String uid, String email) async {
    final db = _db;
    if (db == null) return null;

    // Buscar por UID primero
    final adminDoc = await db.collection('administradores').doc(uid).get();
    if (adminDoc.exists) {
      return {'id': uid, ...adminDoc.data()!};
    }

    // Fallback: buscar por email
    final q = await db
        .collection('administradores')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      return {'id': q.docs.first.id, ...q.docs.first.data()};
    }

    return null;
  }

  // ══════════════════════════════════════════════
  // GUARDIA — Firebase Auth
  // ══════════════════════════════════════════════

  /// Registra un guardia en Firebase Auth + Firestore.
  static Future<void> registrarGuardia({
    required String guardiaId,
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required String condominioId,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final db = _db;
      if (db == null) return;

      await db.collection('guardias_auth').doc(credential.user!.uid).set({
        'guardiaId': guardiaId,
        'email': email,
        'nombre': nombre,
        'apellido': apellido,
        'condominio': condominioId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        AppLog.log('Guardia ya registrado: $email');
        return;
      }
      AppLog.log('Error al registrar guardia', error: e);
    } catch (e) {
      AppLog.log('Error al registrar guardia', error: e);
    }
  }

  /// Login de guardia con migración automática.
  static Future<Map<String, dynamic>?> loginGuardia({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Firebase Auth
      try {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (credential.user != null) {
          await _sincronizarClaims(credential.user!);
          return await _getGuardiaData(email);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found' &&
            e.code != 'wrong-password' &&
            e.code != 'invalid-credential') {
          AppLog.log('Firebase Auth error guardia: ${e.code}');
        }
      }

      // 2. Legacy migration
      final db = _db;
      if (db == null) return null;

      final querySnapshot = await db
          .collection('guardias_auth')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final storedHash = data['passwordHash'] as String?;

        if (storedHash != null && _hashLegacy(password) == storedHash) {
          try {
            await _auth.createUserWithEmailAndPassword(
                email: email, password: password);
            AppLog.log('Guardia migrado a Firebase Auth: $email');
          } on FirebaseAuthException catch (_) {}

          return await _getGuardiaData(email);
        }
      }

      return null;
    } catch (e) {
      AppLog.log('Error en login guardia', error: e);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _getGuardiaData(String email) async {
    final db = _db;
    if (db == null) return null;

    final querySnapshot = await db
        .collection('guardias_auth')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    final data = querySnapshot.docs.first.data();
    final guardiaId = data['guardiaId'] ?? '';

    final guardiaSnapshot =
        await db.collection('guardias').doc(guardiaId).get();

    if (guardiaSnapshot.exists) {
      return {
        'id': guardiaId,
        'email': email,
        'nombre': data['nombre'] ?? '',
        'condominio': data['condominio'] ?? '',
        'tipo': 'guardia',
        ...guardiaSnapshot.data() ?? {},
      };
    }

    return null;
  }

  // ══════════════════════════════════════════════
  // PROPIETARIO — Hash con sal (sin email)
  // ══════════════════════════════════════════════

  /// Login de propietario: verifica hash con sal, con migración de plain-text.
  static Future<Map<String, dynamic>?> loginPropietario({
    required String condominioId,
    required String casaId,
    required String password,
  }) async {
    try {
      final db = _db;
      if (db == null) return null;

      final casaDoc = await db
          .collection('condominios')
          .doc(condominioId)
          .collection('casas')
          .doc(casaId)
          .get();

      if (!casaDoc.exists) return null;

      final casaData = casaDoc.data()!;
      final storedHash = casaData['passwordHash'] as String?;
      final storedSalt = casaData['passwordSalt'] as String?;
      final storedPlain = casaData['password'] as String?;

      // Verificar hash con sal
      if (storedHash != null && storedSalt != null) {
        if (hashWithSalt(password, storedSalt) == storedHash) {
          return {
            'id': casaDoc.id,
            'tipo': 'propietario',
            'condominio': condominioId,
            'casa': casaId,
            'propietario': casaData['propietario'] ?? '',
          };
        }
      }

      // Migración legacy: plain-text → hash con sal
      if (storedPlain != null && storedPlain == password) {
        final salt = _generateSalt();
        final hash = hashWithSalt(password, salt);
        await casaDoc.reference.update({
          'passwordHash': hash,
          'passwordSalt': salt,
          'password': FieldValue.delete(),
        });
        AppLog.log('Propietario migrado a hash: $condominioId casa $casaId');
        return {
          'id': casaDoc.id,
          'tipo': 'propietario',
          'condominio': condominioId,
          'casa': casaId,
          'propietario': casaData['propietario'] ?? '',
        };
      }

      return null;
    } catch (e) {
      AppLog.log('Error en login propietario', error: e);
      return null;
    }
  }

  // ══════════════════════════════════════════════
  // PASSWORD RESET
  // ══════════════════════════════════════════════

  /// Reset de contraseña para propietario. Devuelve la nueva contraseña temporal.
  static Future<String> resetPasswordPropietario({
    required String condominioId,
    required String casaId,
  }) async {
    final db = _db;
    if (db == null) throw Exception('Firebase no inicializado');

    final newPassword = generarPasswordSeguro(length: 10);
    final salt = _generateSalt();
    final hash = hashWithSalt(newPassword, salt);

    await db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(casaId)
        .update({
      'passwordHash': hash,
      'passwordSalt': salt,
      'password': FieldValue.delete(),
      'passwordResetAt': FieldValue.serverTimestamp(),
    });

    return newPassword;
  }

  /// Cambia la contraseña de un propietario a una elegida por el admin, de forma
  /// segura: guarda solo el hash PBKDF2 + salt (nunca el texto plano).
  static Future<void> changePasswordPropietario({
    required String condominioId,
    required String casaId,
    required String newPassword,
  }) async {
    final db = _db;
    if (db == null) throw Exception('Firebase no inicializado');

    final salt = _generateSalt();
    final hash = hashWithSalt(newPassword, salt);

    await db
        .collection('condominios')
        .doc(condominioId)
        .collection('casas')
        .doc(casaId)
        .update({
      'passwordHash': hash,
      'passwordSalt': salt,
      'password': FieldValue.delete(),
      'passwordResetAt': FieldValue.serverTimestamp(),
    });
  }

  /// Envía email de reset para admin/guardia via Firebase Auth.
  static Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ══════════════════════════════════════════════
  // PASSWORD CHANGE (Admin via Firebase Auth)
  // ══════════════════════════════════════════════

  /// Cambia la contraseña del admin autenticado vía Firebase Auth.
  static Future<bool> cambiarContrasenaAdmin({
    required String contrasenaActual,
    required String nuevaContrasena,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      // Re-autenticar para validar contraseña actual
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: contrasenaActual,
      );
      await user.reauthenticateWithCredential(credential);

      // Cambiar contraseña en Firebase Auth
      await user.updatePassword(nuevaContrasena);

      // Actualizar timestamp en Firestore
      final db = _db;
      if (db != null) {
        await db.collection('administradores').doc(user.uid).update({
          'ultimoCambioContrasena': FieldValue.serverTimestamp(),
        });
      }

      return true;
    } on FirebaseAuthException catch (e) {
      AppLog.log('Error al cambiar contraseña: ${e.code}');
      return false;
    } catch (e) {
      AppLog.log('Error inesperado al cambiar contraseña', error: e);
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // EMAIL GENERATION
  // ══════════════════════════════════════════════

  static String generarEmailAdmin(String nombreCondominio) {
    final condominioLimpio = nombreCondominio
        .toLowerCase()
        .trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'admin.$condominioLimpio@fortguards.com';
  }

  static String generarEmailGuardia(
      String nombre, String apellido, String condominioId) {
    final nombreLimpio = nombre
        .toLowerCase()
        .trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final apellidoLimpio = apellido
        .toLowerCase()
        .trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final condominioLimpio = condominioId
        .toLowerCase()
        .trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return 'guardia.$nombreLimpio$apellidoLimpio.$condominioLimpio@fortguards.com';
  }

  /// Cierra sesión.
  static Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Usuario autenticado actual.
  static User? get currentUser => _auth.currentUser;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:developer' as dev;

/// Servicio para manejar la autenticación de usuarios en FortGuards
class AuthService {
  static FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (e) {
      dev.log('Firebase no inicializado', error: e);
      return null;
    }
  }

  /// Calcula hash SHA256 de un texto
  static String _hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Registra un nuevo administrador en Firestore
  static Future<void> registrarAdmin({
    required String email,
    required String password,
    required String nombre,
    required String condominioId,
  }) async {
    try {
      final db = _db;
      if (db == null) return;
      
      // Verificar si el administrador ya existe
      final querySnapshot = await db.collection('administradores')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Crear nuevo administrador si no existe
        await db.collection('administradores').add({
          'email': email,
          'passwordHash': _hash(password),
          'nombre': nombre,
          'condominio': condominioId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      dev.log('Error al registrar administrador', error: e);
      rethrow;
    }
  }

  /// Registra un guardia con su contraseña en Firestore
  static Future<void> registrarGuardia({
    required String guardiaId,
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required String condominioId,
  }) async {
    try {
      final db = _db;
      if (db == null) return;
      
      await db.collection('guardias_auth').add({
        'guardiaId': guardiaId,
        'email': email,
        'passwordHash': _hash(password),
        'nombre': nombre,
        'apellido': apellido,
        'condominio': condominioId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // También agregar a credenciales para el super usuario
      await db.collection('credenciales').add({
        'tipo': 'guardia',
        'email': email,
        'password': password, // Guardar password sin hash para mostrar
        'nombre': '$nombre $apellido',
        'condominio': condominioId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      dev.log('Error al registrar guardia', error: e);
      // No lanzar excepción para que no falle la creación del guardia
    }
  }

  /// Registra una casa con su contraseña en Firestore
  static Future<void> registrarCasa({
    required String condominioId,
    required String casaId,
    required String password,
  }) async {
    try {
      final db = _db;
      if (db == null) return;
      
      await db.collection('credenciales').add({
        'tipo': 'casa',
        'condominio': condominioId,
        'casa': casaId,
        'password': password,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      dev.log('Error al registrar casa', error: e);
      rethrow;
    }
  }

  /// Inicia sesión para administradores
  static const _superEmail = 'admin@fortguards.com';
  static const _superPassword = 'admin123';

  static Future<Map<String, dynamic>?> loginAdmin({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Verificar super admin hardcodeado
      if (email == _superEmail && password == _superPassword) {
        return {
          'id': 'super-admin',
          'email': email,
          'nombre': 'Super Administrador',
          'condominio': 'Todos',
        };
      }

      final db = _db;
      if (db == null) return null;

      // 2. Buscar en Firebase por email
      final querySnapshot = await db.collection('administradores')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final adminDoc = querySnapshot.docs.first;
        final adminData = adminDoc.data();
        
        // 3. Verificar hash de contraseña
        final inputHash = _hash(password);
        final storedHash = adminData['passwordHash'];

        if (inputHash == storedHash) {
          return {
            'id': adminDoc.id,
            ...adminData,
          };
        }
      }
      
      return null;
    } catch (e) {
      dev.log('Error en inicio de sesión de administrador', error: e);
      
      // Fallback para super admin si Firebase falla
      if (email == _superEmail && password == _superPassword) {
        return {
          'id': 'super-admin',
          'email': email,
          'nombre': 'Super Administrador',
          'condominio': 'Todos',
        };
      }
      
      return null;
    }
  }

  /// Inicia sesión de guardia verificando email y contraseña
  static Future<Map<String, dynamic>?> loginGuardia({
    required String email,
    required String password,
  }) async {
    try {
      final db = _db;
      if (db == null) return null;

      // Buscar en la colección guardias_auth
      final querySnapshot = await db.collection('guardias_auth')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final storedHash = data['passwordHash'] ?? '';
        final inputHash = _hash(password);

        if (storedHash == inputHash) {
          // Obtener datos completos del guardia
          final guardiaId = data['guardiaId'] ?? '';
          final guardiaSnapshot = await db.collection('guardias')
              .doc(guardiaId)
              .get();

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
        }
      }

      return null;
    } catch (e) {
      dev.log('Error en inicio de sesión de guardia', error: e);
      return null;
    }
  }

  /// Inicia sesión de propietario verificando casa y contraseña
  static Future<Map<String, dynamic>?> loginPropietario({
    required String condominioId,
    required String casaId,
    required String password,
  }) async {
    try {
      final db = _db;
      if (db == null) return null;
      
      final querySnapshot = await db.collection('credenciales')
          .where('tipo', isEqualTo: 'propietario')
          .where('condominio', isEqualTo: condominioId)
          .where('casa', isEqualTo: casaId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final storedPassword = data['password'] ?? '';

        if (storedPassword == password) {
          return {
            'id': doc.id,
            'tipo': 'propietario',
            'condominio': condominioId,
            'casa': casaId,
            'propietario': data['propietario'] ?? '',
          };
        }
      }

      return null;
    } catch (e) {
      dev.log('Error en inicio de sesión de propietario', error: e);
      return null;
    }
  }

  /// Genera un email para administradores basado en el condominio
  static String generarEmailAdmin(String nombreCondominio) {
    final condominioLimpio = nombreCondominio.toLowerCase().trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
        
    return 'admin.$condominioLimpio@fortguards.com';
  }

  /// Genera una contraseña para administradores basada en el condominio
  static String generarPasswordAdmin(String nombreCondominio) {
    final condominioLimpio = nombreCondominio.toLowerCase().trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
        
    return '${condominioLimpio}123';
  }

  /// Genera un email para guardias basado en nombre y condominio
  static String generarEmailGuardia(String nombre, String apellido, String condominioId) {
    final nombreLimpio = nombre.toLowerCase().trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final apellidoLimpio = apellido.toLowerCase().trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final condominioLimpio = condominioId.toLowerCase().trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
        
    return 'guardia.$nombreLimpio$apellidoLimpio.$condominioLimpio@fortguards.com';
  }

  /// Genera una contraseña para guardias
  static String generarPasswordGuardia(String nombre, String apellido) {
    final nombreLimpio = nombre.toLowerCase().trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final apellidoLimpio = apellido.toLowerCase().trim()
        .replaceAll(' ', '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
        
    return '${nombreLimpio.substring(0, nombreLimpio.length > 3 ? 3 : nombreLimpio.length)}${apellidoLimpio.substring(0, apellidoLimpio.length > 3 ? 3 : apellidoLimpio.length)}2024';
  }

  /// Genera una contraseña para propietarios basada en el número de casa
  static String generarPasswordPropietario(String numeroCasa) {
    // Nueva regla: repetir cada dígito y añadir '01' al final para mayor entropía
    // Ej: casa "1" -> "110101", casa "23" -> "223301"
    final numero = numeroCasa.replaceAll(RegExp(r'[^0-9]'), '');
    if (numero.isEmpty) {
      return '${numeroCasa.substring(0, numeroCasa.length > 2 ? 2 : numeroCasa.length).toLowerCase()}01';
    }

    final buffer = StringBuffer();
    for (final char in numero.split('')) {
      buffer.write(char * 2); // duplica cada dígito
    }
    buffer.write('01');
    return buffer.toString();
  }

  /// Migra contraseñas de texto plano a hash
  static Future<void> migrarPasswordsAHash() async {
    try {
      final db = _db;
      if (db == null) return;
      
      final querySnapshot = await db.collection('administradores').get();
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('password')) {
          final hash = _hash(data['password']);
          await doc.reference.update({
            'passwordHash': hash,
            'password': FieldValue.delete(),
          });
        }
      }
    } catch (e) {
      dev.log('Error al migrar passwords', error: e);
    }
  }

  /// Obtiene todas las credenciales para mostrar en el panel del super usuario
  static Future<List<Map<String, dynamic>>> obtenerTodasLasCredenciales() async {
    try {
      final db = _db;
      if (db == null) return [];
      
      final querySnapshot = await db.collection('credenciales').get();
      return querySnapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      dev.log('Error al obtener credenciales', error: e);
      return [];
    }
  }
}

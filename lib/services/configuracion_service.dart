import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';
import '../models/configuracion_model.dart';
import 'credentials_sync_service.dart';

class ConfiguracionService {
  static const String _configKey = 'app_configuracion';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener configuración actual
  static Future<ConfiguracionModel> obtenerConfiguracion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString(_configKey);
      
      if (configJson != null) {
        final configMap = jsonDecode(configJson) as Map<String, dynamic>;
        return ConfiguracionModel.fromMap(configMap);
      }
      
      // Si no existe configuración, devolver configuración por defecto
      return const ConfiguracionModel();
    } catch (e) {
      debugPrint('Error al obtener configuración: $e');
      return const ConfiguracionModel();
    }
  }

  // Guardar configuración
  static Future<bool> guardarConfiguracion(ConfiguracionModel configuracion) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = jsonEncode(configuracion.toMap());
      await prefs.setString(_configKey, configJson);
      
      // Opcionalmente sincronizar con Firestore
      await _sincronizarConFirestore(configuracion);
      
      return true;
    } catch (e) {
      debugPrint('Error al guardar configuración: $e');
      return false;
    }
  }

  // Actualizar configuración específica
  static Future<bool> actualizarConfiguracion({
    bool? notificacionesActivadas,
    bool? sonidoActivado,
    bool? vibracionActivada,
    bool? modoOscuroAutomatico,
    String? idioma,
  }) async {
    try {
      final configuracionActual = await obtenerConfiguracion();
      final nuevaConfiguracion = configuracionActual.copyWith(
        notificacionesActivadas: notificacionesActivadas,
        sonidoActivado: sonidoActivado,
        vibracionActivada: vibracionActivada,
        modoOscuroAutomatico: modoOscuroAutomatico,
        idioma: idioma,
      );
      
      return await guardarConfiguracion(nuevaConfiguracion);
    } catch (e) {
      debugPrint('Error al actualizar configuración: $e');
      return false;
    }
  }

  // Sincronizar con Firestore (opcional)
  static Future<void> _sincronizarConFirestore(ConfiguracionModel configuracion) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('configuraciones')
            .doc(user.uid)
            .set(configuracion.toFirestore());
      }
    } catch (e) {
      debugPrint('Error al sincronizar con Firestore: $e');
    }
  }

  // Función para hashear contraseña
  static String _hashearContrasena(String contrasena) {
    final bytes = utf8.encode(contrasena);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Obtener administrador logueado actual
  static Future<Map<String, dynamic>?> _obtenerAdministradorActual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminId = prefs.getString('admin_id');
      final adminEmail = prefs.getString('admin_email');
      
      debugPrint('Admin ID desde SharedPreferences: $adminId');
      debugPrint('Admin Email desde SharedPreferences: $adminEmail');
      
      // Si no hay ID guardado, buscar por email
      if (adminId == null && adminEmail != null) {
        final querySnapshot = await _firestore.collection('administradores')
            .where('email', isEqualTo: adminEmail)
            .limit(1)
            .get();
            
        if (querySnapshot.docs.isNotEmpty) {
          final adminDoc = querySnapshot.docs.first;
          return {
            'id': adminDoc.id,
            'data': adminDoc.data(),
          };
        }
      }
      
      // Si hay ID, buscar directamente
      if (adminId != null) {
        final adminDoc = await _firestore.collection('administradores').doc(adminId).get();
        
        if (adminDoc.exists) {
          return {
            'id': adminId,
            'data': adminDoc.data(),
          };
        }
      }

      debugPrint('No se encontró administrador logueado');
      return null;
    } catch (e) {
      debugPrint('Error al obtener administrador actual: $e');
      return null;
    }
  }

  // Cambiar contraseña
  static Future<bool> cambiarContrasena({
    required String contrasenaActual,
    required String nuevaContrasena,
  }) async {
    try {
      // Obtener el administrador logueado actual
      final adminInfo = await _obtenerAdministradorActual();
      if (adminInfo == null) {
        debugPrint('No hay administrador logueado');
        return false;
      }

      final adminId = adminInfo['id'] as String;
      final adminData = adminInfo['data'] as Map<String, dynamic>;

      // Hashear la contraseña actual ingresada
      final contrasenaActualHasheada = _hashearContrasena(contrasenaActual);
      
      // Verificar si la contraseña actual coincide con la almacenada
      // El login usa 'passwordHash', así que debemos usar el mismo campo
      final contrasenaAlmacenada = adminData['passwordHash'] ?? adminData['password'] ?? '';
      
      debugPrint('Contraseña almacenada: $contrasenaAlmacenada');
      debugPrint('Contraseña actual hasheada: $contrasenaActualHasheada');
      
      if (contrasenaAlmacenada != contrasenaActualHasheada) {
        debugPrint('Contraseña actual incorrecta');
        return false;
      }

      // Hashear la nueva contraseña
      final nuevaContrasenaHasheada = _hashearContrasena(nuevaContrasena);

      // Actualizar la contraseña en Firebase usando el mismo campo que el login
      await _firestore.collection('administradores').doc(adminId).update({
        'passwordHash': nuevaContrasenaHasheada,
        'ultimoCambioContrasena': FieldValue.serverTimestamp(),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Contraseña actualizada en administradores');

      // 🔄 SINCRONIZAR CON CREDENCIALES (no dependemos de FirebaseAuth.currentUser)
      // Obtener datos necesarios para la sincronización
      final email = adminData['email'] as String?;
      final condominio = adminData['condominio'] as String?;
      final fallbackAdminUid = _auth.currentUser?.uid ?? adminId;

      if (email != null && condominio != null) {
        try {
          debugPrint('🔄 Iniciando sincronización con credenciales...');

          final syncService = CredentialsSyncService();
          await syncService.updateAdminPasswordAndSyncCredentials(
            condominio: condominio,
            email: email,
            newPassword: nuevaContrasena, // Texto plano para credenciales
            adminUid: fallbackAdminUid,
          );

          debugPrint('✅ Sincronización con credenciales completada');
        } catch (syncError) {
          // Log del error pero no fallar toda la operación
          // La contraseña en administradores ya se actualizó correctamente
          debugPrint('⚠️ Advertencia: No se pudo sincronizar con credenciales: $syncError');
        }
      } else {
        debugPrint('⚠️ Advertencia: Faltan datos para sincronizar (email: $email, condominio: $condominio)');
      }

      return true;
      
    } catch (e) {
      debugPrint('❌ Error al cambiar contraseña: $e');
      return false;
    }
  }

  // Crear backup de datos
  static Future<String?> crearBackup() async {
    try {
      // Solicitar permisos de almacenamiento
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        return null;
      }

      final user = _auth.currentUser;
      if (user == null) return null;

      // Funcionalidad de backup deshabilitada temporalmente
      throw Exception('Funcionalidad de backup no disponible');
    } catch (e) {
      debugPrint('Error al crear backup: $e');
      return null;
    }
  }

  // Restaurar desde backup
  static Future<bool> restaurarBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final backupContent = await file.readAsString();
      final backupData = jsonDecode(backupContent) as Map<String, dynamic>;

      // Restaurar configuración
      if (backupData['configuracion'] != null) {
        final configuracion = ConfiguracionModel.fromMap(
          backupData['configuracion'] as Map<String, dynamic>
        );
        await guardarConfiguracion(configuracion);
      }

      return true;
    } catch (e) {
      debugPrint('Error al restaurar backup: $e');
      return false;
    }
  }

  // Limpiar configuración (reset)
  static Future<bool> limpiarConfiguracion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_configKey);
      return true;
    } catch (e) {
      debugPrint('Error al limpiar configuración: $e');
      return false;
    }
  }

  // Obtener información de la app
  static Future<Map<String, String>> obtenerInfoApp() async {
    return {
      'version': '1.0.0',
      'build': '1',
      'fecha_compilacion': '2024-01-01',
      'desarrollador': 'FortGuard Team',
    };
  }

  // Verificar permisos de notificaciones
  static Future<bool> verificarPermisosNotificaciones() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  // Solicitar permisos de notificaciones
  static Future<bool> solicitarPermisosNotificaciones() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }
}

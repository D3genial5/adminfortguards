import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/configuracion_model.dart';
import 'auth_service.dart';

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
      if (kDebugMode) debugPrint('Error al obtener configuración: $e');
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
      if (kDebugMode) debugPrint('Error al guardar configuración: $e');
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
      if (kDebugMode) debugPrint('Error al actualizar configuración: $e');
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
      if (kDebugMode) debugPrint('Error al sincronizar con Firestore: $e');
    }
  }

  /// Cambia la contraseña del admin autenticado vía Firebase Auth.
  static Future<bool> cambiarContrasena({
    required String contrasenaActual,
    required String nuevaContrasena,
  }) async {
    return AuthService.cambiarContrasenaAdmin(
      contrasenaActual: contrasenaActual,
      nuevaContrasena: nuevaContrasena,
    );
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
      if (kDebugMode) debugPrint('Error al crear backup: $e');
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
      if (kDebugMode) debugPrint('Error al restaurar backup: $e');
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
      if (kDebugMode) debugPrint('Error al limpiar configuración: $e');
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

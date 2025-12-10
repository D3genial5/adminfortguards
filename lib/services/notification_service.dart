import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// GlobalKey para acceder al Navigator desde servicios
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _currentToken;
  
  // Inicializar servicio de notificaciones
  Future<void> initialize() async {
    // Solicitar permisos
    await _requestPermissions();
    
    // Configurar notificaciones locales
    await _configureLocalNotifications();
    
    // Obtener y guardar token FCM
    await _getAndSaveToken();
    
    // Configurar listeners de FCM
    _configureFCMListeners();
    
    // Escuchar cambios de token
    _fcm.onTokenRefresh.listen(_saveToken);
  }
  
  // Solicitar permisos de notificaciones
  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    debugPrint('Permisos de notificación: ${settings.authorizationStatus}');
  }
  
  // Configurar notificaciones locales
  Future<void> _configureLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );
    
    // Crear canal de notificaciones para Android
    const androidChannel = AndroidNotificationChannel(
      'fortguards_channel',
      'FortGuards Notificaciones',
      description: 'Canal principal de notificaciones',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }
  
  // Obtener y guardar token FCM
  Future<void> _getAndSaveToken() async {
    try {
      _currentToken = await _fcm.getToken();
      if (_currentToken != null) {
        await _saveToken(_currentToken!);
      }
    } catch (e) {
      debugPrint('Error obteniendo token FCM: $e');
    }
  }
  
  // Guardar token en Firestore
  Future<void> _saveToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      // Buscar credencial del usuario
      final credencialQuery = await _firestore
          .collection('credenciales')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();
      
      if (credencialQuery.docs.isNotEmpty) {
        final docId = credencialQuery.docs.first.id;
        
        // Actualizar tokens FCM (array para soportar múltiples dispositivos)
        await _firestore.collection('credenciales').doc(docId).update({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'ultimoLoginAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('Token FCM guardado: $token');
      }
    } catch (e) {
      debugPrint('Error guardando token FCM: $e');
    }
  }
  
  // Configurar listeners de FCM
  void _configureFCMListeners() {
    // Mensaje en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });
    
    // App abierta desde notificación (background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationOpen(message);
    });
    
    // Verificar si la app se abrió desde notificación (terminated)
    _checkInitialMessage();
  }
  
  // Manejar mensaje en primer plano
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'Notificación',
        body: notification.body ?? '',
        payload: data['route'] ?? '',
      );
    }
    
    // Guardar notificación en Firestore
    _saveNotificationToFirestore(message);
  }
  
  // Mostrar notificación local
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'fortguards_channel',
      'FortGuards Notificaciones',
      channelDescription: 'Canal principal de notificaciones',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
  
  // Guardar notificación en Firestore
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await _firestore.collection('notificaciones').add({
        'titulo': message.notification?.title ?? 'Notificación',
        'cuerpo': message.notification?.body ?? '',
        'data': message.data,
        'to': user.uid,
        'tipo': message.data['tipo'] ?? 'privada',
        'leida': false,
        'creadoAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error guardando notificación: $e');
    }
  }
  
  // Manejar apertura de notificación
  void _handleNotificationOpen(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null) {
      _navigateToRoute(route);
    }
  }
  
  // Manejar tap en notificación local
  void _handleNotificationTap(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      _navigateToRoute(payload);
    }
  }
  
  // Navegar a ruta específica
  void _navigateToRoute(String route) {
    final navigator = globalNavigatorKey.currentState;
    if (navigator == null) return;
    
    // Implementar navegación según la ruta
    switch (route) {
      case 'expensas':
        navigator.pushNamed('/expensas');
        break;
      case 'reservas':
        navigator.pushNamed('/reservas');
        break;
      case 'notificaciones':
        navigator.pushNamed('/notificaciones');
        break;
      default:
        navigator.pushNamed(route);
    }
  }
  
  // Verificar mensaje inicial (app terminated)
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }
  }
  
  // Enviar notificación a usuario específico
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Guardar notificación en Firestore
      await _firestore.collection('notificaciones').add({
        'titulo': title,
        'cuerpo': body,
        'data': data ?? {},
        'to': userId,
        'tipo': 'privada',
        'leida': false,
        'creadoAt': FieldValue.serverTimestamp(),
      });
      
      // Aquí se llamaría a Cloud Function para enviar push
      // Por ahora solo guardamos en Firestore
      debugPrint('Notificación enviada a usuario: $userId');
    } catch (e) {
      debugPrint('Error enviando notificación: $e');
    }
  }
  
  // Enviar notificación a todo el condominio
  Future<void> sendNotificationToCondominio({
    required String condominioId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Guardar notificación para todos los usuarios del condominio
      await _firestore.collection('notificaciones').add({
        'titulo': title,
        'cuerpo': body,
        'data': data ?? {},
        'to': 'condominio:$condominioId',
        'tipo': 'condominio',
        'leida': false,
        'creadoAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Notificación enviada al condominio: $condominioId');
    } catch (e) {
      debugPrint('Error enviando notificación al condominio: $e');
    }
  }
  
  // Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notificaciones').doc(notificationId).update({
        'leida': true,
      });
    } catch (e) {
      debugPrint('Error marcando notificación como leída: $e');
    }
  }
  
  // Suscribirse a topic del condominio
  Future<void> subscribeToCondominio(String condominioId) async {
    try {
      await _fcm.subscribeToTopic('condominio_$condominioId');
      debugPrint('Suscrito al topic: condominio_$condominioId');
    } catch (e) {
      debugPrint('Error suscribiendo a topic: $e');
    }
  }
  
  // Desuscribirse de topic del condominio
  Future<void> unsubscribeFromCondominio(String condominioId) async {
    try {
      await _fcm.unsubscribeFromTopic('condominio_$condominioId');
      debugPrint('Desuscrito del topic: condominio_$condominioId');
    } catch (e) {
      debugPrint('Error desuscribiendo de topic: $e');
    }
  }
  
  // Obtener token actual
  String? get currentToken => _currentToken;
}

// Handler para mensajes en background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Mensaje en background: ${message.messageId}');
  // Aquí se puede procesar el mensaje en background si es necesario
}

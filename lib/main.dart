import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Optimizaciones de rendimiento
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    
    // Inicialización Firebase
    await FirebaseService.initialize();
    
    // Configurar handler de mensajes en background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Ejecutar app principal
    runApp(const AdminFortGuardApp());
  } catch (e) {
    // En caso de error, ejecutar app sin Firebase
    runApp(const AdminFortGuardApp());
  }
}

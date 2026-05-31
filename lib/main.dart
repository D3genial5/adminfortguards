import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      await initializeDateFormatting('es', null);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await FirebaseService.initialize();

      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      runApp(const AdminFortGuardApp());
    } catch (e) {
      if (kDebugMode) debugPrint('Init error: $e');
      runApp(const AdminFortGuardApp());
    }
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

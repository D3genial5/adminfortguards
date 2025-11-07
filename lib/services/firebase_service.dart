import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static FirebaseFirestore? _firestore;
  static bool _initialized = false;

  static FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firebase no inicializado. Llama a initialize() primero.');
    }
    return _firestore!;
  }

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
      
      // Configuraciones de rendimiento para Firestore
      _firestore = FirebaseFirestore.instance;
      
      // Configurar cache offline
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _initialized = true;
    } catch (e) {
      // No lanzar excepción, solo marcar como no inicializado
      _initialized = false;
      _firestore = null;
    }
  }

  static bool get isInitialized => _initialized;
}

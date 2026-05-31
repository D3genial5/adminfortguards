import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/theme_service.dart';

import 'screens/admin/lista_condominios_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/crear_condominio_screen.dart';
import 'screens/general/acceso_general_screen.dart';
import 'screens/admin/login_admin_screen.dart';
import 'screens/seguridad/login_seguridad_screen.dart';
import 'screens/seguridad/perfil_guardia.dart';
import 'screens/seguridad/scan_qr_screen.dart';
import 'screens/seguridad/registros_activos_screen.dart';
import 'screens/seguridad/alertas_screen.dart';
import 'screens/admin/ver_credenciales_screen.dart';

final GoRouter _router = GoRouter(
  redirect: (context, state) {
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;
    final isPublicRoute = state.matchedLocation == '/' ||
        state.matchedLocation == '/login-admin' ||
        state.matchedLocation == '/login-seguridad';

    if (!isLoggedIn && !isPublicRoute) {
      return '/';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AccesoGeneralScreen(),
    ),

    GoRoute(
      path: '/crear-condominio',
      builder: (context, state) => const CrearCondominioScreen(),
    ),
    
    GoRoute(
      path: '/lista',
      builder: (context, state) => const ListaCondominiosScreen(),
    ),

    GoRoute(
      path: '/dashboard/:condominio',
      builder: (context, state) {
        final id = state.pathParameters['condominio']!;
        return AdminDashboardScreen(condominioId: id);
      },
    ),

    GoRoute(
      path: '/login-admin',
      builder: (context, state) => const LoginAdminScreen()
    ),

    GoRoute(
      path: '/login-seguridad',
      builder: (context, state) => const LoginSeguridadScreen()
    ),

    GoRoute(
      path: '/perfil-guardia',
      builder: (context, state) => PerfilGuardiaScreen(
        guardiaData: state.extra as Map<String, dynamic>?,
      ),
    ),

    GoRoute(
      path: '/admin-dashboard',
      builder: (context, state) => AdminDashboardScreen(
        condominioId: (state.extra as Map<String, dynamic>?)?['id'] ?? '',
      ),
    ),

    GoRoute(
      path: '/scan-qr',
      builder: (context, state) => ScanQrScreen(
        guardiaData: state.extra as Map<String, dynamic>?,
      ),
    ),

    GoRoute(
      path: '/registros-activos',
      builder: (context, state) => RegistrosActivosScreen(
        guardiaData: state.extra as Map<String, dynamic>?,
      ),
    ),
    
    GoRoute(
      path: '/ver-credenciales',
      builder: (context, state) => const VerCredencialesScreen(),
    ),
    
    GoRoute(
      path: '/credenciales',
      builder: (context, state) => const VerCredencialesScreen(),
    ),

    GoRoute(
      path: '/alertas',
      builder: (context, state) => AlertasScreen(
        guardiaData: state.extra as Map<String, dynamic>?,
      ),
    ),

  ],
);

class AdminFortGuardApp extends StatelessWidget {
  const AdminFortGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ThemeService(),
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp.router(
            title: 'Admin FortGuards',
            theme: ThemeService.lightTheme,
            darkTheme: ThemeService.darkTheme,
            themeMode: themeService.themeMode,
            routerConfig: _router,
            debugShowCheckedModeBanner: false,
            // Localizaciones para español
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('es', 'ES'),
              Locale('es'),
              Locale('en'),
            ],
            locale: const Locale('es'),
            // Optimizaciones de rendimiento
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

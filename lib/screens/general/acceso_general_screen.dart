import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AccesoGeneralScreen extends StatefulWidget {
  const AccesoGeneralScreen({super.key});

  @override
  State<AccesoGeneralScreen> createState() => _AccesoGeneralScreenState();
}

class _AccesoGeneralScreenState extends State<AccesoGeneralScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo FortGuard
              Container(
                margin: const EdgeInsets.only(bottom: 48),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/fortguard_logo.png',
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 20),
                    Image.asset(
                      'assets/fortguard_letras.png',
                      width: 220,
                      height: 45,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Administración',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _buildAccesoButton(
                context,
                label: 'SEGURIDAD',
                icon: Icons.shield_rounded,
                route: '/login-seguridad', 
              ),
              const SizedBox(height: 20),
              _buildAccesoButton(
                context,
                label: 'ADMINISTRACIÓN',
                icon: Icons.admin_panel_settings_rounded,
                route: '/login-admin',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccesoButton(BuildContext context,
      {required String label, required IconData icon, required String route}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          context.go(route);
        },
        icon: Icon(icon, size: 28),
        label: Text(
          label, 
          style: const TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

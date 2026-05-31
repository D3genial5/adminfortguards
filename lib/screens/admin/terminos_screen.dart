import 'package:flutter/material.dart';

/// Pantalla de Términos y Condiciones / Política de privacidad.
class TerminosScreen extends StatelessWidget {
  const TerminosScreen({super.key});

  static const List<({String titulo, String cuerpo})> _secciones = [
    (
      titulo: '1. Uso del servicio',
      cuerpo:
          'FortGuards es una herramienta de gestión de acceso y administración '
          'para condominios. El uso de la aplicación implica la aceptación de '
          'estos términos por parte de administradores, guardias y propietarios.',
    ),
    (
      titulo: '2. Datos personales',
      cuerpo:
          'La aplicación procesa datos necesarios para el control de acceso '
          '(nombres, documentos de identidad, registros de ingreso/salida). '
          'Estos datos se utilizan únicamente con fines de seguridad y '
          'administración del condominio.',
    ),
    (
      titulo: '3. Responsabilidades',
      cuerpo:
          'El administrador es responsable de mantener actualizada la '
          'información de casas, propietarios y guardias, así como de gestionar '
          'las credenciales de acceso de forma segura.',
    ),
    (
      titulo: '4. Seguridad',
      cuerpo:
          'Los códigos y QR de acceso son personales e intransferibles. El uso '
          'indebido de credenciales puede derivar en la suspensión del acceso.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y Condiciones')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final seccion in _secciones) ...[
            Text(
              seccion.titulo,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(seccion.cuerpo, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
          ],
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Última actualización: mayo de 2026',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

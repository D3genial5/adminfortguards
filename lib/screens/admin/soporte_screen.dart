import 'package:flutter/material.dart';

/// Pantalla de Ayuda y Soporte: preguntas frecuentes y datos de contacto.
class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

  // TODO(prod): reemplazar por el correo/teléfono real de soporte.
  static const String _correoSoporte = 'soporte@fortguards.com';

  static const List<({String pregunta, String respuesta})> _faqs = [
    (
      pregunta: '¿Cómo agrego una nueva casa al condominio?',
      respuesta:
          'Desde el panel principal, abre el menú y selecciona la opción de '
          'gestión de casas. Pulsa el botón de agregar e ingresa los datos del '
          'propietario y residentes.',
    ),
    (
      pregunta: '¿Cómo cambio la contraseña de un propietario?',
      respuesta:
          'En el menú de una casa elige "Editar propietario". Allí puedes ver '
          'la información y asignar una nueva contraseña.',
    ),
    (
      pregunta: '¿Cómo registro un guardia?',
      respuesta:
          'Entra a la gestión de guardias, pulsa agregar y completa los datos. '
          'El sistema genera sus credenciales automáticamente.',
    ),
    (
      pregunta: 'El guardia no puede escanear un QR, ¿qué hago?',
      respuesta:
          'Verifica que el código de la casa esté vigente y con usos '
          'disponibles, y que el guardia tenga conexión a internet.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda y Soporte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Preguntas frecuentes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ..._faqs.map(
            (faq) => Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ExpansionTile(
                title: Text(faq.pregunta),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedAlignment: Alignment.topLeft,
                children: [Text(faq.respuesta)],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Contacto',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Correo de soporte'),
              subtitle: const Text(_correoSoporte),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/propietario_service.dart';

class EditarPropietarioScreen extends StatefulWidget {
  final String condominio;
  final String casa;
  final String propietarioNombre;

  const EditarPropietarioScreen({
    super.key,
    required this.condominio,
    required this.casa,
    required this.propietarioNombre,
  });

  @override
  State<EditarPropietarioScreen> createState() => _EditarPropietarioScreenState();
}

class _EditarPropietarioScreenState extends State<EditarPropietarioScreen> {
  late Map<String, dynamic> propietarioData;
  bool isLoading = true;
  bool isSaving = false;
  bool mostrarPassword = false;
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarPropietario();
  }

  Future<void> _cargarPropietario() async {
    try {
      final data = await PropietarioService.obtenerPropietario(
        condominio: widget.condominio,
        casa: widget.casa,
      );

      if (mounted) {
        setState(() {
          propietarioData = data ?? {};
          passwordController.text = propietarioData['password'] ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cambiarPassword() async {
    if (!_validarFormulario()) return;

    setState(() => isSaving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final adminUid = currentUser?.uid ?? 'SYSTEM_ADMIN';

      final exito = await PropietarioService.cambiarPasswordPropietario(
        condominio: widget.condominio,
        casa: widget.casa,
        nuevaPassword: passwordController.text.trim(),
        adminUid: adminUid,
        createIfMissing: true,
      );

      if (mounted) {
        setState(() => isSaving = false);

        if (exito) {
          setState(() {
            propietarioData['password'] = passwordController.text.trim();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Contraseña actualizada exitosamente',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          confirmPasswordController.clear();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Error al actualizar contraseña',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _validarFormulario() {
    final nuevaPassword = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (nuevaPassword.isEmpty) {
      _mostrarError('La contraseña no puede estar vacía');
      return false;
    }

    if (nuevaPassword.length < 4) {
      _mostrarError('La contraseña debe tener al menos 4 caracteres');
      return false;
    }

    if (nuevaPassword != confirmPassword) {
      _mostrarError('Las contraseñas no coinciden');
      return false;
    }

    return true;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, size: 20, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Propietario',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 📋 Información General
                    _buildSeccion(
                      titulo: 'Información General',
                      icono: Icons.info_outline_rounded,
                      colorScheme: colorScheme,
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Casa', widget.casa, colorScheme),
                          const SizedBox(height: 12),
                          _buildInfoRow('Propietario', propietarioData['propietario'] ?? 'N/A', colorScheme),
                          const SizedBox(height: 12),
                          _buildInfoRow('Condominio', widget.condominio, colorScheme),
                          if (propietarioData['email'] != null && (propietarioData['email'] as String).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow('Email', propietarioData['email'] ?? '', colorScheme),
                          ],
                          if (propietarioData['telefono'] != null && (propietarioData['telefono'] as String).isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow('Teléfono', propietarioData['telefono'] ?? '', colorScheme),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🔐 Cambiar Contraseña
                    _buildSeccion(
                      titulo: 'Cambiar Contraseña',
                      icono: Icons.lock_outline_rounded,
                      colorScheme: colorScheme,
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Contraseña Actual
                          Text(
                            'Contraseña Actual',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  mostrarPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  size: 18,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    mostrarPassword 
                                        ? (propietarioData['password'] ?? '')
                                        : '•' * (propietarioData['password']?.toString().length ?? 0),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => mostrarPassword = !mostrarPassword),
                                  child: Icon(
                                    mostrarPassword ? Icons.hide_source_rounded : Icons.visibility_rounded,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Nueva Contraseña
                          Text(
                            'Nueva Contraseña',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: 'Ingresa nueva contraseña',
                              isDense: true,
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Confirmar Contraseña
                          Text(
                            'Confirmar Contraseña',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: confirmPasswordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              hintText: 'Confirma la nueva contraseña',
                              isDense: true,
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Botón Guardar
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : _cambiarPassword,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: colorScheme.primary,
                                disabledBackgroundColor: colorScheme.primary.withOpacity(0.5),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Guardar Cambios',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 📜 Historial
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: PropietarioService.obtenerHistorialPropietario(
                        condominio: widget.condominio,
                        casa: widget.casa,
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final historial = snapshot.data!;
                        return _buildSeccion(
                          titulo: 'Historial de Cambios',
                          icono: Icons.history_rounded,
                          colorScheme: colorScheme,
                          isDark: isDark,
                          child: Column(
                            children: historial.map((cambio) {
                              final timestamp = cambio['at'] as dynamic;
                              final fecha = timestamp != null
                                  ? DateTime.fromMillisecondsSinceEpoch(
                                      (timestamp as Timestamp).millisecondsSinceEpoch,
                                    )
                                  : DateTime.now();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Colors.green.shade600,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cambio['detalle'] ?? 'Cambio de contraseña',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              fontSize: 11,
                                              color: colorScheme.onSurface.withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSeccion({
    required String titulo,
    required IconData icono,
    required ColorScheme colorScheme,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withOpacity(0.5)
            : colorScheme.surfaceContainerHighest.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

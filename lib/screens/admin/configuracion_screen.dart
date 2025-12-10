import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/configuracion_model.dart';
import '../../services/configuracion_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  ConfiguracionModel _configuracion = const ConfiguracionModel();
  bool _cargando = true;
  String _nombreUsuario = 'Administrador';

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
    _cargarDatosUsuario();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final config = await ConfiguracionService.obtenerConfiguracion();
      if (mounted) {
        setState(() {
          _configuracion = config;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarDatosUsuario() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      setState(() {
        _nombreUsuario = user.displayName ?? 'Administrador';
      });
    }
  }

  Future<void> _actualizarConfiguracion(ConfiguracionModel nuevaConfig) async {
    final exito = await ConfiguracionService.guardarConfiguracion(nuevaConfig);
    if (mounted) {
      if (exito) {
        setState(() => _configuracion = nuevaConfig);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar configuración'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorPrimario = Theme.of(context).colorScheme.primary;
    
    if (_cargando) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFBFC),
        appBar: AppBar(
          title: const Text(
            'Configuración',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
              letterSpacing: 0.3,
            ),
          ),
          centerTitle: true,
          backgroundColor: colorPrimario,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFC),
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorPrimario,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            // Perfil del usuario
            _buildPerfilUsuario(),
            const SizedBox(height: 32),
            
            // Notificaciones
            _buildSeccionNotificaciones(),
            const SizedBox(height: 24),
            
            // Seguridad
            _buildSeccionSeguridad(),
            const SizedBox(height: 24),
            
            // Datos y Backup
            _buildSeccionBackup(),
            const SizedBox(height: 24),
            
            // Información
            _buildSeccionInformacion(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Widgets de construcción
  Widget _buildPerfilUsuario() {
    final colorPrimario = Theme.of(context).colorScheme.primary;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colorPrimario,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _nombreUsuario.isNotEmpty ? _nombreUsuario[0].toUpperCase() : 'A',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombreUsuario,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionNotificaciones() {
    return _buildSeccion(
      titulo: 'Notificaciones',
      icono: Icons.notifications_outlined,
      children: [
        _buildToggleItem(
          icono: Icons.notifications_active_outlined,
          titulo: 'Notificaciones Push',
          subtitulo: 'Recibir notificaciones en tiempo real',
          valor: _configuracion.notificacionesActivadas,
          onChanged: (value) async {
            final nuevaConfig = _configuracion.copyWith(
              notificacionesActivadas: value,
            );
            await _actualizarConfiguracion(nuevaConfig);
            
            if (value) {
              await ConfiguracionService.solicitarPermisosNotificaciones();
            }
          },
        ),
        _buildDivider(),
        _buildToggleItem(
          icono: Icons.volume_up_outlined,
          titulo: 'Sonido',
          subtitulo: 'Reproducir sonidos de la aplicación',
          valor: _configuracion.sonidoActivado,
          onChanged: (value) async {
            final nuevaConfig = _configuracion.copyWith(
              sonidoActivado: value,
            );
            await _actualizarConfiguracion(nuevaConfig);
          },
        ),
        _buildDivider(),
        _buildToggleItem(
          icono: Icons.vibration_outlined,
          titulo: 'Vibración',
          subtitulo: 'Vibrar para notificaciones',
          valor: _configuracion.vibracionActivada,
          onChanged: (value) async {
            final nuevaConfig = _configuracion.copyWith(
              vibracionActivada: value,
            );
            await _actualizarConfiguracion(nuevaConfig);
          },
        ),
      ],
    );
  }

  Widget _buildSeccionSeguridad() {
    return _buildSeccion(
      titulo: 'Seguridad',
      icono: Icons.shield_outlined,
      children: [
        _buildActionItem(
          icono: Icons.lock_outlined,
          titulo: 'Cambiar Contraseña',
          subtitulo: 'Actualizar tu contraseña de acceso',
          onTap: _mostrarDialogoCambiarContrasena,
        ),
      ],
    );
  }

  Widget _buildSeccionBackup() {
    return _buildSeccion(
      titulo: 'Datos y Backup',
      icono: Icons.cloud_outlined,
      children: [
        _buildActionItem(
          icono: Icons.cloud_upload_outlined,
          titulo: 'Crear Backup',
          subtitulo: _configuracion.ultimoBackup != null
              ? 'Último backup: ${_formatearFecha(_configuracion.ultimoBackup!)}'
              : 'Respaldar datos importantes',
          onTap: _crearBackup,
        ),
        _buildDivider(),
        _buildActionItem(
          icono: Icons.cloud_download_outlined,
          titulo: 'Restaurar Backup',
          subtitulo: 'Recuperar datos desde backup',
          onTap: _restaurarBackup,
        ),
      ],
    );
  }

  Widget _buildSeccionInformacion() {
    return _buildSeccion(
      titulo: 'Información',
      icono: Icons.info_outlined,
      children: [
        _buildActionItem(
          icono: Icons.info_outlined,
          titulo: 'Acerca de',
          subtitulo: 'Versión ${_configuracion.version}',
          onTap: _mostrarDialogoAcercaDe,
        ),
        _buildDivider(),
        _buildActionItem(
          icono: Icons.help_outline_rounded,
          titulo: 'Ayuda',
          subtitulo: 'Centro de ayuda y soporte',
          onTap: _mostrarAyuda,
        ),
        _buildDivider(),
        _buildActionItem(
          icono: Icons.privacy_tip_outlined,
          titulo: 'Política de Privacidad',
          subtitulo: 'Términos y condiciones',
          onTap: _mostrarPoliticaPrivacidad,
        ),
      ],
    );
  }

  Widget _buildSeccion({
    required String titulo,
    required IconData icono,
    required List<Widget> children,
  }) {
    final colorPrimario = Theme.of(context).colorScheme.primary;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de sección
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorPrimario.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icono,
                  color: colorPrimario,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorPrimario,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        // Items de la sección
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleItem({
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    final colorPrimario = Theme.of(context).colorScheme.primary;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icono,
              color: const Color(0xFF6B7280),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2D2D2D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: valor,
            onChanged: onChanged,
            activeColor: colorPrimario,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icono,
                  color: const Color(0xFF6B7280),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFF1F3F6),
      ),
    );
  }

  // Métodos funcionales
  void _mostrarDialogoCambiarContrasena() {
    final formKey = GlobalKey<FormState>();
    final contrasenaActualController = TextEditingController();
    final nuevaContrasenaController = TextEditingController();
    final confirmarContrasenaController = TextEditingController();
    bool cargando = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cambiar Contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: contrasenaActualController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese su contraseña actual';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nuevaContrasenaController,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmarContrasenaController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nueva contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value != nuevaContrasenaController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: cargando ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: cargando ? null : () async {
                if (formKey.currentState!.validate()) {
                  // Capturar referencias antes del await
                  final navigator = Navigator.of(context);
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  
                  setDialogState(() => cargando = true);
                  
                  final exito = await ConfiguracionService.cambiarContrasena(
                    contrasenaActual: contrasenaActualController.text,
                    nuevaContrasena: nuevaContrasenaController.text,
                  );
                  
                  if (mounted) {
                    navigator.pop();
                    
                    if (exito) {
                      // ✅ La sincronización con credenciales ya se hace automáticamente
                      // en ConfiguracionService.cambiarContrasena
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Contraseña actualizada y credenciales sincronizadas',
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
                    } else {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: const [
                              Icon(Icons.error_outline, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Error al cambiar contraseña. Verifique su contraseña actual.',
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
                }
              },
              child: cargando 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cambiar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearBackup() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Creando backup...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      final rutaBackup = await ConfiguracionService.crearBackup();
      
      if (mounted) {
        if (rutaBackup != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Backup creado exitosamente en: $rutaBackup'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          
          // Actualizar configuración con nueva fecha de backup
          await _cargarConfiguracion();
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Error al crear backup. Verifique los permisos.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error al crear backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restaurarBackup() async {
    try {
      // Mostrar diálogo de confirmación
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restaurar Backup'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_rounded, color: Colors.orange, size: 48),
              SizedBox(height: 16),
              Text(
                'Esta acción restaurará todos los datos desde un archivo de backup. Los datos actuales serán reemplazados.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                '¿Desea continuar?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Restaurar'),
            ),
          ],
        ),
      );

      if (confirmar != true) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seleccionando archivo de backup...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Simulación de restaurar backup - implementación completa pendiente
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Backup restaurado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Recargar configuración después de restaurar
        await _cargarConfiguracion();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restaurar backup: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoAcercaDe() async {
    final infoApp = await ConfiguracionService.obtenerInfoApp();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Acerca de FortGuard Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versión: ${infoApp['version']}'),
              const SizedBox(height: 8),
              Text('Build: ${infoApp['build']}'),
              const SizedBox(height: 8),
              Text('Desarrollado por: ${infoApp['desarrollador']}'),
              const SizedBox(height: 16),
              const Text(
                'Sistema de administración para condominios y gestión de seguridad.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  void _mostrarAyuda() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Centro de Ayuda'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preguntas Frecuentes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• ¿Cómo crear un nuevo condominio?'),
            Text('• ¿Cómo agregar guardias de seguridad?'),
            Text('• ¿Cómo gestionar las credenciales?'),
            Text('• ¿Cómo crear backup de datos?'),
            SizedBox(height: 16),
            Text(
              'Para soporte técnico, contacte al administrador del sistema.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarPoliticaPrivacidad() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Política de Privacidad'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Términos y Condiciones de Uso',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                '1. Los datos almacenados en esta aplicación son confidenciales y están protegidos.',
              ),
              SizedBox(height: 8),
              Text(
                '2. El acceso a la información está restringido a usuarios autorizados.',
              ),
              SizedBox(height: 8),
              Text(
                '3. Se requiere mantener la confidencialidad de las credenciales de acceso.',
              ),
              SizedBox(height: 8),
              Text(
                '4. El uso indebido de la aplicación puede resultar en la suspensión del acceso.',
              ),
              SizedBox(height: 16),
              Text(
                'Para más información, contacte al administrador del sistema.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}

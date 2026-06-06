import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/guardia_model.dart';
import '../../services/guardia_service.dart';

class CrearGuardiaScreen extends StatefulWidget {
  final String condominioId;
  final GuardiaModel? guardia; // null = crear, no null = editar

  const CrearGuardiaScreen({
    super.key,
    required this.condominioId,
    this.guardia,
  });

  @override
  State<CrearGuardiaScreen> createState() => _CrearGuardiaScreenState();
}

class _CrearGuardiaScreenState extends State<CrearGuardiaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  
  String _turnoSeleccionado = 'diurno';
  String _tipoPerfilSeleccionado = 'recepcion';
  bool _activo = true;
  bool _guardando = false;

  bool get _esEdicion => widget.guardia != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargarDatosGuardia();
    }
  }

  void _cargarDatosGuardia() {
    final guardia = widget.guardia!;
    _nombreController.text = guardia.nombre;
    _apellidoController.text = guardia.apellido;
    _emailController.text = guardia.email;
    _telefonoController.text = guardia.telefono;
    _turnoSeleccionado = guardia.turno;
    _tipoPerfilSeleccionado = guardia.tipoPerfil;
    _activo = guardia.activo;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Guardia' : 'Nuevo Guardia'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSeccionDatosPersonales(),
            const SizedBox(height: 20),
            _buildSeccionTurno(),
            if (_esEdicion) ...[
              const SizedBox(height: 20),
              _buildSeccionEstado(),
            ],
            const SizedBox(height: 32),
            _buildBotones(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionDatosPersonales() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Datos Personales',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej: Juan',
                prefixIcon: const Icon(Icons.badge_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Requerido';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _apellidoController,
              decoration: InputDecoration(
                labelText: 'Apellido',
                hintText: 'Ej: Pérez',
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Requerido';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'correo@ejemplo.com',
                prefixIcon: const Icon(Icons.email_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El email es requerido';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Email inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoController,
              decoration: InputDecoration(
                labelText: 'Teléfono',
                hintText: 'Ej: 77712345',
                prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El teléfono es requerido';
                }
                if (value.trim().length < 8) {
                  return 'Teléfono inválido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTurno() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Turno de Trabajo
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Turno de Trabajo',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOpcionTurno(
                    titulo: 'Diurno',
                    subtitulo: '6:00 AM - 6:00 PM',
                    icono: Icons.wb_sunny_rounded,
                    color: Colors.orange,
                    seleccionado: _turnoSeleccionado == 'diurno',
                    onTap: () => setState(() => _turnoSeleccionado = 'diurno'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOpcionTurno(
                    titulo: 'Nocturno',
                    subtitulo: '6:00 PM - 6:00 AM',
                    icono: Icons.nightlight_rounded,
                    color: Colors.indigo,
                    seleccionado: _turnoSeleccionado == 'nocturno',
                    onTap: () => setState(() => _turnoSeleccionado = 'nocturno'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Tipo de Perfil
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tipo de Perfil',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOpcionTurno(
                    titulo: 'Recepción',
                    subtitulo: 'Control de acceso',
                    icono: Icons.desk_rounded,
                    color: Colors.blue,
                    seleccionado: _tipoPerfilSeleccionado == 'recepcion',
                    onTap: () => setState(() => _tipoPerfilSeleccionado = 'recepcion'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildOpcionTurno(
                    titulo: 'Vigilancia',
                    subtitulo: 'Rondas y seguridad',
                    icono: Icons.visibility_rounded,
                    color: Colors.green,
                    seleccionado: _tipoPerfilSeleccionado == 'vigilancia',
                    onTap: () => setState(() => _tipoPerfilSeleccionado = 'vigilancia'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcionTurno({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado 
              ? color.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              color: seleccionado ? color : (isDark ? Colors.white54 : Colors.grey),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: seleccionado ? color : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitulo,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEstado() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (_activo ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _activo ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                color: _activo ? Colors.green : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _activo ? 'Guardia Activo' : 'Guardia Inactivo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _activo 
                        ? 'Disponible para turnos'
                        : 'No disponible',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _activo,
              onChanged: (value) => setState(() => _activo = value),
              activeColor: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotones() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardarGuardia,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _esEdicion ? 'Actualizar' : 'Crear Guardia',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarCredenciales(String email, String password) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Credenciales del guardia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guardalas y comunicáselas al guardia. La contraseña no se vuelve '
              'a mostrar.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            SelectableText('Email: $email'),
            const SizedBox(height: 4),
            SelectableText(
              'Contraseña: $password',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: 'Email: $email\nContraseña: $password'),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  Future<void> _guardarGuardia() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
    });

    try {
      // Verificar email único
      final emailExiste = await GuardiaService.emailExiste(
        _emailController.text.trim(),
        widget.condominioId,
        excludeId: _esEdicion ? widget.guardia!.id : null,
      );

      if (emailExiste) {
        throw Exception('Ya existe un guardia con este email');
      }

      final guardia = GuardiaModel(
        id: _esEdicion ? widget.guardia!.id : '',
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        email: _emailController.text.trim(),
        telefono: _telefonoController.text.trim(),
        condominioId: widget.condominioId,
        turno: _turnoSeleccionado,
        tipoPerfil: _tipoPerfilSeleccionado,
        activo: _activo,
        fechaIngreso: _esEdicion ? widget.guardia!.fechaIngreso : DateTime.now(),
      );

      String? passGenerada;
      if (_esEdicion) {
        await GuardiaService.actualizar(guardia.id, guardia);
      } else {
        passGenerada = await GuardiaService.crear(guardia);
      }

      if (!mounted) return;

      if (!_esEdicion && passGenerada != null && passGenerada.isNotEmpty) {
        await _mostrarCredenciales(guardia.email.trim(), passGenerada);
        if (!mounted) return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion ? 'Guardia actualizado' : 'Guardia creado'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.pop(context, true); // true indica que se guardó exitosamente

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }
}

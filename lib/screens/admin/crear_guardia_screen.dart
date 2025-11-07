import 'package:flutter/material.dart';
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
          padding: const EdgeInsets.all(16),
          children: [
            _buildSeccionDatosPersonales(),
            const SizedBox(height: 24),
            _buildSeccionTurno(),
            const SizedBox(height: 24),
            _buildSeccionEstado(),
            const SizedBox(height: 32),
            _buildBotones(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionDatosPersonales() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Datos Personales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _apellidoController,
                    decoration: InputDecoration(
                      labelText: 'Apellido',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _telefonoController,
              decoration: InputDecoration(
                labelText: 'Teléfono',
                prefixIcon: const Icon(Icons.phone_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Turno de Trabajo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'diurno',
                  label: const Text('Diurno'),
                  icon: const Icon(Icons.wb_sunny_rounded),
                ),
                ButtonSegment(
                  value: 'nocturno',
                  label: const Text('Nocturno'),
                  icon: const Icon(Icons.nightlight_rounded),
                ),
              ],
              selected: {_turnoSeleccionado},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _turnoSeleccionado = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _turnoSeleccionado == 'diurno'
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _turnoSeleccionado == 'diurno'
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.indigo.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _turnoSeleccionado == 'diurno'
                        ? Icons.wb_sunny_rounded
                        : Icons.nightlight_rounded,
                    color: _turnoSeleccionado == 'diurno'
                        ? Colors.orange
                        : Colors.indigo,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _turnoSeleccionado == 'diurno' ? 'Turno Diurno' : 'Turno Nocturno',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _turnoSeleccionado == 'diurno'
                                ? Colors.orange
                                : Colors.indigo,
                          ),
                        ),
                        Text(
                          _turnoSeleccionado == 'diurno' ? '6:00 AM - 6:00 PM' : '6:00 PM - 6:00 AM',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Tipo de Perfil
            Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Tipo de Perfil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'recepcion',
                  label: const Text('Recepción'),
                  icon: const Icon(Icons.desk_rounded),
                ),
                ButtonSegment(
                  value: 'vigilancia',
                  label: const Text('Vigilancia'),
                  icon: const Icon(Icons.visibility_rounded),
                ),
              ],
              selected: {_tipoPerfilSeleccionado},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _tipoPerfilSeleccionado = selection.first;
                });
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _tipoPerfilSeleccionado == 'recepcion'
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _tipoPerfilSeleccionado == 'recepcion'
                      ? Colors.blue.withValues(alpha: 0.3)
                      : Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _tipoPerfilSeleccionado == 'recepcion'
                        ? Icons.desk_rounded
                        : Icons.visibility_rounded,
                    color: _tipoPerfilSeleccionado == 'recepcion'
                        ? Colors.blue
                        : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tipoPerfilSeleccionado == 'recepcion' ? 'Guardia de Recepción' : 'Guardia de Vigilancia',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _tipoPerfilSeleccionado == 'recepcion'
                                ? Colors.blue
                                : Colors.green,
                          ),
                        ),
                        Text(
                          _tipoPerfilSeleccionado == 'recepcion' 
                              ? 'Atención en recepción y control de acceso'
                              : 'Rondas de vigilancia y seguridad perimetral',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEstado() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.toggle_on_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Estado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: Text(
                _activo ? 'Guardia Activo' : 'Guardia Inactivo',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                _activo 
                    ? 'El guardia puede ser asignado a turnos'
                    : 'El guardia no estará disponible para turnos',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              value: _activo,
              onChanged: (value) {
                setState(() {
                  _activo = value;
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotones() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _guardando ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                : Text(_esEdicion ? 'Actualizar' : 'Crear Guardia'),
          ),
        ),
      ],
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

      if (_esEdicion) {
        await GuardiaService.actualizar(guardia.id, guardia);
      } else {
        await GuardiaService.crear(guardia);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_esEdicion ? 'Guardia actualizado' : 'Guardia creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

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

import 'package:flutter/material.dart';
import '../../models/notificacion_model.dart';
import '../../services/notificacion_service.dart';

class CrearNotificacionScreen extends StatefulWidget {
  final String condominioId;
  final NotificacionModel? notificacion; // null = crear, no null = editar

  const CrearNotificacionScreen({
    super.key,
    required this.condominioId,
    this.notificacion,
  });

  @override
  State<CrearNotificacionScreen> createState() => _CrearNotificacionScreenState();
}

class _CrearNotificacionScreenState extends State<CrearNotificacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _mensajeController = TextEditingController();
  
  PrioridadNotificacion _prioridad = PrioridadNotificacion.media;
  TipoRepeticion _repeticion = TipoRepeticion.ninguna;
  List<String> _destinatarios = ['todos'];
  bool _esProgramada = false;
  DateTime? _fechaProgramada;
  TimeOfDay? _horaProgramada;
  bool _guardando = false;

  bool get _esEdicion => widget.notificacion != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargarDatosNotificacion();
    }
  }

  void _cargarDatosNotificacion() {
    final notificacion = widget.notificacion!;
    _tituloController.text = notificacion.titulo;
    _mensajeController.text = notificacion.mensaje;
    _prioridad = notificacion.prioridad;
    _repeticion = notificacion.repeticion;
    _destinatarios = List.from(notificacion.destinatarios);
    _esProgramada = notificacion.esProgramada;
    if (notificacion.fechaProgramada != null) {
      _fechaProgramada = DateTime(
        notificacion.fechaProgramada!.year,
        notificacion.fechaProgramada!.month,
        notificacion.fechaProgramada!.day,
      );
      _horaProgramada = TimeOfDay(
        hour: notificacion.fechaProgramada!.hour,
        minute: notificacion.fechaProgramada!.minute,
      );
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _mensajeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Notificación' : 'Nueva Notificación'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSeccionContenido(),
            const SizedBox(height: 24),
            _buildSeccionPrioridad(),
            const SizedBox(height: 24),
            _buildSeccionDestinatarios(),
            const SizedBox(height: 24),
            _buildSeccionProgramacion(),
            if (_repeticion != TipoRepeticion.ninguna) ...[
              const SizedBox(height: 24),
              _buildSeccionRepeticion(),
            ],
            const SizedBox(height: 32),
            _buildBotones(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionContenido() {
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
                  Icons.message_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Contenido de la Notificación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _tituloController,
              decoration: InputDecoration(
                labelText: 'Título',
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                hintText: 'Ej: Mantenimiento programado',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es requerido';
                }
                if (value.trim().length < 3) {
                  return 'El título debe tener al menos 3 caracteres';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mensajeController,
              decoration: InputDecoration(
                labelText: 'Mensaje',
                prefixIcon: const Icon(Icons.description_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                hintText: 'Describe los detalles de la notificación...',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El mensaje es requerido';
                }
                if (value.trim().length < 10) {
                  return 'El mensaje debe tener al menos 10 caracteres';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionPrioridad() {
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
                  Icons.priority_high_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Prioridad',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PrioridadNotificacion.values.map((prioridad) {
                final isSelected = _prioridad == prioridad;
                Color color;
                switch (prioridad) {
                  case PrioridadNotificacion.baja:
                    color = Colors.grey;
                    break;
                  case PrioridadNotificacion.media:
                    color = Colors.blue;
                    break;
                  case PrioridadNotificacion.alta:
                    color = Colors.orange;
                    break;
                  case PrioridadNotificacion.urgente:
                    color = Colors.red;
                    break;
                }

                return FilterChip(
                  label: Text(
                    prioridad.name.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _prioridad = prioridad;
                    });
                  },
                  backgroundColor: color.withValues(alpha: 0.1),
                  selectedColor: color,
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionDestinatarios() {
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
                  Icons.people_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Destinatarios',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              title: const Text('Todos los usuarios'),
              subtitle: const Text('Propietarios y residentes'),
              value: _destinatarios.contains('todos'),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _destinatarios = ['todos'];
                  } else {
                    _destinatarios.remove('todos');
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Solo propietarios'),
              subtitle: const Text('Únicamente los dueños de las casas'),
              value: _destinatarios.contains('propietarios'),
              onChanged: _destinatarios.contains('todos') ? null : (value) {
                setState(() {
                  if (value == true) {
                    _destinatarios.add('propietarios');
                  } else {
                    _destinatarios.remove('propietarios');
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Solo residentes'),
              subtitle: const Text('Únicamente los habitantes de las casas'),
              value: _destinatarios.contains('residentes'),
              onChanged: _destinatarios.contains('todos') ? null : (value) {
                setState(() {
                  if (value == true) {
                    _destinatarios.add('residentes');
                  } else {
                    _destinatarios.remove('residentes');
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionProgramacion() {
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
                  'Programación',
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
              title: const Text('Programar envío'),
              subtitle: Text(
                _esProgramada 
                    ? 'Se enviará en la fecha y hora seleccionada'
                    : 'Se enviará inmediatamente',
              ),
              value: _esProgramada,
              onChanged: (value) {
                setState(() {
                  _esProgramada = value;
                  if (!value) {
                    _fechaProgramada = null;
                    _horaProgramada = null;
                    _repeticion = TipoRepeticion.ninguna;
                  }
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            if (_esProgramada) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seleccionarFecha(),
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(
                        _fechaProgramada != null
                            ? '${_fechaProgramada!.day}/${_fechaProgramada!.month}/${_fechaProgramada!.year}'
                            : 'Seleccionar fecha',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _seleccionarHora(),
                      icon: const Icon(Icons.access_time_rounded),
                      label: Text(
                        _horaProgramada != null
                            ? '${_horaProgramada!.hour.toString().padLeft(2, '0')}:${_horaProgramada!.minute.toString().padLeft(2, '0')}'
                            : 'Seleccionar hora',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TipoRepeticion>(
                value: _repeticion,
                decoration: InputDecoration(
                  labelText: 'Repetición',
                  prefixIcon: const Icon(Icons.repeat_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                ),
                items: TipoRepeticion.values.map((repeticion) {
                  return DropdownMenuItem(
                    value: repeticion,
                    child: Text(repeticion.name == 'ninguna' ? 'Sin repetición' : repeticion.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _repeticion = value!;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionRepeticion() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.purple.withValues(alpha: 0.05),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.repeat_rounded,
                  color: Colors.purple,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Notificación Recurrente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Esta notificación se repetirá ${_repeticion.name.toLowerCase()} automáticamente.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes cancelar la repetición en cualquier momento desde la lista de notificaciones.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
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
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardarNotificacion,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(_esProgramada ? Icons.schedule_send_rounded : Icons.send_rounded),
            label: Text(
              _guardando
                  ? 'Guardando...'
                  : _esProgramada
                      ? (_esEdicion ? 'Actualizar' : 'Programar')
                      : (_esEdicion ? 'Actualizar' : 'Enviar Ahora'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaProgramada ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (fecha != null) {
      setState(() {
        _fechaProgramada = fecha;
      });
    }
  }

  Future<void> _seleccionarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _horaProgramada ?? TimeOfDay.now(),
    );

    if (hora != null) {
      setState(() {
        _horaProgramada = hora;
      });
    }
  }

  Future<void> _guardarNotificacion() async {
    if (!_formKey.currentState!.validate()) return;

    if (_esProgramada && (_fechaProgramada == null || _horaProgramada == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha y hora para notificaciones programadas'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_destinatarios.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un tipo de destinatario'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      DateTime? fechaProgramadaCompleta;
      if (_esProgramada && _fechaProgramada != null && _horaProgramada != null) {
        fechaProgramadaCompleta = DateTime(
          _fechaProgramada!.year,
          _fechaProgramada!.month,
          _fechaProgramada!.day,
          _horaProgramada!.hour,
          _horaProgramada!.minute,
        );
      }

      final notificacion = NotificacionModel(
        id: _esEdicion ? widget.notificacion!.id : '',
        condominioId: widget.condominioId,
        titulo: _tituloController.text.trim(),
        mensaje: _mensajeController.text.trim(),
        prioridad: _prioridad,
        fechaCreacion: _esEdicion ? widget.notificacion!.fechaCreacion : DateTime.now(),
        fechaProgramada: fechaProgramadaCompleta,
        repeticion: _repeticion,
        estado: EstadoNotificacion.programada,
        destinatarios: _destinatarios,
        creadoPor: 'admin', // TODO: Obtener del usuario actual
      );

      if (_esEdicion) {
        await NotificacionService.actualizar(notificacion.id, notificacion.toFirestore());
      } else {
        if (_esProgramada) {
          await NotificacionService.programar(notificacion);
        } else {
          await NotificacionService.enviarInmediata(notificacion);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _esEdicion 
                ? 'Notificación actualizada'
                : _esProgramada 
                    ? 'Notificación programada exitosamente'
                    : 'Notificación enviada exitosamente'
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);

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

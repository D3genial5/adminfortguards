import 'package:flutter/material.dart';
import '../../models/turno_model.dart';
import '../../models/guardia_model.dart';
import '../../services/turno_service.dart';
import '../../services/guardia_service.dart';

class TurnoActualScreen extends StatefulWidget {
  final String condominioId;

  const TurnoActualScreen({
    super.key,
    required this.condominioId,
  });

  @override
  State<TurnoActualScreen> createState() => _TurnoActualScreenState();
}

class _TurnoActualScreenState extends State<TurnoActualScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Turno Actual'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: StreamBuilder<TurnoModel?>(
        stream: TurnoService.streamTurnoActual(widget.condominioId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                ],
              ),
            );
          }

          final turno = snapshot.data;

          if (turno == null) {
            return _buildSinTurnoActivo();
          }

          return _buildTurnoActivo(turno);
        },
      ),
    );
  }

  Widget _buildSinTurnoActivo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEstadoCard(
            titulo: 'Sin Turno Activo',
            icono: Icons.schedule_rounded,
            color: Colors.orange,
            contenido: 'No hay ningún guardia en turno en este momento.',
          ),
          const SizedBox(height: 24),
          _buildAccionesRapidas(),
          const SizedBox(height: 24),
          _buildProximosTurnos(),
        ],
      ),
    );
  }

  Widget _buildTurnoActivo(TurnoModel turno) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoGuardia(turno),
          const SizedBox(height: 16),
          _buildInfoTurno(turno),
          const SizedBox(height: 16),
          _buildReportesAcceso(turno),
          const SizedBox(height: 24),
          _buildAccionesTurno(turno),
        ],
      ),
    );
  }

  Widget _buildInfoGuardia(TurnoModel turno) {
    return FutureBuilder<GuardiaModel?>(
      future: GuardiaService.obtenerPorId(turno.guardiaId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ));
        }

        final guardia = snapshot.data!;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Icon(
                        guardia.esDiurno ? Icons.wb_sunny_rounded : Icons.nightlight_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Guardia en Turno',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            guardia.nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            guardia.turnoDisplay,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'ACTIVO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        Icons.email_rounded,
                        'Email',
                        guardia.email,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoItem(
                        Icons.phone_rounded,
                        'Teléfono',
                        guardia.telefono,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(IconData icono, String label, String valor) {
    return Row(
      children: [
        Icon(icono, color: Colors.white.withValues(alpha: 0.8), size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                valor,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTurno(TurnoModel turno) {
    final duracionTranscurrida = DateTime.now().difference(turno.fechaInicio);
    final duracionTotal = turno.fechaFin.difference(turno.fechaInicio);
    final progreso = duracionTranscurrida.inMinutes / duracionTotal.inMinutes;

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
                  Icons.access_time_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Información del Turno',
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
                  child: _buildTurnoInfo(
                    'Inicio',
                    '${turno.fechaInicio.hour.toString().padLeft(2, '0')}:${turno.fechaInicio.minute.toString().padLeft(2, '0')}',
                    Icons.play_arrow_rounded,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTurnoInfo(
                    'Fin',
                    '${turno.fechaFin.hour.toString().padLeft(2, '0')}:${turno.fechaFin.minute.toString().padLeft(2, '0')}',
                    Icons.stop_rounded,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTurnoInfo(
                    'Duración',
                    '${duracionTotal.inHours}h ${(duracionTotal.inMinutes % 60)}m',
                    Icons.schedule_rounded,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Progreso del Turno',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0),
              backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progreso * 100).clamp(0, 100).toInt()}% completado',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnoInfo(String label, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportesAcceso(TurnoModel turno) {
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
                  Icons.assignment_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Accesos Registrados',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${turno.totalAccesos}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (turno.reportes.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sin accesos registrados',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...turno.reportes.take(5).map((reporte) => _buildReporteItem(reporte)),
            if (turno.reportes.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    // TODO: Mostrar todos los reportes
                  },
                  child: Text('Ver todos (${turno.reportes.length})'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReporteItem(ReporteAcceso reporte) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reporte.visitante,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'Casa ${reporte.casa} • ${reporte.motivo}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            reporte.horaFormateada,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccionesTurno(TurnoModel turno) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _agregarReporte(turno),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar Acceso'),
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
          child: ElevatedButton.icon(
            onPressed: () => _finalizarTurno(turno),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Finalizar Turno'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoCard({
    required String titulo,
    required IconData icono,
    required Color color,
    required String contenido,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icono, color: color, size: 48),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              contenido,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acciones Rápidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _iniciarTurno('diurno'),
                    icon: const Icon(Icons.wb_sunny_rounded),
                    label: const Text('Iniciar Diurno'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _iniciarTurno('nocturno'),
                    icon: const Icon(Icons.nightlight_rounded),
                    label: const Text('Iniciar Nocturno'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProximosTurnos() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Próximos Turnos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Funcionalidad próximamente',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _agregarReporte(TurnoModel turno) {
    final formKey = GlobalKey<FormState>();
    final visitanteController = TextEditingController();
    final casaController = TextEditingController();
    final motivoController = TextEditingController();
    final observacionesController = TextEditingController();
    String tipoVisita = 'Visitante';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Acceso'),
        content: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tipo de visita
                  DropdownButtonFormField<String>(
                    value: tipoVisita,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de Visita',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Visitante', child: Text('Visitante')),
                      DropdownMenuItem(value: 'Delivery', child: Text('Delivery')),
                      DropdownMenuItem(value: 'Servicio', child: Text('Servicio Técnico')),
                      DropdownMenuItem(value: 'Proveedor', child: Text('Proveedor')),
                      DropdownMenuItem(value: 'Emergencia', child: Text('Emergencia')),
                    ],
                    onChanged: (value) => tipoVisita = value!,
                  ),
                  const SizedBox(height: 16),
                  
                  // Nombre del visitante
                  TextFormField(
                    controller: visitanteController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Visitante',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingrese el nombre del visitante';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Casa destino
                  TextFormField(
                    controller: casaController,
                    decoration: const InputDecoration(
                      labelText: 'Casa/Departamento',
                      prefixIcon: Icon(Icons.home),
                      border: OutlineInputBorder(),
                      hintText: 'Ej: A-101, Casa 25, etc.',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingrese la casa o departamento';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Motivo de la visita
                  TextFormField(
                    controller: motivoController,
                    decoration: const InputDecoration(
                      labelText: 'Motivo de la Visita',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                      hintText: 'Breve descripción del motivo',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingrese el motivo de la visita';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Observaciones adicionales
                  TextFormField(
                    controller: observacionesController,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (Opcional)',
                      prefixIcon: Icon(Icons.note),
                      border: OutlineInputBorder(),
                      hintText: 'Información adicional relevante',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                // Capturar referencias antes del await
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                
                try {
                  final nuevoReporte = ReporteAcceso(
                    id: '',
                    turnoId: turno.id,
                    visitante: visitanteController.text.trim(),
                    casa: casaController.text.trim(),
                    horaEntrada: DateTime.now(),
                    motivo: motivoController.text.trim(),
                    tipoVisita: tipoVisita,
                    observaciones: observacionesController.text.trim(),
                    fechaHora: DateTime.now(),
                  );
                  
                  await TurnoService.agregarReporteAcceso(turno.id, nuevoReporte);
                  
                  if (mounted) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Acceso registrado exitosamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error al registrar acceso: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _finalizarTurno(TurnoModel turno) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Turno'),
        content: const Text('¿Estás seguro que deseas finalizar el turno actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await TurnoService.finalizarTurno(turno.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno finalizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _iniciarTurno(String tipoTurno) async {
    // Capturar referencia antes de operaciones async
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      // Obtener guardias activos del tipo de turno
      final guardias = await GuardiaService.obtenerGuardiasPorTurno(tipoTurno);
      
      if (guardias.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('No hay guardias activos para turno $tipoTurno'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      
      // Mostrar selector de guardia
      final guardiaSeleccionado = await showDialog<GuardiaModel>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Seleccionar Guardia - Turno ${tipoTurno.toUpperCase()}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Selecciona el guardia que iniciará el turno $tipoTurno:',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: guardias.length,
                    itemBuilder: (context, index) {
                      final guardia = guardias[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              guardia.nombre[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text('${guardia.nombre} ${guardia.apellido}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Email: ${guardia.email}'),
                              Text('Teléfono: ${guardia.telefono}'),
                              Text(
                                'Turno: ${guardia.esDiurno ? "Diurno" : "Nocturno"}',
                                style: TextStyle(
                                  color: guardia.esDiurno ? Colors.orange : Colors.indigo,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          onTap: () => Navigator.of(context).pop(guardia),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (guardiaSeleccionado != null && mounted) {
        // Confirmar inicio de turno
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar Inicio de Turno'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Iniciar turno $tipoTurno con el siguiente guardia?'),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${guardiaSeleccionado.nombre} ${guardiaSeleccionado.apellido}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Email: ${guardiaSeleccionado.email}'),
                        Text('Teléfono: ${guardiaSeleccionado.telefono}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hora de inicio: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
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
                child: const Text('Iniciar Turno'),
              ),
            ],
          ),
        );

        if (confirmar == true) {
          try {
            // Crear nuevo turno
            final nuevoTurno = TurnoModel(
              id: '',
              guardiaId: guardiaSeleccionado.id,
              condominioId: 'default', // TODO: Obtener condominio actual
              fechaInicio: DateTime.now(),
              fechaFin: DateTime.now().add(const Duration(hours: 12)), // Turno de 12 horas
              estado: 'activo',
              reportes: [],
            );

            await TurnoService.iniciarTurno(nuevoTurno);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Turno $tipoTurno iniciado exitosamente'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error al iniciar turno: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar guardias: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

import 'package:flutter/material.dart';
import '../../models/notificacion_model.dart';
import '../../services/notificacion_service.dart';
import 'crear_notificacion_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  final String condominioId;

  const NotificacionesScreen({
    super.key,
    required this.condominioId,
  });

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _mostrarFormularioNotificacion(),
            tooltip: 'Nueva Notificación',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Programadas', icon: Icon(Icons.schedule_rounded)),
            Tab(text: 'Enviadas', icon: Icon(Icons.check_circle_rounded)),
            Tab(text: 'Todas', icon: Icon(Icons.list_rounded)),
          ],
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      body: Column(
        children: [
          _buildEstadisticas(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListaNotificaciones(EstadoNotificacion.programada),
                _buildListaNotificaciones(EstadoNotificacion.enviada),
                _buildListaNotificaciones(null), // Todas
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    return FutureBuilder<Map<String, int>>(
      future: NotificacionService.obtenerEstadisticas(
        widget.condominioId,
        DateTime.now().subtract(const Duration(days: 30)),
        DateTime.now(),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatCard('Total', stats['total']!, Icons.notifications_rounded, Colors.blue),
              const SizedBox(width: 8),
              _buildStatCard('Enviadas', stats['enviadas']!, Icons.check_circle_rounded, Colors.green),
              const SizedBox(width: 8),
              _buildStatCard('Programadas', stats['programadas']!, Icons.schedule_rounded, Colors.orange),
              const SizedBox(width: 8),
              _buildStatCard('Urgentes', stats['urgentes']!, Icons.priority_high_rounded, Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaNotificaciones(EstadoNotificacion? filtroEstado) {
    return StreamBuilder<List<NotificacionModel>>(
      stream: NotificacionService.streamPorCondominio(widget.condominioId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final todasNotificaciones = snapshot.data!;
        final notificaciones = filtroEstado != null
            ? todasNotificaciones.where((n) => n.estado == filtroEstado).toList()
            : todasNotificaciones;

        if (notificaciones.isEmpty) {
          return _buildEmptyState(esFiltrado: true);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notificaciones.length,
          itemBuilder: (context, index) {
            return _buildNotificacionCard(notificaciones[index]);
          },
        );
      },
    );
  }

  Widget _buildNotificacionCard(NotificacionModel notificacion) {
    Color prioridadColor;
    switch (notificacion.prioridad) {
      case PrioridadNotificacion.baja:
        prioridadColor = Colors.grey;
        break;
      case PrioridadNotificacion.media:
        prioridadColor = Colors.blue;
        break;
      case PrioridadNotificacion.alta:
        prioridadColor = Colors.orange;
        break;
      case PrioridadNotificacion.urgente:
        prioridadColor = Colors.red;
        break;
    }

    Color estadoColor;
    switch (notificacion.estado) {
      case EstadoNotificacion.programada:
        estadoColor = Colors.orange;
        break;
      case EstadoNotificacion.enviada:
        estadoColor = Colors.green;
        break;
      case EstadoNotificacion.cancelada:
        estadoColor = Colors.red;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: prioridadColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: prioridadColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notificacion.titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notificacion.mensaje,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _manejarAccionNotificacion(value, notificacion),
                  itemBuilder: (_) => [
                    if (notificacion.estaPendiente) ...[
                      const PopupMenuItem(value: 'enviar', child: Text('Enviar Ahora')),
                      const PopupMenuItem(value: 'editar', child: Text('Editar')),
                      const PopupMenuItem(value: 'cancelar', child: Text('Cancelar')),
                    ],
                    if (notificacion.tieneRepeticion && notificacion.estaEnviada)
                      const PopupMenuItem(value: 'reprogramar', child: Text('Reprogramar')),
                    const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildChip(
                  notificacion.prioridadDisplay,
                  prioridadColor,
                  Icons.priority_high_rounded,
                ),
                _buildChip(
                  notificacion.estadoDisplay,
                  estadoColor,
                  _getEstadoIcon(notificacion.estado),
                ),
                if (notificacion.esProgramada)
                  _buildChip(
                    '${notificacion.fechaProgramada!.day}/${notificacion.fechaProgramada!.month} ${notificacion.fechaProgramada!.hour.toString().padLeft(2, '0')}:${notificacion.fechaProgramada!.minute.toString().padLeft(2, '0')}',
                    Colors.blue,
                    Icons.schedule_rounded,
                  ),
                if (notificacion.tieneRepeticion)
                  _buildChip(
                    notificacion.repeticionDisplay,
                    Colors.purple,
                    Icons.repeat_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Para: ${notificacion.destinatariosDisplay}',
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

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getEstadoIcon(EstadoNotificacion estado) {
    switch (estado) {
      case EstadoNotificacion.programada:
        return Icons.schedule_rounded;
      case EstadoNotificacion.enviada:
        return Icons.check_circle_rounded;
      case EstadoNotificacion.cancelada:
        return Icons.cancel_rounded;
    }
  }

  Widget _buildEmptyState({bool esFiltrado = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            esFiltrado ? 'No hay notificaciones en esta categoría' : 'No hay notificaciones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            esFiltrado 
                ? 'Cambia de pestaña para ver otras notificaciones'
                : 'Crea tu primera notificación para comenzar',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (!esFiltrado) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormularioNotificacion(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva Notificación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _mostrarFormularioNotificacion([NotificacionModel? notificacion]) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CrearNotificacionScreen(
          condominioId: widget.condominioId,
          notificacion: notificacion,
        ),
      ),
    );

    if (resultado == true && mounted) {
      // El stream se actualizará automáticamente
    }
  }

  void _manejarAccionNotificacion(String accion, NotificacionModel notificacion) async {
    switch (accion) {
      case 'enviar':
        await _enviarAhora(notificacion);
        break;
      case 'editar':
        _mostrarFormularioNotificacion(notificacion);
        break;
      case 'cancelar':
        await _cancelarNotificacion(notificacion);
        break;
      case 'reprogramar':
        await _reprogramarNotificacion(notificacion);
        break;
      case 'eliminar':
        await _eliminarNotificacion(notificacion);
        break;
    }
  }

  Future<void> _enviarAhora(NotificacionModel notificacion) async {
    try {
      await NotificacionService.enviarInmediata(notificacion);
      await NotificacionService.marcarComoEnviada(notificacion.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notificación enviada exitosamente'),
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

  Future<void> _cancelarNotificacion(NotificacionModel notificacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Notificación'),
        content: Text('¿Estás seguro que deseas cancelar "${notificacion.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await NotificacionService.cancelar(notificacion.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificación cancelada')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _reprogramarNotificacion(NotificacionModel notificacion) async {
    try {
      await NotificacionService.reprogramarRecurrente(notificacion);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificación reprogramada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _eliminarNotificacion(NotificacionModel notificacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Notificación'),
        content: Text('¿Estás seguro que deseas eliminar "${notificacion.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await NotificacionService.eliminar(notificacion.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notificación eliminada')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

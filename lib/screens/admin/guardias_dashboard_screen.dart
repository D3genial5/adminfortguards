import 'package:flutter/material.dart';
import '../../models/guardia_model.dart';
import '../../services/guardia_service.dart';
import 'crear_guardia_screen.dart';

class GuardiasDashboardScreen extends StatefulWidget {
  final String condominioId;
  
  const GuardiasDashboardScreen({
    super.key,
    required this.condominioId,
  });

  @override
  State<GuardiasDashboardScreen> createState() => _GuardiasDashboardScreenState();
}

class _GuardiasDashboardScreenState extends State<GuardiasDashboardScreen> {
  String _filtroTurno = 'todos'; // 'todos', 'diurno', 'nocturno'
  bool _soloActivos = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Gestión de Guardias'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _mostrarFormularioGuardia(),
            tooltip: 'Agregar Guardia',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltros(),
          _buildEstadisticas(),
          Expanded(child: _buildListaGuardias()),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'todos', label: Text('Todos')),
                ButtonSegment(value: 'diurno', label: Text('Diurnos')),
                ButtonSegment(value: 'nocturno', label: Text('Nocturnos')),
              ],
              selected: {_filtroTurno},
              onSelectionChanged: (Set<String> selection) {
                setState(() {
                  _filtroTurno = selection.first;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: const Text('Solo Activos'),
            selected: _soloActivos,
            onSelected: (selected) {
              setState(() {
                _soloActivos = selected;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    return FutureBuilder<Map<String, int>>(
      future: GuardiaService.obtenerEstadisticas(widget.condominioId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatCard('Total', stats['total']!, Icons.people_rounded),
              const SizedBox(width: 12),
              _buildStatCard('Activos', stats['activos']!, Icons.check_circle_rounded),
              const SizedBox(width: 12),
              _buildStatCard('Diurnos', stats['diurnos']!, Icons.wb_sunny_rounded),
              const SizedBox(width: 12),
              _buildStatCard('Nocturnos', stats['nocturnos']!, Icons.nightlight_rounded),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
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
      ),
    );
  }

  Widget _buildListaGuardias() {
    return StreamBuilder<List<GuardiaModel>>(
      stream: GuardiaService.streamPorCondominio(widget.condominioId),
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

        final guardias = _filtrarGuardias(snapshot.data!);

        if (guardias.isEmpty) {
          return _buildEmptyState(esFiltrado: true);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: guardias.length,
          itemBuilder: (context, index) {
            return _buildGuardiaCard(guardias[index]);
          },
        );
      },
    );
  }

  List<GuardiaModel> _filtrarGuardias(List<GuardiaModel> guardias) {
    return guardias.where((guardia) {
      // Filtro por estado
      if (_soloActivos && !guardia.activo) return false;
      
      // Filtro por turno
      if (_filtroTurno != 'todos' && guardia.turno != _filtroTurno) return false;
      
      return true;
    }).toList();
  }

  Widget _buildGuardiaCard(GuardiaModel guardia) {
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
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: guardia.activo
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            guardia.esDiurno ? Icons.wb_sunny_rounded : Icons.nightlight_rounded,
            color: guardia.activo
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            size: 24,
          ),
        ),
        title: Text(
          guardia.nombre,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              guardia.email,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: guardia.esDiurno
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.indigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    guardia.turnoDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: guardia.esDiurno ? Colors.orange : Colors.indigo,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: guardia.activo
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    guardia.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: guardia.activo ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          onSelected: (value) => _manejarAccionGuardia(value, guardia),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'editar', child: Text('Editar')),
            PopupMenuItem(
              value: guardia.activo ? 'desactivar' : 'activar',
              child: Text(guardia.activo ? 'Desactivar' : 'Activar'),
            ),
            const PopupMenuItem(value: 'eliminar', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool esFiltrado = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            esFiltrado ? 'No hay guardias con estos filtros' : 'No hay guardias registrados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            esFiltrado 
                ? 'Intenta cambiar los filtros'
                : 'Agrega el primer guardia para comenzar',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (!esFiltrado) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _mostrarFormularioGuardia(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar Guardia'),
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

  void _mostrarFormularioGuardia([GuardiaModel? guardia]) async {
    final resultado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CrearGuardiaScreen(
          condominioId: widget.condominioId,
          guardia: guardia,
        ),
      ),
    );

    // Si se guardó exitosamente, el stream se actualizará automáticamente
    if (resultado == true && mounted) {
      // Opcional: mostrar mensaje de confirmación adicional
    }
  }

  void _manejarAccionGuardia(String accion, GuardiaModel guardia) async {
    switch (accion) {
      case 'editar':
        _mostrarFormularioGuardia(guardia);
        break;
      case 'activar':
      case 'desactivar':
        await _cambiarEstadoGuardia(guardia);
        break;
      case 'eliminar':
        await _confirmarEliminarGuardia(guardia);
        break;
    }
  }

  Future<void> _cambiarEstadoGuardia(GuardiaModel guardia) async {
    try {
      await GuardiaService.cambiarEstado(guardia.id, !guardia.activo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            guardia.activo 
                ? 'Guardia desactivado' 
                : 'Guardia activado'
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _confirmarEliminarGuardia(GuardiaModel guardia) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Guardia'),
        content: Text('¿Estás seguro que deseas eliminar a ${guardia.nombre}?'),
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
        await GuardiaService.eliminar(guardia.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardia eliminado')),
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

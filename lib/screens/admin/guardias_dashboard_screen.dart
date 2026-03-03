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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF6EEE3),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: const Text(
                'Gestión de Guardias',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.person_add_rounded, color: Theme.of(context).colorScheme.primary),
                  onPressed: () => _mostrarFormularioGuardia(),
                  tooltip: 'Agregar Guardia',
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildFiltros()),
          SliverToBoxAdapter(child: _buildEstadisticas()),
          SliverFillRemaining(child: _buildListaGuardias()),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todos', 'todos', Icons.group_rounded),
                  const SizedBox(width: 10),
                  _buildFilterChip('Diurnos', 'diurno', Icons.wb_sunny_rounded),
                  const SizedBox(width: 10),
                  _buildFilterChip('Nocturnos', 'nocturno', Icons.nightlight_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _soloActivos 
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                  : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _soloActivos ? Icons.visibility : Icons.visibility_off,
                color: _soloActivos 
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.white54 : Colors.grey),
                size: 22,
              ),
              onPressed: () => setState(() => _soloActivos = !_soloActivos),
              tooltip: _soloActivos ? 'Mostrando activos' : 'Mostrando todos',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _filtroTurno == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => setState(() => _filtroTurno = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white),
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected ? [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected 
                  ? Colors.white 
                  : (isDark ? Colors.white70 : Colors.grey.shade600),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final turnoColor = guardia.esDiurno ? Colors.orange : Colors.indigo;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar con gradiente
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: guardia.activo
                      ? [turnoColor.withValues(alpha: 0.8), turnoColor]
                      : [Colors.grey.shade400, Colors.grey.shade500],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (guardia.activo ? turnoColor : Colors.grey).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                guardia.esDiurno ? Icons.wb_sunny_rounded : Icons.nightlight_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${guardia.nombre} ${guardia.apellido}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          guardia.email,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildBadge(
                        guardia.turnoDisplay,
                        turnoColor,
                        guardia.esDiurno ? Icons.wb_sunny_rounded : Icons.nightlight_rounded,
                      ),
                      _buildBadge(
                        guardia.activo ? 'Activo' : 'Inactivo',
                        guardia.activo ? Colors.green : Colors.red,
                        guardia.activo ? Icons.check_circle : Icons.cancel,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Menu
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) => _manejarAccionGuardia(value, guardia),
                itemBuilder: (_) => [
                  _buildPopupItem('editar', Icons.edit_rounded, 'Editar', Colors.blue),
                  _buildPopupItem(
                    guardia.activo ? 'desactivar' : 'activar',
                    guardia.activo ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                    guardia.activo ? 'Desactivar' : 'Activar',
                    guardia.activo ? Colors.orange : Colors.green,
                  ),
                  _buildPopupItem('eliminar', Icons.delete_rounded, 'Eliminar', Colors.red),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String text, Color color) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: color)),
        ],
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

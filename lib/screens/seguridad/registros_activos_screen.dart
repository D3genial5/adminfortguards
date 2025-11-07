import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/registro_ingreso_model.dart';
import '../../services/registro_ingreso_service.dart';

class RegistrosActivosScreen extends StatefulWidget {
  final Map<String, dynamic>? guardiaData;
  
  const RegistrosActivosScreen({super.key, this.guardiaData});

  @override
  State<RegistrosActivosScreen> createState() => _RegistrosActivosScreenState();
}

class _RegistrosActivosScreenState extends State<RegistrosActivosScreen> {
  String _filtro = 'activos'; // 'activos', 'todos', 'hoy'

  @override
  Widget build(BuildContext context) {
    final condominio = widget.guardiaData?['condominio'] ?? '';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros de Acceso'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => context.go('/scan-qr', extra: widget.guardiaData),
            tooltip: 'Escanear QR',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                _buildFilterChip('Activos', 'activos', Icons.login_rounded, Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip('Todos', 'todos', Icons.list_rounded, Colors.blue),
                const SizedBox(width: 8),
                _buildFilterChip('Hoy', 'hoy', Icons.today_rounded, Colors.orange),
              ],
            ),
          ),
          
          // Lista de registros
          Expanded(
            child: _buildRegistrosList(condominio),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/scan-qr', extra: widget.guardiaData),
        child: const Icon(Icons.qr_code_scanner),
        tooltip: 'Escanear QR',
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon, Color color) {
    final isSelected = _filtro == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filtro = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? color.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? color.withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected 
                    ? color
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected 
                      ? color
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrosList(String condominio) {
    Stream<List<RegistroIngresoModel>> stream;
    
    switch (_filtro) {
      case 'activos':
        stream = RegistroIngresoService.obtenerRegistrosActivos(condominio);
        break;
      case 'hoy':
        stream = RegistroIngresoService.obtenerRegistrosPorCondominio(condominio, limite: 100);
        break;
      default:
        stream = RegistroIngresoService.obtenerRegistrosPorCondominio(condominio);
    }

    return StreamBuilder<List<RegistroIngresoModel>>(
      stream: stream,
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
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar registros',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        List<RegistroIngresoModel> registros = snapshot.data ?? [];

        // Filtrar por fecha si es necesario
        if (_filtro == 'hoy') {
          final hoy = DateTime.now();
          registros = registros.where((registro) {
            return registro.fechaIngreso.year == hoy.year &&
                   registro.fechaIngreso.month == hoy.month &&
                   registro.fechaIngreso.day == hoy.day;
          }).toList();
        }

        if (registros.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyIcon(),
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyMessage(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Los registros aparecerán aquí cuando escanees códigos QR',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: registros.length,
          itemBuilder: (context, index) {
            final registro = registros[index];
            return _buildRegistroCard(registro);
          },
        );
      },
    );
  }

  Widget _buildRegistroCard(RegistroIngresoModel registro) {
    final esActivo = registro.estado == 'ingresado';
    final color = esActivo ? Colors.green : Colors.grey;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getTipoIcon(registro.tipoUsuario),
                    size: 20,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registro.usuarioNombre,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _getTipoTexto(registro.tipoUsuario),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    esActivo ? 'ACTIVO' : 'SALIÓ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                if (registro.casa != null) ...[
                  Icon(
                    Icons.home_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Casa ${registro.casa}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  registro.fechaIngresoFormateada,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  registro.tiempoIngreso,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            
            if (registro.visitanteCI != null || registro.motivoVisita != null) ...[
              const SizedBox(height: 8),
              if (registro.visitanteCI != null)
                Text(
                  'CI: ${registro.visitanteCI}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              if (registro.motivoVisita != null)
                Text(
                  'Motivo: ${registro.motivoVisita}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
            ],
            
            if (esActivo) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _registrarSalida(registro),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Registrar Salida'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getTipoIcon(String tipo) {
    switch (tipo) {
      case 'propietario':
        return Icons.home_rounded;
      case 'visitante':
        return Icons.person_add_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _getTipoTexto(String tipo) {
    switch (tipo) {
      case 'propietario':
        return 'Propietario';
      case 'visitante':
        return 'Visitante';
      default:
        return 'Usuario';
    }
  }

  IconData _getEmptyIcon() {
    switch (_filtro) {
      case 'activos':
        return Icons.login_rounded;
      case 'hoy':
        return Icons.today_rounded;
      default:
        return Icons.list_rounded;
    }
  }

  String _getEmptyMessage() {
    switch (_filtro) {
      case 'activos':
        return 'No hay personas activas';
      case 'hoy':
        return 'No hay registros de hoy';
      default:
        return 'No hay registros';
    }
  }

  Future<void> _registrarSalida(RegistroIngresoModel registro) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Salida'),
        content: Text(
          '¿Confirmar salida de ${registro.usuarioNombre}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmacion == true && mounted) {
      try {
        await RegistroIngresoService.registrarSalida(registro.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Salida registrada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al registrar salida: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

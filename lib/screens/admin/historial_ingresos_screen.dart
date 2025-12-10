import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/registro_ingreso_model.dart';
import '../../services/registro_ingreso_service.dart';

class HistorialIngresosScreen extends StatefulWidget {
  final String condominio;
  
  const HistorialIngresosScreen({
    super.key,
    required this.condominio,
  });

  @override
  State<HistorialIngresosScreen> createState() => _HistorialIngresosScreenState();
}

class _HistorialIngresosScreenState extends State<HistorialIngresosScreen> {
  DateTime _fechaSeleccionada = DateTime.now();
  bool _mostrarTodos = true; // true = últimos 3 meses, false = fecha específica
  List<RegistroIngresoModel> _registros = [];
  Map<String, int> _estadisticas = {'hoy': 0, 'semana': 0, 'mes': 0};
  bool _isLoading = true;
  String? _error;
  final TextEditingController _busquedaController = TextEditingController();
  String _terminoBusqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final [estadisticas, registros] = await Future.wait([
        RegistroIngresoService.obtenerEstadisticasExtendidas(widget.condominio),
        _mostrarTodos
            ? RegistroIngresoService.obtenerRegistrosUltimosMeses(widget.condominio, meses: 3)
            : RegistroIngresoService.obtenerRegistrosPorFecha(widget.condominio, _fechaSeleccionada),
      ]);

      setState(() {
        _estadisticas = estadisticas as Map<String, int>;
        _registros = registros as List<RegistroIngresoModel>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _buscar(String termino) async {
    if (termino.isEmpty) {
      _cargarDatos();
      return;
    }

    setState(() {
      _isLoading = true;
      _terminoBusqueda = termino;
    });

    try {
      final registros = await RegistroIngresoService.buscarRegistros(
        widget.condominio,
        termino,
      );

      setState(() {
        _registros = registros;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _seleccionarFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF00C853),
            ),
          ),
          child: child!,
        );
      },
    );

    if (fecha != null) {
      setState(() {
        _fechaSeleccionada = fecha;
        _mostrarTodos = false;
        _terminoBusqueda = '';
        _busquedaController.clear();
      });
      _cargarDatos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Historial de Ingresos'),
        backgroundColor: const Color(0xFF00C853),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con estadísticas
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF00C853), Color(0xFF00E676)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    // Estadísticas
                    Row(
                      children: [
                        _buildStatCard('Hoy', _estadisticas['hoy'] ?? 0, Icons.today),
                        const SizedBox(width: 8),
                        _buildStatCard('Semana', _estadisticas['semana'] ?? 0, Icons.date_range),
                        const SizedBox(width: 8),
                        _buildStatCard('Mes', _estadisticas['mes'] ?? 0, Icons.calendar_month),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Filtros
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Barra de búsqueda
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _busquedaController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, CI o casa...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      suffixIcon: _terminoBusqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _busquedaController.clear();
                                setState(() => _terminoBusqueda = '');
                                _cargarDatos();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onSubmitted: _buscar,
                    onChanged: (value) {
                      if (value.isEmpty && _terminoBusqueda.isNotEmpty) {
                        setState(() => _terminoBusqueda = '');
                        _cargarDatos();
                      }
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Filtros de fecha
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip(
                        label: 'Últimos 3 meses',
                        isSelected: _mostrarTodos && _terminoBusqueda.isEmpty,
                        onTap: () {
                          setState(() {
                            _mostrarTodos = true;
                            _terminoBusqueda = '';
                            _busquedaController.clear();
                          });
                          _cargarDatos();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterChip(
                        label: _mostrarTodos 
                            ? 'Seleccionar fecha' 
                            : DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
                        isSelected: !_mostrarTodos && _terminoBusqueda.isEmpty,
                        icon: Icons.calendar_today,
                        onTap: _seleccionarFecha,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Info de resultados
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    _terminoBusqueda.isNotEmpty
                        ? 'Resultados para "$_terminoBusqueda"'
                        : _mostrarTodos
                            ? 'Últimos 3 meses'
                            : DateFormat('EEEE, d MMMM yyyy', 'es').format(_fechaSeleccionada),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_registros.length} registros',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00C853),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Lista de registros
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C853)))
                : _error != null
                    ? _buildErrorState()
                    : _registros.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _cargarDatos,
                            color: const Color(0xFF00C853),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _registros.length,
                              itemBuilder: (context, index) {
                                final registro = _registros[index];
                                final mostrarFecha = index == 0 ||
                                    !_mismoDia(_registros[index - 1].fechaIngreso, registro.fechaIngreso);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (mostrarFecha) ...[
                                      if (index > 0) const SizedBox(height: 16),
                                      _buildDateHeader(registro.fechaIngreso),
                                      const SizedBox(height: 8),
                                    ],
                                    _buildRegistroCard(registro),
                                  ],
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C853) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[700],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime fecha) {
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));
    
    String texto;
    if (_mismoDia(fecha, hoy)) {
      texto = 'Hoy';
    } else if (_mismoDia(fecha, ayer)) {
      texto = 'Ayer';
    } else {
      texto = DateFormat('EEEE, d MMMM', 'es').format(fecha);
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF667EEA).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667EEA),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistroCard(RegistroIngresoModel registro) {
    final iniciales = registro.usuarioNombre
        .split(' ')
        .map((p) => p.isNotEmpty ? p[0] : '')
        .take(2)
        .join()
        .toUpperCase();

    final hora = DateFormat('HH:mm').format(registro.fechaIngreso);
    final esPropietario = registro.tipoUsuario == 'propietario';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: esPropietario
                    ? [const Color(0xFF00C853), const Color(0xFF00E676)]
                    : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                iniciales,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Info principal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        registro.usuarioNombre,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: esPropietario
                            ? const Color(0xFF00C853).withValues(alpha: 0.1)
                            : const Color(0xFF667EEA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        esPropietario ? 'Propietario' : 'Visitante',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: esPropietario
                              ? const Color(0xFF00C853)
                              : const Color(0xFF667EEA),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (registro.visitanteCI != null) ...[
                      Icon(Icons.badge_outlined, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        registro.visitanteCI!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.home_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      registro.casa ?? 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      hora,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.security, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        registro.guardiaNombre,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                _terminoBusqueda.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _terminoBusqueda.isNotEmpty
                  ? 'Sin resultados'
                  : 'No hay registros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _terminoBusqueda.isNotEmpty
                  ? 'No se encontraron registros para "$_terminoBusqueda"'
                  : _mostrarTodos
                      ? 'No hay ingresos registrados en los últimos 3 meses'
                      : 'No hay ingresos para la fecha seleccionada',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar datos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Error desconocido',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _cargarDatos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  bool _mismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

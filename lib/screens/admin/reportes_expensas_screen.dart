import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/casa_model.dart';
import '../../services/admin_firestore_service.dart';

class ReportesExpensasScreen extends StatefulWidget {
  final String condominioId;

  const ReportesExpensasScreen({
    super.key,
    required this.condominioId,
  });

  @override
  State<ReportesExpensasScreen> createState() => _ReportesExpensasScreenState();
}

class _ReportesExpensasScreenState extends State<ReportesExpensasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filtroEstado = 'todos'; // 'todos', 'pagadas', 'pendientes'
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaFin = DateTime.now();
  String _periodoSeleccionado = 'ultimo_mes'; // 'ultimo_mes', 'ultimos_3_meses', 'ultimo_año', 'personalizado'

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
        title: const Text('Reportes de Expensas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            onPressed: () => _exportarReporte(),
            tooltip: 'Exportar Reporte',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Resumen', icon: Icon(Icons.analytics_rounded)),
            Tab(text: 'Por Casa', icon: Icon(Icons.home_rounded)),
            Tab(text: 'Histórico', icon: Icon(Icons.history_rounded)),
          ],
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildResumenTab(),
          _buildPorCasaTab(),
          _buildHistoricoTab(),
        ],
      ),
    );
  }

  Widget _buildResumenTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AdminFirestoreService.streamCasas(widget.condominioId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final casas = snapshot.data?.docs
            .map((doc) => CasaModel.fromFirestore(doc.data(), doc.id))
            .toList() ?? [];

        final estadisticas = _calcularEstadisticas(casas);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildEstadisticasGenerales(estadisticas),
            const SizedBox(height: 24),
            _buildGraficoEstados(estadisticas),
            const SizedBox(height: 24),
            _buildTopMorosos(casas),
            const SizedBox(height: 24),
            _buildResumenMensual(casas),
          ],
        );
      },
    );
  }

  Widget _buildPorCasaTab() {
    return Column(
      children: [
        _buildFiltros(),
        Expanded(child: _buildListaCasas()),
      ],
    );
  }

  Widget _buildHistoricoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSelectorPeriodo(),
        const SizedBox(height: 24),
        _buildGraficoHistorico(),
        const SizedBox(height: 24),
        _buildTendencias(),
      ],
    );
  }

  Widget _buildEstadisticasGenerales(Map<String, dynamic> stats) {
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Estadísticas Generales',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Casas',
                    stats['totalCasas'].toString(),
                    Icons.home_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Pagadas',
                    stats['pagadas'].toString(),
                    Icons.check_circle_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Pendientes',
                    stats['pendientes'].toString(),
                    Icons.pending_rounded,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Porcentaje Pago',
                    '${stats['porcentajePago']}%',
                    Icons.percent_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.attach_money_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Recaudado',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '\$${stats['totalRecaudado'].toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGraficoEstados(Map<String, dynamic> stats) {
    final total = stats['totalCasas'] as int;
    final pagadas = stats['pagadas'] as int;
    final pendientes = stats['pendientes'] as int;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribución de Pagos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: pagadas,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                        topRight: pendientes == 0 ? Radius.circular(10) : Radius.zero,
                        bottomRight: pendientes == 0 ? Radius.circular(10) : Radius.zero,
                      ),
                    ),
                  ),
                ),
                if (pendientes > 0)
                  Expanded(
                    flex: pendientes,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(10),
                          bottomRight: Radius.circular(10),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLeyendaItem('Pagadas', pagadas, Colors.green, total),
                _buildLeyendaItem('Pendientes', pendientes, Colors.orange, total),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeyendaItem(String label, int value, Color color, int total) {
    final porcentaje = total > 0 ? ((value / total) * 100).round() : 0;
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          '$value ($porcentaje%)',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildTopMorosos(List<CasaModel> casas) {
    final morosos = casas.where((casa) => !casa.expensasPagadas).take(5).toList();

    if (morosos.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.celebration_rounded,
                size: 48,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                '¡Todas las expensas están al día!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                  Icons.warning_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Casas con Expensas Pendientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...morosos.map((casa) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.home_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          casa.nombre,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Propietario: ${casa.propietario}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PENDIENTE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenMensual(List<CasaModel> casas) {
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
                  Icons.calendar_month_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Resumen del Mes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Próximamente: Gráficos de tendencias mensuales',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
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
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'todos', label: Text('Todas')),
          ButtonSegment(value: 'pagadas', label: Text('Pagadas')),
          ButtonSegment(value: 'pendientes', label: Text('Pendientes')),
        ],
        selected: {_filtroEstado},
        onSelectionChanged: (Set<String> selection) {
          setState(() {
            _filtroEstado = selection.first;
          });
        },
      ),
    );
  }

  Widget _buildListaCasas() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AdminFirestoreService.streamCasas(widget.condominioId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final todasCasas = snapshot.data?.docs
            .map((doc) => CasaModel.fromFirestore(doc.data(), doc.id))
            .toList() ?? [];

        final casasFiltradas = _filtrarCasas(todasCasas);

        if (casasFiltradas.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: casasFiltradas.length,
          itemBuilder: (context, index) {
            return _buildCasaCard(casasFiltradas[index]);
          },
        );
      },
    );
  }

  Widget _buildCasaCard(CasaModel casa) {
    final color = casa.expensasPagadas ? Colors.green : Colors.orange;
    final estado = casa.expensasPagadas ? 'PAGADA' : 'PENDIENTE';

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
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.home_rounded,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    casa.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Propietario: ${casa.propietario}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  if (casa.residentes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Residentes: ${casa.residentes.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                estado,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectorPeriodo() {
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
                  Icons.date_range,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Seleccionar Período',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Botones de período predefinido
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPeriodoChip('Último Mes', 'ultimo_mes'),
                _buildPeriodoChip('Últimos 3 Meses', 'ultimos_3_meses'),
                _buildPeriodoChip('Último Año', 'ultimo_año'),
                _buildPeriodoChip('Personalizado', 'personalizado'),
              ],
            ),
            
            if (_periodoSeleccionado == 'personalizado') ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _seleccionarFecha(true),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Desde',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_fechaInicio.day}/${_fechaInicio.month}/${_fechaInicio.year}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _seleccionarFecha(false),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hasta',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_fechaFin.day}/${_fechaFin.month}/${_fechaFin.year}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            Text(
              'Seleccionar Período',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Funcionalidad próximamente',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoHistorico() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Histórico de Pagos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Gráfico de tendencias próximamente',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTendencias() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Análisis de Tendencias',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Análisis predictivo próximamente',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay casas con este filtro',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  List<CasaModel> _filtrarCasas(List<CasaModel> casas) {
    switch (_filtroEstado) {
      case 'pagadas':
        return casas.where((casa) => casa.expensasPagadas).toList();
      case 'pendientes':
        return casas.where((casa) => !casa.expensasPagadas).toList();
      default:
        return casas;
    }
  }

  Map<String, dynamic> _calcularEstadisticas(List<CasaModel> casas) {
    final totalCasas = casas.length;
    final pagadas = casas.where((casa) => casa.expensasPagadas).length;
    final pendientes = totalCasas - pagadas;
    final porcentajePago = totalCasas > 0 ? ((pagadas / totalCasas) * 100).round() : 0;
    final totalRecaudado = pagadas * 150000.0; // Valor ejemplo de expensa

    return {
      'totalCasas': totalCasas,
      'pagadas': pagadas,
      'pendientes': pendientes,
      'porcentajePago': porcentajePago,
      'totalRecaudado': totalRecaudado,
    };
  }

  void _mostrarDialogoPermisos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos Requeridos'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Para exportar reportes necesitamos acceso al almacenamiento.'),
            SizedBox(height: 12),
            Text('Por favor:'),
            SizedBox(height: 8),
            Text('1. Ve a Configuración de la app'),
            Text('2. Selecciona "Permisos"'),
            Text('3. Activa "Almacenamiento" o "Archivos y multimedia"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Ir a Configuración'),
          ),
        ],
      ),
    );
  }

  // Método de exportación de reportes
  Future<void> _exportarReporte() async {
    try {
      // Solicitar permisos de almacenamiento (Android 13+ usa permisos específicos)
      bool permisoConcedido = false;
      
      if (await Permission.photos.isGranted || await Permission.storage.isGranted) {
        permisoConcedido = true;
      } else {
        // Intentar solicitar permisos
        final statusPhotos = await Permission.photos.request();
        final statusStorage = await Permission.storage.request();
        final statusManageStorage = await Permission.manageExternalStorage.request();
        
        permisoConcedido = statusPhotos.isGranted || 
                          statusStorage.isGranted || 
                          statusManageStorage.isGranted;
      }
      
      if (!permisoConcedido) {
        if (mounted) {
          _mostrarDialogoPermisos();
        }
        return;
      }

      // Mostrar opciones de exportación
      if (!mounted) return;
      final formato = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exportar Reporte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Selecciona el formato de exportación:'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Excel (.xlsx)'),
                subtitle: const Text('Formato de hoja de cálculo'),
                onTap: () => Navigator.of(context).pop('excel'),
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet, color: Colors.blue),
                title: const Text('CSV (.csv)'),
                subtitle: const Text('Valores separados por comas'),
                onTap: () => Navigator.of(context).pop('csv'),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('PDF (.pdf)'),
                subtitle: const Text('Documento portable'),
                onTap: () => Navigator.of(context).pop('pdf'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );

      if (formato == null) return;

      // Obtener datos para exportar
      final casas = await _obtenerDatosParaExportar();
      
      if (casas.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay datos para exportar'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Mostrar indicador de carga
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Exportando reporte...'),
              ],
            ),
          ),
        );
      }

      String? rutaArchivo;
      
      switch (formato) {
        case 'excel':
          rutaArchivo = await _exportarAExcel(casas);
          break;
        case 'csv':
          rutaArchivo = await _exportarACSV(casas);
          break;
        case 'pdf':
          rutaArchivo = await _exportarAPDF(casas);
          break;
      }

      // Cerrar indicador de carga
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (rutaArchivo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reporte exportado: ${rutaArchivo.split('/').last}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () => _mostrarRutaArchivo(rutaArchivo!),
            ),
          ),
        );
      }

    } catch (e) {
      // Cerrar indicador de carga si está abierto
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Obtener datos para exportar
  Future<List<CasaModel>> _obtenerDatosParaExportar() async {
    try {
      final snapshot = await AdminFirestoreService.obtenerCasas(widget.condominioId);
      return snapshot.docs
          .map((doc) => CasaModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error al obtener datos: $e');
    }
  }

  // Exportar a CSV
  Future<String?> _exportarACSV(List<CasaModel> casas) async {
    try {
      // Funcionalidad de exportar deshabilitada temporalmente
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionalidad de exportar próximamente')),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Error al exportar CSV: $e');
    }
  }

  // Exportar a Excel (simulado como CSV extendido)
  Future<String?> _exportarAExcel(List<CasaModel> casas) async {
    try {
      // Funcionalidad de exportar deshabilitada temporalmente
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionalidad de exportar próximamente')),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Error al exportar Excel: $e');
    }
  }

  // Exportar a PDF (simulado como texto estructurado)
  Future<String?> _exportarAPDF(List<CasaModel> casas) async {
    try {
      // Funcionalidad de exportar deshabilitada temporalmente
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funcionalidad de exportar próximamente')),
        );
      }
      return null;
    } catch (e) {
      throw Exception('Error al exportar PDF: $e');
    }
  }

  // Mostrar ruta del archivo exportado
  void _mostrarRutaArchivo(String ruta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivo Exportado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('El reporte se ha guardado en:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ruta,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
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

  Widget _buildPeriodoChip(String label, String value) {
    final isSelected = _periodoSeleccionado == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _periodoSeleccionado = value;
          _actualizarFechasPorPeriodo();
        });
      },
      selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  void _actualizarFechasPorPeriodo() {
    final now = DateTime.now();
    switch (_periodoSeleccionado) {
      case 'ultimo_mes':
        _fechaInicio = DateTime(now.year, now.month - 1, now.day);
        _fechaFin = now;
        break;
      case 'ultimos_3_meses':
        _fechaInicio = DateTime(now.year, now.month - 3, now.day);
        _fechaFin = now;
        break;
      case 'ultimo_año':
        _fechaInicio = DateTime(now.year - 1, now.month, now.day);
        _fechaFin = now;
        break;
      case 'personalizado':
        // Las fechas se mantienen como están
        break;
    }
  }

  Future<void> _seleccionarFecha(bool esInicio) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: esInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (fecha != null) {
      setState(() {
        if (esInicio) {
          _fechaInicio = fecha;
        } else {
          _fechaFin = fecha;
        }
      });
    }
  }
}

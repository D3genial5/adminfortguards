import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/alerta_model.dart';
import '../../services/alerta_service.dart';

class AlertasScreen extends StatefulWidget {
  final Map<String, dynamic>? guardiaData;

  const AlertasScreen({super.key, this.guardiaData});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _condominio;
  String? _guardiaId;
  String? _guardiaNombre;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    if (widget.guardiaData != null) {
      _condominio = widget.guardiaData!['condominio'];
      _guardiaId = widget.guardiaData!['id'];
      _guardiaNombre = '${widget.guardiaData!['nombre']} ${widget.guardiaData!['apellido']}';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_condominio == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alertas')),
        body: const Center(child: Text('Error: No se encontraron datos del guardia')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de Emergencia'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              router.go('/perfil-guardia', extra: widget.guardiaData);
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.warning_amber_rounded),
              text: 'Activas',
            ),
            Tab(
              icon: Icon(Icons.history),
              text: 'Historial',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlertasActivas(),
          _buildHistorial(),
        ],
      ),
    );
  }

  Widget _buildAlertasActivas() {
    return StreamBuilder<List<AlertaModel>>(
      stream: AlertaService.streamAlertasActivas(_condominio!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final alertas = snapshot.data ?? [];

        if (alertas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
                const SizedBox(height: 16),
                const Text(
                  'No hay alertas activas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Todo está tranquilo en $_condominio',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: alertas.length,
          itemBuilder: (context, index) {
            final alerta = alertas[index];
            return _buildAlertaCard(alerta, mostrarBotonAtender: true);
          },
        );
      },
    );
  }

  Widget _buildHistorial() {
    return StreamBuilder<List<AlertaModel>>(
      stream: AlertaService.streamHistorialAlertas(_condominio!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final alertas = snapshot.data ?? [];

        if (alertas.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No hay historial de alertas',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: alertas.length,
          itemBuilder: (context, index) {
            final alerta = alertas[index];
            return _buildAlertaCard(alerta, mostrarBotonAtender: false);
          },
        );
      },
    );
  }

  Widget _buildAlertaCard(AlertaModel alerta, {required bool mostrarBotonAtender}) {
    final colorScheme = Theme.of(context).colorScheme;
    final fechaFormateada = DateFormat('dd/MM/yyyy HH:mm').format(alerta.creadoAt);
    
    // Usar el estado REAL de la alerta
    final bool esAlertaActiva = alerta.esActiva;
    
    Color cardColor;
    Color iconColor;
    IconData iconData;
    
    switch (alerta.tipo) {
      case 'ambulancia':
        cardColor = Colors.red.shade50;
        iconColor = Colors.red;
        iconData = Icons.local_hospital;
        break;
      case 'incendio':
        cardColor = Colors.orange.shade50;
        iconColor = Colors.orange;
        iconData = Icons.local_fire_department;
        break;
      case 'ayuda':
        cardColor = Colors.blue.shade50;
        iconColor = Colors.blue;
        iconData = Icons.help_outline;
        break;
      default:
        cardColor = Colors.amber.shade50;
        iconColor = Colors.amber.shade700;
        iconData = Icons.warning_amber_rounded;
    }

    // Si no está activa, cambiar colores a gris
    if (!esAlertaActiva) {
      cardColor = Colors.grey.shade100;
      iconColor = Colors.grey;
    }

    return Card(
      elevation: esAlertaActiva ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: esAlertaActiva 
            ? BorderSide(color: iconColor, width: 2) 
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _mostrarDetalleAlerta(alerta),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alerta.tipoEmoji} ${alerta.tipoDisplay}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: esAlertaActiva ? iconColor : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Casa ${alerta.casaNumero}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (esAlertaActiva)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACTIVA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ATENDIDA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    alerta.propietarioNombre,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    fechaFormateada,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              // Mostrar quién atendió
              if (!esAlertaActiva && alerta.atendidaPorNombre != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Atendida por: ${alerta.atendidaPorNombre}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
              // Indicador de notas disponibles
              if (!esAlertaActiva && alerta.notas != null && alerta.notas!.isNotEmpty) ...[  
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notes_rounded, size: 16, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Toca para ver notas',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.touch_app_rounded, size: 16, color: Colors.blue[400]),
                  ],
                ),
              ],
              if (mostrarBotonAtender && esAlertaActiva) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _mostrarDialogoAtender(alerta),
                    icon: const Icon(Icons.check),
                    label: const Text('Marcar como Atendida'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleAlerta(AlertaModel alerta) {
    final fechaFormateada = DateFormat('dd/MM/yyyy HH:mm').format(alerta.creadoAt);
    final fechaAtendidaFormateada = alerta.atendidaAt != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(alerta.atendidaAt!) 
        : null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header con estado
            Row(
              children: [
                Text(alerta.tipoEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alerta.tipoDisplay,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Casa ${alerta.casaNumero}',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: alerta.esActiva ? Colors.red : Colors.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    alerta.esActiva ? 'ACTIVA' : 'ATENDIDA',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Información básica
            _buildInfoRow(Icons.person_outline, 'Propietario', alerta.propietarioNombre),
            _buildInfoRow(Icons.location_city_outlined, 'Condominio', alerta.condominio),
            _buildInfoRow(Icons.access_time, 'Creada', fechaFormateada),
            
            // Información de atención (si está atendida)
            if (!alerta.esActiva) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              
              if (alerta.atendidaPorNombre != null)
                _buildInfoRow(Icons.verified_user_outlined, 'Atendida por', alerta.atendidaPorNombre!),
              
              if (fechaAtendidaFormateada != null)
                _buildInfoRow(Icons.check_circle_outline, 'Fecha atención', fechaAtendidaFormateada),
              
              // NOTAS - La parte importante
              if (alerta.notas != null && alerta.notas!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notes_rounded, size: 20, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Notas de atención',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        alerta.notas!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Sin notas de atención',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
            
            const SizedBox(height: 24),
            
            // Botones de acción
            if (alerta.esActiva)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _mostrarDialogoAtender(alerta);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Marcar como Atendida'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAtender(AlertaModel alerta) {
    final notasController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atender Alerta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Marcar la alerta de Casa ${alerta.casaNumero} como atendida?'),
            const SizedBox(height: 16),
            TextField(
              controller: notasController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Describe cómo se atendió la alerta',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _atenderAlerta(alerta, notasController.text);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _atenderAlerta(AlertaModel alerta, String notas) async {
    try {
      await AlertaService.marcarComoAtendida(
        alertaId: alerta.id,
        guardiaId: _guardiaId ?? '',
        guardiaNombre: _guardiaNombre ?? 'Guardia',
        notas: notas.isNotEmpty ? notas : null,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alerta marcada como atendida'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

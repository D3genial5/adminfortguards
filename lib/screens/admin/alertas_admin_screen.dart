import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/alerta_model.dart';
import '../../services/alerta_service.dart';

class AlertasAdminScreen extends StatefulWidget {
  final String condominioId;

  const AlertasAdminScreen({super.key, required this.condominioId});

  @override
  State<AlertasAdminScreen> createState() => _AlertasAdminScreenState();
}

class _AlertasAdminScreenState extends State<AlertasAdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de Emergencia'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
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
      stream: AlertaService.streamAlertasActivas(widget.condominioId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar alertas',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        final alertas = snapshot.data ?? [];

        if (alertas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
                const SizedBox(height: 16),
                Text(
                  'Sin alertas activas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Todo está en orden',
                  style: TextStyle(color: Colors.grey[500]),
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
            return _buildAlertaCard(alerta, isActive: true);
          },
        );
      },
    );
  }

  Widget _buildHistorial() {
    return StreamBuilder<List<AlertaModel>>(
      stream: AlertaService.streamHistorialAlertas(widget.condominioId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar historial',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        final alertas = snapshot.data ?? [];

        if (alertas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Sin historial de alertas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
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
            return _buildAlertaCard(alerta, isActive: false);
          },
        );
      },
    );
  }

  Widget _buildAlertaCard(AlertaModel alerta, {required bool isActive}) {
    Color cardColor;
    Color iconColor;
    IconData iconData;

    switch (alerta.tipo.toLowerCase()) {
      case 'panico':
      case 'emergencia':
        cardColor = Colors.red[50]!;
        iconColor = Colors.red;
        iconData = Icons.emergency;
        break;
      case 'medica':
        cardColor = Colors.blue[50]!;
        iconColor = Colors.blue;
        iconData = Icons.medical_services;
        break;
      case 'incendio':
        cardColor = Colors.orange[50]!;
        iconColor = Colors.orange;
        iconData = Icons.local_fire_department;
        break;
      case 'robo':
      case 'seguridad':
        cardColor = Colors.purple[50]!;
        iconColor = Colors.purple;
        iconData = Icons.security;
        break;
      default:
        cardColor = Colors.amber[50]!;
        iconColor = Colors.amber[700]!;
        iconData = Icons.warning_amber_rounded;
    }

    if (!isActive) {
      cardColor = Colors.grey[100]!;
      iconColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 4 : 1,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(color: iconColor.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _mostrarDetallesAlerta(alerta),
        borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(iconData, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alerta.tipo.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: iconColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Casa ${alerta.casaNumero}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 8),
                          SizedBox(width: 6),
                          Text(
                            'ACTIVA',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (alerta.notas != null && alerta.notas!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    alerta.notas!,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;

                  final fechaInfo = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _formatDateTime(alerta.creadoAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  );

                  final propietarioInfo = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          alerta.propietarioNombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        fechaInfo,
                        const SizedBox(height: 6),
                        propietarioInfo,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: fechaInfo),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: propietarioInfo,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (isActive) ...[
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;

                    final botonContactar = OutlinedButton.icon(
                      onPressed: () => _contactarCasa(alerta),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text(
                        'Contactar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );

                    final botonAtender = ElevatedButton.icon(
                      onPressed: () => _atenderAlerta(alerta),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text(
                        'Atender',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );

                    if (compact) {
                      return Column(
                        children: [
                          SizedBox(width: double.infinity, child: botonContactar),
                          const SizedBox(height: 10),
                          SizedBox(width: double.infinity, child: botonAtender),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: botonContactar),
                        const SizedBox(width: 12),
                        Expanded(child: botonAtender),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Hace un momento';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }

  void _mostrarDetallesAlerta(AlertaModel alerta) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              'Detalles de la Alerta',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildDetalleRow('Tipo', alerta.tipo.toUpperCase()),
            _buildDetalleRow('Casa', alerta.casaNumero.toString()),
            _buildDetalleRow('Fecha', DateFormat('dd/MM/yyyy HH:mm').format(alerta.creadoAt)),
            _buildDetalleRow('Propietario', alerta.propietarioNombre),
            if (alerta.notas != null && alerta.notas!.isNotEmpty)
              _buildDetalleRow('Notas', alerta.notas!),
            if (alerta.atendidaPorNombre != null)
              _buildDetalleRow('Atendido por', alerta.atendidaPorNombre!),
            if (alerta.atendidaAt != null)
              _buildDetalleRow('Fecha atención', DateFormat('dd/MM/yyyy HH:mm').format(alerta.atendidaAt!)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _contactarCasa(AlertaModel alerta) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contactando a Casa ${alerta.casaNumero}...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _atenderAlerta(AlertaModel alerta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Atender Alerta'),
        content: const Text('¿Confirmas que has atendido esta alerta de emergencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await AlertaService.marcarComoAtendida(
                  alertaId: alerta.id,
                  guardiaId: 'admin',
                  guardiaNombre: 'Administrador',
                );
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Alerta atendida correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error al atender alerta: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

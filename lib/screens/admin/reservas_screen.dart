import 'package:flutter/material.dart';
import '../../models/reserva_model.dart';
import '../../services/reservas_service.dart';

class ReservasScreen extends StatefulWidget {
  final String condominioId;
  
  const ReservasScreen({super.key, required this.condominioId});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Reservas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Pendientes'),
            Tab(text: 'Aprobadas'),
            Tab(text: 'Rechazadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReservasList(null, isTablet),
          _buildReservasList('pendiente', isTablet),
          _buildReservasList('aprobada', isTablet),
          _buildReservasList('rechazada', isTablet),
        ],
      ),
    );
  }

  Widget _buildReservasList(String? estado, bool isTablet) {
    return StreamBuilder<List<ReservaModel>>(
      stream: estado == null 
          ? ReservasService.streamReservas(widget.condominioId)
          : ReservasService.streamReservasPorEstado(widget.condominioId, estado),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final reservas = snapshot.data ?? [];

        if (reservas.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay reservas ${estado ?? ''}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(isTablet ? 24 : 16),
          itemCount: reservas.length,
          itemBuilder: (context, index) {
            final reserva = reservas[index];
            return _buildReservaCard(reserva, isTablet);
          },
        );
      },
    );
  }

  Widget _buildReservaCard(ReservaModel reserva, bool isTablet) {
    Color statusColor;
    IconData statusIcon;
    
    switch (reserva.estado) {
      case 'aprobada':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rechazada':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reserva.areaSocial,
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        reserva.estado.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            _buildInfoRow('Casa:', reserva.casaNumero, isTablet),
            _buildInfoRow('Propietario:', reserva.propietario, isTablet),
            _buildInfoRow('Fecha:', _formatDate(reserva.fechaReserva), isTablet),
            _buildInfoRow('Horario:', '${reserva.horaInicio} - ${reserva.horaFin}', isTablet),
            
            if (reserva.costoAdicional != null)
              _buildInfoRow('Costo:', '\$${reserva.costoAdicional!.toStringAsFixed(2)}', isTablet),
            
            if (reserva.observaciones != null && reserva.observaciones!.isNotEmpty)
              _buildInfoRow('Observaciones:', reserva.observaciones!, isTablet),
            
            if (reserva.motivoRechazo != null && reserva.motivoRechazo!.isNotEmpty)
              _buildInfoRow('Motivo rechazo:', reserva.motivoRechazo!, isTablet),
            
            if (reserva.estado == 'pendiente') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rechazarReserva(reserva),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Rechazar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _aprobarReserva(reserva),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isTablet ? 120 : 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: isTablet ? 14 : 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTablet ? 14 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _aprobarReserva(ReservaModel reserva) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => _AprobarReservaDialog(
        reserva: reserva,
        onApprove: (costoAdicional, observaciones) async {
          try {
            await ReservasService.aprobarReserva(
              widget.condominioId,
              reserva.id,
              'Admin', // TODO: Obtener usuario actual
              costoAdicional: costoAdicional,
              observaciones: observaciones,
            );
            
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Reserva aprobada exitosamente'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Error al aprobar reserva: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _rechazarReserva(ReservaModel reserva) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => _RechazarReservaDialog(
        reserva: reserva,
        onReject: (motivo) async {
          try {
            await ReservasService.rechazarReserva(
              widget.condominioId,
              reserva.id,
              'Admin', // TODO: Obtener usuario actual
              motivo,
            );
            
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Reserva rechazada'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Error al rechazar reserva: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _AprobarReservaDialog extends StatefulWidget {
  final ReservaModel reserva;
  final Function(double?, String?) onApprove;

  const _AprobarReservaDialog({
    required this.reserva,
    required this.onApprove,
  });

  @override
  State<_AprobarReservaDialog> createState() => _AprobarReservaDialogState();
}

class _AprobarReservaDialogState extends State<_AprobarReservaDialog> {
  final _costoController = TextEditingController();
  final _observacionesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aprobar Reserva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¿Aprobar la reserva de ${widget.reserva.areaSocial}?'),
          const SizedBox(height: 16),
          
          TextField(
            controller: _costoController,
            decoration: const InputDecoration(
              labelText: 'Costo adicional (opcional)',
              prefixText: '\$',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          
          TextField(
            controller: _observacionesController,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final costo = _costoController.text.isNotEmpty 
                ? double.tryParse(_costoController.text) 
                : null;
            final observaciones = _observacionesController.text.isNotEmpty 
                ? _observacionesController.text 
                : null;
            
            widget.onApprove(costo, observaciones);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Aprobar'),
        ),
      ],
    );
  }
}

class _RechazarReservaDialog extends StatefulWidget {
  final ReservaModel reserva;
  final Function(String) onReject;

  const _RechazarReservaDialog({
    required this.reserva,
    required this.onReject,
  });

  @override
  State<_RechazarReservaDialog> createState() => _RechazarReservaDialogState();
}

class _RechazarReservaDialogState extends State<_RechazarReservaDialog> {
  final _motivoController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar Reserva'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¿Rechazar la reserva de ${widget.reserva.areaSocial}?'),
          const SizedBox(height: 16),
          
          TextField(
            controller: _motivoController,
            decoration: const InputDecoration(
              labelText: 'Motivo del rechazo *',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_motivoController.text.trim().isNotEmpty) {
              widget.onReject(_motivoController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}

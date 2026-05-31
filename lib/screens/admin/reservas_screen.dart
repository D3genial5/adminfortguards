import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/reserva_model.dart';
import '../../services/reservas_service.dart';
import 'gestion_areas_screen.dart';

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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Reservas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit_location_alt_rounded),
              color: Theme.of(context).colorScheme.primary,
              onPressed: () => _mostrarGestionAreas(context),
              tooltip: 'Gestionar Áreas Sociales',
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
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
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay reservas ${estado ?? ''}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 360;

                  final botonRechazar = OutlinedButton.icon(
                    onPressed: () => _rechazarReserva(reserva),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      'Rechazar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  );

                  final botonAprobar = ElevatedButton.icon(
                    onPressed: () => _aprobarReserva(reserva),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Aprobar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  );

                  if (compact) {
                    return Column(
                      children: [
                        SizedBox(width: double.infinity, child: botonRechazar),
                        const SizedBox(height: 10),
                        SizedBox(width: double.infinity, child: botonAprobar),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: botonRechazar),
                      const SizedBox(width: 12),
                      Expanded(child: botonAprobar),
                    ],
                  );
                },
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: isTablet ? 14 : 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isTablet ? 14 : 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarGestionAreas(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GestionAreasScreen(condominioId: widget.condominioId),
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
              FirebaseAuth.instance.currentUser?.uid ?? 'admin',
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
              FirebaseAuth.instance.currentUser?.uid ?? 'admin',
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
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechazar Reserva'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Rechazar la reserva de ${widget.reserva.areaSocial}?'),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo del rechazo *',
                border: OutlineInputBorder(),
                hintText: 'Escribe el motivo del rechazo',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El motivo es requerido';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : () async {
            if (_formKey.currentState!.validate()) {
              final navigator = Navigator.of(context);
              setState(() => _isLoading = true);
              await widget.onReject(_motivoController.text.trim());
              if (mounted) {
                navigator.pop();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
              )
            : const Text('Rechazar'),
        ),
      ],
    );
  }
}

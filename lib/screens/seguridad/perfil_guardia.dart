import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/alerta_service.dart';
import '../admin/historial_ingresos_screen.dart';

class PerfilGuardiaScreen extends StatelessWidget {
  final Map<String, dynamic>? guardiaData;
  
  const PerfilGuardiaScreen({super.key, this.guardiaData});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final padding = isTablet ? 32.0 : 24.0;
    final avatarRadius = isTablet ? 50.0 : 40.0;
    final titleFontSize = isTablet ? 28.0 : 24.0;
    
    // Obtener datos del guardia
    final nombre = guardiaData?['nombre'] ?? 'Guardia';
    final apellido = guardiaData?['apellido'] ?? '';
    final telefono = guardiaData?['telefono'] ?? 'No disponible';
    final email = guardiaData?['email'] ?? 'No disponible';
    final condominio = guardiaData?['condominio'] ?? 'No asignado';
    final turno = guardiaData?['turno'] ?? 'No definido';
    final tipoPerfil = guardiaData?['tipoPerfil'] ?? 'No definido';
    final id = guardiaData?['id'] ?? 'Sin ID';
    
    final nombreCompleto = '$nombre $apellido'.trim();
    final horarioTexto = turno == 'diurno' ? '6:00 AM - 6:00 PM' : '6:00 PM - 6:00 AM';
    final perfilTexto = tipoPerfil == 'recepcion' ? 'Recepción' : 'Vigilancia';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil Guardia'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con avatar
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      nombre.isNotEmpty ? nombre[0].toUpperCase() : 'G',
                      style: TextStyle(
                        fontSize: isTablet ? 40 : 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    nombreCompleto,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 4),
                  Text(
                    perfilTexto,
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isTablet ? 32 : 24),
            
            // Información del guardia
            _buildInfoRow('Condominio', condominio, isTablet),
            _buildInfoRow('Email', email, isTablet),
            _buildInfoRow('Teléfono', telefono, isTablet),
            _buildInfoRow('Turno', '${turno.toUpperCase()} ($horarioTexto)', isTablet),
            _buildInfoRow('Tipo de Perfil', perfilTexto, isTablet),
            _buildInfoRow('ID de Guardia', id, isTablet),
            
            SizedBox(height: isTablet ? 48 : 32),
            
            // Botones de acción
            Center(
              child: SizedBox(
                width: isTablet ? 300 : double.infinity,
                child: Column(
                  children: [
                    // Botón Escanear QR
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/scan-qr', extra: guardiaData);
                        },
                        icon: Icon(
                          Icons.qr_code_scanner,
                          size: isTablet ? 28 : 24,
                        ),
                        label: Text(
                          'Escanear QR',
                          style: TextStyle(fontSize: isTablet ? 18 : 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 32 : 24,
                            vertical: isTablet ? 20 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: isTablet ? 16 : 12),
                    
                    // Botón Ver Alertas con badge
                    SizedBox(
                      width: double.infinity,
                      child: StreamBuilder<int>(
                        stream: AlertaService.streamCantidadAlertasActivas(condominio),
                        builder: (context, snapshot) {
                          final cantidadAlertas = snapshot.data ?? 0;
                          
                          return ElevatedButton.icon(
                            onPressed: () {
                              context.push('/alertas', extra: guardiaData);
                            },
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  size: isTablet ? 28 : 24,
                                  color: cantidadAlertas > 0 ? Colors.red : null,
                                ),
                                if (cantidadAlertas > 0)
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Text(
                                        '$cantidadAlertas',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            label: Text(
                              cantidadAlertas > 0 
                                  ? 'Ver Alertas ($cantidadAlertas activas)'
                                  : 'Ver Alertas',
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                color: cantidadAlertas > 0 ? Colors.red : null,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 32 : 24,
                                vertical: isTablet ? 20 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: cantidadAlertas > 0 
                                  ? Colors.red.shade50
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    
                    SizedBox(height: isTablet ? 16 : 12),
                    
                    // Botón Historial de Ingresos
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistorialIngresosScreen(condominio: condominio),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.history_rounded,
                          size: isTablet ? 28 : 24,
                        ),
                        label: Text(
                          'Historial de Ingresos',
                          style: TextStyle(fontSize: isTablet ? 18 : 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 32 : 24,
                            vertical: isTablet ? 20 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: padding),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isTablet ? 12 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 16 : 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

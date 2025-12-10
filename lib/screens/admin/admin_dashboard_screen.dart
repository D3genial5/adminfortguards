import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/admin_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'editar_casa_screen.dart';
import 'editar_propietario_screen.dart';
import 'expensas_screen.dart';
import 'enviar_notificacion_screen.dart';
import 'guardias_dashboard_screen.dart';
import 'turno_actual_screen.dart';
import 'notificaciones_screen.dart';
import 'configuracion_screen.dart';
import 'reportes_expensas_screen.dart';
import 'reservas_screen.dart';
import 'gestion_qr_pago_screen.dart';
import 'historial_ingresos_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  final String condominioId;
  const AdminDashboardScreen({super.key, required this.condominioId});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'Dashboard $condominioId',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menú',
          ),
        ),
      ),
      drawer: _buildDrawer(context, isTablet),
      body: FutureBuilder(
        future: AdminFirestoreService.seedIfEmpty(condominioId),
        builder: (context, snapshotSeed) {
          if (snapshotSeed.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: AdminFirestoreService.streamCasas(condominioId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('Sin casas registradas'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final numero = data['numero'];
                  final propietario = data['propietario'];
                  final estadoExpensa = data['estadoExpensa'];
                  final isPagada = estadoExpensa == 'pagada';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => EditarCasaScreen(
                              condominioId: condominioId, 
                              numero: numero, 
                              data: data,
                            ),
                          ));
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.home_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Casa $numero',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                        color: Color(0xFF1A1A1A),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      propietario,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isPagada 
                                            ? const Color(0xFFECFDF5)
                                            : const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isPagada 
                                                ? Icons.check_circle_outline_rounded
                                                : Icons.warning_amber_rounded,
                                            size: 16,
                                            color: isPagada 
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Expensa: $estadoExpensa',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: isPagada 
                                                  ? const Color(0xFF10B981)
                                                  : const Color(0xFFF59E0B),
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: Color(0xFF9CA3AF),
                                  size: 24,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                onSelected: (value) {
                                  if (value == 'editar') {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => EditarCasaScreen(condominioId: condominioId, numero: numero),
                                    ));
                                  } else if (value == 'propietario') {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => EditarPropietarioScreen(
                                        condominio: condominioId,
                                        casa: numero.toString(),
                                        propietarioNombre: propietario,
                                      ),
                                    ));
                                  } else if (value == 'expensa') {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => ExpensasScreen(condominioId: condominioId, numero: numero, estadoActual: estadoExpensa == 'pagada'),
                                    ));
                                  } else if (value == 'notificacion') {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => EnviarNotificacionScreen(condominioId: condominioId, numero: numero),
                                    ));
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'editar',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 20, color: Color(0xFF6B7280)),
                                        SizedBox(width: 12),
                                        Text('Editar casa'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'propietario',
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF6B7280)),
                                        SizedBox(width: 12),
                                        Text('Editar propietario'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'expensa',
                                    child: Row(
                                      children: [
                                        Icon(Icons.payment_outlined, size: 20, color: Color(0xFF6B7280)),
                                        SizedBox(width: 12),
                                        Text('Actualizar expensa'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'notificacion',
                                    child: Row(
                                      children: [
                                        Icon(Icons.notifications_outlined, size: 20, color: Color(0xFF6B7280)),
                                        SizedBox(width: 12),
                                        Text('Enviar notificación'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => EditarCasaScreen(condominioId: condominioId),
            ));
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_home_outlined, size: 24),
          label: const Text(
            'Agregar Casa',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // Drawer methods
  Widget _buildDrawer(BuildContext context, bool isTablet) {
    return Drawer(
      elevation: 0,
      width: isTablet ? 320 : 280,
      backgroundColor: Colors.white,
      child: Column(
        children: [
          _buildDrawerHeader(context, isTablet),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 16 : 12,
                isTablet ? 16 : 12,
                isTablet ? 16 : 12,
                isTablet ? 12 : 8,
              ),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_rounded,
                  title: 'Dashboard',
                  onTap: () {
                    Navigator.pop(context);
                  },
                  isTablet: isTablet,
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.security_rounded,
                  title: 'Gestión de Guardias',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuardiasDashboardScreen(condominioId: condominioId),
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.access_time_rounded,
                  title: 'Turno Actual',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TurnoActualScreen(condominioId: condominioId),
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.notifications_rounded,
                  title: 'Notificaciones',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotificacionesScreen(condominioId: condominioId),
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.analytics_rounded,
                  title: 'Reportes de Expensas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportesExpensasScreen(condominioId: condominioId),
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.qr_code_2,
                  title: 'QR de Pago',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GestionQrPagoScreen(condominioId: condominioId),
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.calendar_today_rounded,
                  title: 'Ver Reservas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReservasScreen(condominioId: condominioId),
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.history_rounded,
                  title: 'Historial de Ingresos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistorialIngresosScreen(condominio: condominioId),
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Divider(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    thickness: 1,
                  ),
                ),
                SizedBox(height: isTablet ? 12 : 8),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_rounded,
                  title: 'Configuración',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ConfiguracionScreen(),
                      ),
                    );
                  },
                  isTablet: isTablet,
                ),
              ],
            ),
          ),
          _buildLogoutSection(context, isTablet),
        ],
      ),
    );
  }

  Widget _buildLogoutSection(BuildContext context, bool isTablet) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 16 : 12,
          isTablet ? 12 : 8,
          isTablet ? 16 : 12,
          isTablet ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              final navigator = Navigator.of(context);
              final router = GoRouter.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('admin_session');
              if (!context.mounted) return;
              navigator.pop();
              router.go('/');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 14,
                vertical: isTablet ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.shade200,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isTablet ? 36 : 32,
                    height: isTablet ? 36 : 32,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.logout_rounded,
                      color: Colors.red.shade700,
                      size: isTablet ? 20 : 18,
                    ),
                  ),
                  SizedBox(width: isTablet ? 12 : 10),
                  Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: isTablet ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : 20,
        isTablet ? 56 : 48,
        isTablet ? 24 : 20,
        isTablet ? 32 : 28,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isTablet ? 64 : 56,
            height: isTablet ? 64 : 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.shield_rounded,
              size: isTablet ? 32 : 28,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isTablet ? 20 : 16),
          Text(
            condominioId,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTablet ? 26 : 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              height: 1.2,
            ),
          ),
          SizedBox(height: isTablet ? 6 : 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'ADMINISTRACIÓN',
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 13 : 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
    required bool isTablet,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16 : 14,
            vertical: isTablet ? 14 : 12,
          ),
          child: Row(
            children: [
              Container(
                width: isTablet ? 44 : 40,
                height: isTablet ? 44 : 40,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? Colors.red.shade50
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isDestructive
                      ? Colors.red.shade600
                      : Theme.of(context).colorScheme.primary,
                  size: isTablet ? 22 : 20,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDestructive
                        ? Colors.red.shade600
                        : const Color(0xFF37474F),
                    fontSize: isTablet ? 16 : 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

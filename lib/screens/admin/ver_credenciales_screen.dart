import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../services/purgar_service.dart';

/// Pantalla de visualización de credenciales con diseño minimalista
class VerCredencialesScreen extends StatefulWidget {
  const VerCredencialesScreen({super.key});

  @override
  State<VerCredencialesScreen> createState() => _VerCredencialesScreenState();
}

class _VerCredencialesScreenState extends State<VerCredencialesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _credenciales = [];
  String _filtro = 'todos'; // 'todos', 'administrador', 'propietario'
  String _condominioSeleccionado = 'todos';
  String _busqueda = ''; // texto de búsqueda

  @override
  void initState() {
    super.initState();
    _cargarCredenciales();
  }

  Future<void> _cargarCredenciales() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot = await _db
          .collection('credenciales')
          .orderBy('createdAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _credenciales = querySnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar credenciales: $e')),
        );
      }
    }
  }

  // Copiar credenciales al portapapeles
  void _copiarCredencial(String texto) {
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // 1. Filtrar por tipo
    var credencialesFiltradas = _filtro == 'todos'
        ? _credenciales
        : _credenciales.where((cred) => cred['tipo'] == _filtro).toList();
    
    // 2. Filtrar por condominio
    if (_condominioSeleccionado != 'todos') {
      credencialesFiltradas = credencialesFiltradas
          .where((cred) => (cred['condominio'] ?? '') == _condominioSeleccionado)
          .toList();
    }
    
    // 3. Filtrar por texto de búsqueda
    if (_busqueda.isNotEmpty) {
      final query = _busqueda.toLowerCase();
      credencialesFiltradas = credencialesFiltradas.where((cred) {
        final valores = [
          cred['email'] ?? '',
          cred['propietario'] ?? '',
          cred['casa'] ?? '',
          cred['condominio'] ?? '',
          cred['nombre'] ?? '',
          cred['perfil'] ?? '',
          cred['turno'] ?? '',
        ].join(' ').toLowerCase();
        return valores.contains(query);
      }).toList();
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // AppBar compacto
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  toolbarHeight: 56,
                  backgroundColor: colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_rounded, size: 20, color: colorScheme.onSurface),
                    onPressed: () => context.go('/lista'),
                    visualDensity: VisualDensity.compact,
                  ),
                  title: Text(
                    'Credenciales',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, size: 20, color: colorScheme.onSurface),
                      onPressed: _cargarCredenciales,
                      tooltip: 'Actualizar',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_sweep_rounded, size: 20, color: colorScheme.onSurface),
                      onPressed: _purgarCredenciales,
                      tooltip: 'Purgar',
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                
                // Toolbar de filtros compacto
                SliverToBoxAdapter(
                  child: _buildCompactToolbar(context),
                ),
                
                // Lista de credenciales
                credencialesFiltradas.isEmpty
                    ? SliverFillRemaining(
                        child: _buildEmptyState(context),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final credencial = credencialesFiltradas[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildCredentialCard(context, credencial),
                              );
                            },
                            childCount: credencialesFiltradas.length,
                          ),
                        ),
                      ),
                
                // Padding bottom
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),
              ],
            ),
    );
  }

  /// Toolbar ultra-compacto profesional
  Widget _buildCompactToolbar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar ultra compacto
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar…',
              hintStyle: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              isDense: true,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _busqueda = value.trim();
              });
            },
          ),
          const SizedBox(height: 8),
          // Filtros en fila horizontal con scroll
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Chips de filtro más compactos
                _buildFilterChipCompact('Todos', 'todos', Icons.all_inclusive_rounded, colorScheme),
                const SizedBox(width: 6),
                _buildFilterChipCompact('Admins', 'administrador', Icons.admin_panel_settings_rounded, colorScheme),
                const SizedBox(width: 6),
                _buildFilterChipCompact('Guardias', 'guardia', Icons.security_rounded, colorScheme),
                const SizedBox(width: 6),
                _buildFilterChipCompact('Propietarios', 'propietario', Icons.home_rounded, colorScheme),
                const SizedBox(width: 12),
                // Dropdown inline compacto
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButton<String>(
                    value: _condominioSeleccionado,
                    items: _buildOpcionesCondominio(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _condominioSeleccionado = value;
                        });
                      }
                    },
                    underline: const SizedBox(),
                    isDense: true,
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                    icon: Icon(Icons.arrow_drop_down, size: 20, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Constantes de color que funcionan en tema claro
  static const _turquoise = Color(0xFF47D9B2);
  static const _darkGray = Color(0xFFF5F5F5);
  static const _mediumGray = Color(0xFFFAFAFA);
  
  // Getter para acceder a colores del tema
  ColorScheme get _colors => Theme.of(context).colorScheme;
  
  /// Chip de filtro compacto - usa colores del tema
  Widget _buildFilterChipCompact(String label, String value, IconData icon, ColorScheme colorScheme) {
    final isSelected = _filtro == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filtro = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary,
            width: isSelected ? 0 : 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildOpcionesCondominio() {
    final setCondominios = {
      'todos',
      ..._credenciales.map((e) => (e['condominio'] ?? '').toString())
    }..removeWhere((element) => element.isEmpty);

    return setCondominios.map((condo) {
      final texto = condo == 'todos' ? 'Todos' : condo;
      return DropdownMenuItem<String>(
        value: condo,
        child: Text(texto),
      );
    }).toList();
  }

  /// Estado vacío minimalista
  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay credenciales',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajusta los filtros para ver más resultados',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta unificada para credenciales (todos los tipos)
  Widget _buildCredentialCard(BuildContext context, Map<String, dynamic> credencial) {
    final tipo = credencial['tipo'] ?? '';
    
    switch (tipo) {
      case 'administrador':
        return _buildAdminCard(credencial);
      case 'guardia':
        return _buildGuardiaCard(credencial);
      case 'propietario':
      default:
        return _buildPropietarioCard(credencial);
    }
  }

  // Tarjeta para credenciales de administrador - usa tema claro
  Widget _buildAdminCard(Map<String, dynamic> credencial) {
    final email = credencial['email']?.toString() ?? '';
    final password = credencial['password']?.toString() ?? '';
    final condominio = credencial['condominio']?.toString() ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _colors.primary.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: _colors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrador',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _colors.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        condominio,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _colors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildCompactCredentialRow(
                    context,
                    'Email',
                    email,
                    Icons.email_rounded,
                    () => _copiarCredencial(email),
                  ),
                  const SizedBox(height: 10),
                  _buildCompactCredentialRow(
                    context,
                    'Contraseña',
                    password,
                    Icons.lock_rounded,
                    () => _copiarCredencial(password),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método helper para filas de credenciales compactas - usa tema
  Widget _buildCompactCredentialRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    VoidCallback onCopy,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
              color: colors.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: colors.primary,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.copy_rounded,
                size: 16,
                color: colors.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // TODO UI Revamp - Tarjeta para credenciales de guardia
  Widget _buildGuardiaCard(Map<String, dynamic> credencial) {
    final email = credencial['email']?.toString() ?? '';
    final password = credencial['password']?.toString() ?? '';
    final nombre = credencial['nombre']?.toString() ?? '';
    final condominio = credencial['condominio']?.toString() ?? '';
    final perfil = credencial['perfil']?.toString() ?? '';
    final turno = credencial['turno']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _turquoise.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _turquoise.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    perfil == 'recepcion' ? Icons.desk_rounded : Icons.visibility_rounded,
                    color: _turquoise,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guardia de Seguridad',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _turquoise,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        nombre,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _turquoise.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    perfil == 'recepcion' ? 'Recepción' : 'Vigilancia',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _turquoise,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _turquoise.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    turno == 'diurno' ? 'Diurno' : 'Nocturno',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _turquoise,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Condominio: $condominio',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFCCCCCC),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _mediumGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildCompactCredentialRow(
                    context,
                    'Email',
                    email,
                    Icons.email_rounded,
                    () => _copiarCredencial(email),
                  ),
                  const SizedBox(height: 8),
                  _buildCompactCredentialRow(
                    context,
                    'Contraseña',
                    password,
                    Icons.lock_rounded,
                    () => _copiarCredencial(password),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TODO UI Revamp - Tarjeta para credenciales de propietario
  static const _secondaryTurquoise = Color(0xFF5FE5C4);
  
  Widget _buildPropietarioCard(Map<String, dynamic> credencial) {
    final condominio = credencial['condominio']?.toString() ?? '';
    final casa = credencial['casa']?.toString() ?? '';
    final password = credencial['password']?.toString() ?? '';
    final propietario = credencial['propietario']?.toString() ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _darkGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _secondaryTurquoise.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _secondaryTurquoise.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: _secondaryTurquoise,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Propietario',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _secondaryTurquoise,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        propietario,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _mediumGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Condominio',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFCCCCCC),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          condominio,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _mediumGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Casa',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFFCCCCCC),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        casa,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _mediumGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _buildCompactCredentialRow(
                context,
                'Contraseña',
                password,
                Icons.lock_rounded,
                () => _copiarCredencial(password),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _secondaryTurquoise.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: _secondaryTurquoise,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Login: Condominio + Casa + Contraseña',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: _secondaryTurquoise,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purgarCredenciales() async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purgar Credenciales'),
        content: const Text(
          '¿Deseas eliminar todas las credenciales que no tienen condominio asociado?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Purgar'),
          ),
        ],
      ),
    );

    if (confirmacion == true && mounted) {
      try {
        final resultado = await PurgarService.purgarTodo();
        final credEliminadas = resultado['credenciales'] ?? 0;
        final adminEliminados = resultado['administradores'] ?? 0;
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Purgado completado:\n'
                '• $credEliminadas credenciales eliminadas\n'
                '• $adminEliminados administradores eliminados',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          _cargarCredenciales();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al purgar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

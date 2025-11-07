import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/condominio_model.dart';
import '../../models/casa_model.dart';
import '../../services/condominio_service.dart';

class CrearCondominioScreen extends StatefulWidget {
  const CrearCondominioScreen({super.key});

  @override
  State<CrearCondominioScreen> createState() => _CrearCondominioScreenState();
}

class _CrearCondominioScreenState extends State<CrearCondominioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Controladores para información básica del condominio
  final _nombreController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailContactoController = TextEditingController();
  final _notasController = TextEditingController();

  // Controladores para información del responsable
  final _nombreResponsableController = TextEditingController();
  final _apellidoResponsableController = TextEditingController();
  final _telefonoResponsableController = TextEditingController();
  final _emailResponsableController = TextEditingController();
  final _cedulaResponsableController = TextEditingController();

  // Lista de administradores
  final List<AdministradorModel> _administradores = [];
  
  // Lista de casas
  final List<Map<String, dynamic>> _casasData = [];

  @override
  void initState() {
    super.initState();
    // Agregar una casa por defecto
    _casasData.add({
      'nombre': '',
      'propietario': '',
      'residentes': [''],
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _telefonoController.dispose();
    _emailContactoController.dispose();
    _notasController.dispose();
    _nombreResponsableController.dispose();
    _apellidoResponsableController.dispose();
    _telefonoResponsableController.dispose();
    _emailResponsableController.dispose();
    _cedulaResponsableController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _agregarAdministrador() {
    showDialog(
      context: context,
      builder: (context) => _AdministradorDialog(
        onAdministradorCreado: (administrador) {
          setState(() {
            _administradores.add(administrador);
          });
        },
      ),
    );
  }

  void _agregarCasa() {
    setState(() {
      _casasData.add({
        'nombre': '',
        'propietario': '',
        'residentes': [''],
      });
    });
  }

  void _eliminarCasa(int index) {
    if (_casasData.length > 1) {
      setState(() {
        _casasData.removeAt(index);
      });
    }
  }

  void _agregarResidente(int casaIndex) {
    setState(() {
      (_casasData[casaIndex]['residentes'] as List<String>).add('');
    });
  }

  void _eliminarResidente(int casaIndex, int residenteIndex) {
    final residentes = _casasData[casaIndex]['residentes'] as List<String>;
    if (residentes.length > 1) {
      setState(() {
        residentes.removeAt(residenteIndex);
      });
    }
  }

  Future<void> _crearCondominio() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Crear lista de casas
      final casas = <CasaModel>[];
      for (final casaData in _casasData) {
        if (casaData['nombre'].toString().isNotEmpty &&
            casaData['propietario'].toString().isNotEmpty) {
          final residentes = (casaData['residentes'] as List<String>)
              .where((r) => r.isNotEmpty)
              .toList();
          
          if (residentes.isEmpty) {
            residentes.add(casaData['propietario']);
          }

          casas.add(CasaModel(
            id: '',
            nombre: casaData['nombre'],
            propietario: casaData['propietario'],
            residentes: residentes,
          ));
        }
      }

      final condominio = CondominioModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: _nombreController.text.trim(),
        direccion: _direccionController.text.trim(),
        ciudad: _ciudadController.text.trim(),
        telefono: _telefonoController.text.trim(),
        emailContacto: _emailContactoController.text.trim(),
        nombreResponsable: _nombreResponsableController.text.trim(),
        apellidoResponsable: _apellidoResponsableController.text.trim(),
        telefonoResponsable: _telefonoResponsableController.text.trim(),
        emailResponsable: _emailResponsableController.text.trim(),
        cedulaResponsable: _cedulaResponsableController.text.trim(),
        administradores: _administradores,
        notas: _notasController.text.trim().isEmpty ? null : _notasController.text.trim(),
        casas: casas,
      );

      await CondominioService.agregar(condominio);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Condominio creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/lista');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear condominio: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        title: const Text(
          'Crear Condominio',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Color(0xFF1A2B4C),
            letterSpacing: 0.3,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Color(0xFF1A2B4C), size: 20),
          onPressed: () => context.go('/lista'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFE0E0E0).withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Stepper elegante y minimalista
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 24,
                vertical: 20,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        Expanded(
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: i < _currentPage
                                  ? const Color(0xFF1A2B4C).withValues(alpha: 0.6)
                                  : i == _currentPage
                                      ? const Color(0xFF1A2B4C)
                                      : const Color(0xFFD0D4DA),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (i < 2) const SizedBox(width: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStepLabel('Información', 0, isTablet),
                      _buildStepLabel('Responsable', 1, isTablet),
                      _buildStepLabel('Casas', 2, isTablet),
                    ],
                  ),
                ],
              ),
            ),
            
            // Contenido de las páginas
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildInfoBasicaPage(),
                  _buildResponsableAdminPage(),
                  _buildCasasPage(),
                ],
              ),
            ),
            
            // Botones de navegación profesionales
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _previousPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE9ECEF),
                            foregroundColor: const Color(0xFF1A2B4C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Anterior',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    if (_currentPage > 0) const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A2B4C).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading 
                              ? null 
                              : (_currentPage == 2 ? _crearCondominio : _nextPage),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2B4C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            disabledBackgroundColor: const Color(0xFF1A2B4C).withValues(alpha: 0.6),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  _currentPage == 2 ? 'Crear Condominio' : 'Siguiente',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLabel(String label, int step, bool isTablet) {
    final isActive = step == _currentPage;
    final isCompleted = step < _currentPage;
    return Text(
      label,
      style: TextStyle(
        fontSize: isTablet ? 13 : 12,
        fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.w400,
        color: isActive
            ? const Color(0xFF1A2B4C)
            : isCompleted
                ? const Color(0xFF1A2B4C).withValues(alpha: 0.6)
                : const Color(0xFF9CA3AF),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildInfoBasicaPage() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 40 : 20,
        vertical: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header moderno
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Información Básica',
                  style: TextStyle(
                    fontSize: isTablet ? 26 : 22,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D2D2D),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete los datos generales del condominio',
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 14,
                    color: const Color(0xFF6B7280),
                    height: 1.5,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          
          // Formulario con diseño minimalista
          _buildMinimalField(
            controller: _nombreController,
            label: 'Nombre del Condominio',
            hint: 'Ej: Residencial Los Pinos',
            icon: Icons.apartment_outlined,
            isRequired: true,
            isTablet: isTablet,
          ),
          
          _buildMinimalField(
            controller: _direccionController,
            label: 'Dirección',
            hint: 'Calle, número, sector',
            icon: Icons.location_on_outlined,
            isRequired: true,
            isTablet: isTablet,
          ),
          
          _buildMinimalField(
            controller: _ciudadController,
            label: 'Ciudad',
            hint: 'Ciudad donde se ubica',
            icon: Icons.location_city_outlined,
            isRequired: true,
            isTablet: isTablet,
          ),
          
          _buildMinimalField(
            controller: _telefonoController,
            label: 'Teléfono de Contacto',
            hint: '+1 234 567 8900',
            icon: Icons.phone_outlined,
            isRequired: true,
            keyboardType: TextInputType.phone,
            isTablet: isTablet,
          ),
          
          _buildMinimalField(
            controller: _emailContactoController,
            label: 'Email de Contacto',
            hint: 'contacto@condominio.com',
            icon: Icons.email_outlined,
            isRequired: true,
            keyboardType: TextInputType.emailAddress,
            isTablet: isTablet,
          ),
          
          _buildMinimalField(
            controller: _notasController,
            label: 'Notas Adicionales',
            hint: 'Información adicional relevante (opcional)',
            icon: Icons.note_outlined,
            maxLines: 3,
            isTablet: isTablet,
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildMinimalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    required bool isTablet,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF2D2D2D),
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          labelText: label + (isRequired ? ' *' : ''),
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF1A2B4C).withValues(alpha: 0.7),
            size: 22,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: const Color(0xFF9CA3AF).withValues(alpha: 0.7),
            fontSize: 14,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A2B4C), width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: isRequired ? (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label es requerido';
          }
          if (keyboardType == TextInputType.emailAddress && !value.contains('@')) {
            return 'Ingrese un email válido';
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildResponsableAdminPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Responsable del Condominio',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Datos del dueño o responsable principal',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nombreResponsableController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es requerido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _apellidoResponsableController,
                  decoration: const InputDecoration(
                    labelText: 'Apellido *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El apellido es requerido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _cedulaResponsableController,
            decoration: const InputDecoration(
              labelText: 'Cédula/ID *',
              hintText: '12345678',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'La cédula es requerida';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _telefonoResponsableController,
            decoration: const InputDecoration(
              labelText: 'Teléfono Personal *',
              hintText: '+1 234 567 8900',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El teléfono es requerido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _emailResponsableController,
            decoration: const InputDecoration(
              labelText: 'Email Personal *',
              hintText: 'responsable@email.com',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El email es requerido';
              }
              if (!value.contains('@')) {
                return 'Ingrese un email válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          
          // Sección de administradores
          Row(
            children: [
              const Text(
                'Administradores/Secretarias',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _agregarAdministrador,
                icon: const Icon(Icons.add_circle),
                tooltip: 'Agregar administrador',
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (_administradores.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'No hay administradores agregados',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_administradores.length, (index) {
              final admin = _administradores[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      admin.nombre[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(admin.nombreCompleto),
                  subtitle: Text('${admin.cargo} • ${admin.email}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _administradores.removeAt(index);
                      });
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCasasPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Casas del Condominio',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _agregarCasa,
                icon: const Icon(Icons.add_circle),
                tooltip: 'Agregar casa',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Configure las casas y sus residentes',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
          ...List.generate(_casasData.length, (index) {
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Casa ${index + 1}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_casasData.length > 1)
                          IconButton(
                            onPressed: () => _eliminarCasa(index),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Número/Nombre',
                              hintText: 'A-1, Casa 1, etc.',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _casasData[index]['nombre'] = value;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Propietario',
                              hintText: 'Nombre completo',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              _casasData[index]['propietario'] = value;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Residentes:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    
                    ...List.generate(
                      (_casasData[index]['residentes'] as List<String>).length,
                      (residenteIndex) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(
                                    labelText: residenteIndex == 0 
                                        ? 'Residente principal' 
                                        : 'Residente ${residenteIndex + 1}',
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (value) {
                                    (_casasData[index]['residentes'] as List<String>)[residenteIndex] = value;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: (_casasData[index]['residentes'] as List<String>).length > 1
                                    ? () => _eliminarResidente(index, residenteIndex)
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    TextButton.icon(
                      onPressed: () => _agregarResidente(index),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Agregar residente'),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// Dialog para agregar administradores
class _AdministradorDialog extends StatefulWidget {
  final Function(AdministradorModel) onAdministradorCreado;

  const _AdministradorDialog({required this.onAdministradorCreado});

  @override
  State<_AdministradorDialog> createState() => _AdministradorDialogState();
}

class _AdministradorDialogState extends State<_AdministradorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  String _cargoSeleccionado = 'Administrador';

  final List<String> _cargos = [
    'Administrador',
    'Secretaria',
    'Conserje',
    'Contador',
    'Asistente',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Administrador'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _apellidoController,
                decoration: const InputDecoration(
                  labelText: 'Apellido *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El apellido es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _cargoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Cargo',
                  border: OutlineInputBorder(),
                ),
                items: _cargos.map((cargo) {
                  return DropdownMenuItem(
                    value: cargo,
                    child: Text(cargo),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _cargoSeleccionado = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El teléfono es requerido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El email es requerido';
                  }
                  if (!value.contains('@')) {
                    return 'Ingrese un email válido';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final administrador = AdministradorModel(
                nombre: _nombreController.text.trim(),
                apellido: _apellidoController.text.trim(),
                telefono: _telefonoController.text.trim(),
                email: _emailController.text.trim(),
                cargo: _cargoSeleccionado,
              );
              
              widget.onAdministradorCreado(administrador);
              Navigator.of(context).pop();
            }
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/admin_firestore_service.dart';

class EditarCasaScreen extends StatefulWidget {
  final String condominioId;
  final int? numero;
  final Map<String, dynamic>? data;
  const EditarCasaScreen({super.key, required this.condominioId, this.numero, this.data});

  @override
  State<EditarCasaScreen> createState() => _EditarCasaScreenState();
}

class _EditarCasaScreenState extends State<EditarCasaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _propietarioCtrl = TextEditingController();
  final _cedulaPropietarioCtrl = TextEditingController();
  final _telefonoPropietarioCtrl = TextEditingController();
  final _emailPropietarioCtrl = TextEditingController();
  final _residentesCtrl = TextEditingController();
  final _cedulaResidenteCtrl = TextEditingController();
  final _telefonoResidenteCtrl = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.numero != null) {
      _numeroCtrl.text = widget.numero.toString();
      _cargarDatosCasa();
    } else if (widget.data != null) {
      _numeroCtrl.text = widget.data!['numero'].toString();
      _propietarioCtrl.text = widget.data!['propietario'] ?? '';
      _residentesCtrl.text = (widget.data!['residentes'] as List?)?.join(', ') ?? '';
      _direccionCtrl.text = widget.data!['direccion'] ?? '';
      _cedulaPropietarioCtrl.text = widget.data!['cedulaPropietario'] ?? '';
      _telefonoPropietarioCtrl.text = widget.data!['telefonoPropietario'] ?? '';
      _emailPropietarioCtrl.text = widget.data!['emailPropietario'] ?? '';
      _cedulaResidenteCtrl.text = widget.data!['cedulaResidente'] ?? '';
      _telefonoResidenteCtrl.text = widget.data!['telefonoResidente'] ?? '';
    }
  }
  
  Future<void> _cargarDatosCasa() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final casasSnapshot = await AdminFirestoreService.obtenerCasas(widget.condominioId);
      final casas = casasSnapshot.docs.map((doc) => doc.data()).toList();
      final casa = casas.firstWhere((c) => c['numero'] == widget.numero);
      
      setState(() {
        _propietarioCtrl.text = casa['propietario'] ?? '';
        _residentesCtrl.text = (casa['residentes'] as List?)?.join(', ') ?? '';
        _direccionCtrl.text = casa['direccion'] ?? '';
        _cedulaPropietarioCtrl.text = casa['cedulaPropietario'] ?? '';
        _telefonoPropietarioCtrl.text = casa['telefonoPropietario'] ?? '';
        _emailPropietarioCtrl.text = casa['emailPropietario'] ?? '';
        _cedulaResidenteCtrl.text = casa['cedulaResidente'] ?? '';
        _telefonoResidenteCtrl.text = casa['telefonoResidente'] ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _numeroCtrl.dispose();
    _direccionCtrl.dispose();
    _propietarioCtrl.dispose();
    _cedulaPropietarioCtrl.dispose();
    _telefonoPropietarioCtrl.dispose();
    _emailPropietarioCtrl.dispose();
    _residentesCtrl.dispose();
    _cedulaResidenteCtrl.dispose();
    _telefonoResidenteCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final numero = int.parse(_numeroCtrl.text.trim());
      await AdminFirestoreService.guardarCasa(
        condominioId: widget.condominioId,
        numero: numero,
        propietario: _propietarioCtrl.text.trim(),
        residentes: _residentesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        direccion: _direccionCtrl.text.trim().isNotEmpty ? _direccionCtrl.text.trim() : null,
        cedulaPropietario: _cedulaPropietarioCtrl.text.trim().isNotEmpty ? _cedulaPropietarioCtrl.text.trim() : null,
        telefonoPropietario: _telefonoPropietarioCtrl.text.trim().isNotEmpty ? _telefonoPropietarioCtrl.text.trim() : null,
        emailPropietario: _emailPropietarioCtrl.text.trim().isNotEmpty ? _emailPropietarioCtrl.text.trim() : null,
        cedulaResidente: _cedulaResidenteCtrl.text.trim().isNotEmpty ? _cedulaResidenteCtrl.text.trim() : null,
        telefonoResidente: _telefonoResidenteCtrl.text.trim().isNotEmpty ? _telefonoResidenteCtrl.text.trim() : null,
      );
      
      if (!mounted) return;
      
      // Mostrar feedback visual
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.data == null ? 'Casa creada correctamente' : 'Casa actualizada correctamente',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.data != null;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Volver',
        ),
        title: Text(
          isEditing ? 'Editar Casa' : 'Agregar Casa',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            _buildSectionTitle('🏠 Datos de la Casa'),
            const SizedBox(height: 16),
            _buildCard([
              _buildTextField(
                controller: _numeroCtrl,
                label: 'Número de casa',
                hint: 'Ej: 101',
                icon: Icons.home_outlined,
                keyboardType: TextInputType.number,
                required: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _direccionCtrl,
                label: 'Dirección (opcional)',
                hint: 'Ej: Av. Principal #123',
                icon: Icons.location_on_outlined,
              ),
            ]),
            
            const SizedBox(height: 28),
            _buildSectionTitle('👤 Propietario'),
            const SizedBox(height: 16),
            _buildCard([
              _buildTextField(
                controller: _propietarioCtrl,
                label: 'Nombre completo',
                hint: 'Ej: Juan Pérez',
                icon: Icons.person_outline,
                required: true,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _cedulaPropietarioCtrl,
                label: 'Cédula / CI',
                hint: 'Ej: 12345678',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _telefonoPropietarioCtrl,
                label: 'Teléfono',
                hint: 'Ej: +591 70000000',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _emailPropietarioCtrl,
                label: 'Correo electrónico (opcional)',
                hint: 'Ej: correo@ejemplo.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
            ]),
            
            const SizedBox(height: 28),
            _buildSectionTitle('👥 Residente(s)'),
            const SizedBox(height: 16),
            _buildCard([
              _buildTextField(
                controller: _residentesCtrl,
                label: 'Nombre(s) de residentes',
                hint: 'Separados por coma',
                icon: Icons.people_outline,
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _cedulaResidenteCtrl,
                label: 'Cédula / CI de residente principal (opcional)',
                hint: 'Ej: 87654321',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _telefonoResidenteCtrl,
                label: 'Teléfono de contacto (opcional)',
                hint: 'Ej: +591 70000000',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ]),
            
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool required = false,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 22),
        labelStyle: TextStyle(
          color: const Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: const Color(0xFF9CA3AF),
          fontSize: 14,
        ),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Este campo es requerido';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 54,
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
      child: ElevatedButton(
        onPressed: _isLoading ? null : _guardar,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
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
            : const Text(
                'Guardar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
      ),
    );
  }
}

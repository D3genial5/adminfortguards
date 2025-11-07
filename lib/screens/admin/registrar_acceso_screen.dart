import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../models/turno_model.dart';

class RegistrarAccesoScreen extends StatefulWidget {
  final TurnoModel turno;

  const RegistrarAccesoScreen({
    super.key,
    required this.turno,
  });

  @override
  State<RegistrarAccesoScreen> createState() => _RegistrarAccesoScreenState();
}

class _RegistrarAccesoScreenState extends State<RegistrarAccesoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visitanteController = TextEditingController();
  final _ciController = TextEditingController();
  final _placaController = TextEditingController();
  final _casaController = TextEditingController();
  final _motivoController = TextEditingController();
  
  final ImagePicker _picker = ImagePicker();
  File? _ciFrenteImage;
  File? _ciReversoImage;
  File? _placaImage;
  
  bool _guardando = false;

  @override
  void dispose() {
    _visitanteController.dispose();
    _ciController.dispose();
    _placaController.dispose();
    _casaController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Registrar Acceso'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildInfoTurno(),
            const SizedBox(height: 24),
            _buildFormularioAcceso(),
            const SizedBox(height: 24),
            _buildSeccionDocumentos(),
            const SizedBox(height: 32),
            _buildBotones(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTurno() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              Theme.of(context).colorScheme.primary,
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Turno Activo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Registrando acceso para el turno actual',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.turno.fechaInicio.hour.toString().padLeft(2, '0')}:${widget.turno.fechaInicio.minute.toString().padLeft(2, '0')} - ${widget.turno.fechaFin.hour.toString().padLeft(2, '0')}:${widget.turno.fechaFin.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormularioAcceso() {
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
                  Icons.person_add_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Datos del Acceso',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _visitanteController,
              decoration: InputDecoration(
                labelText: 'Nombre del visitante',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre del visitante es requerido';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ciController,
                    decoration: InputDecoration(
                      labelText: 'C.I. del visitante',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _placaController,
                    decoration: InputDecoration(
                      labelText: 'Placa del vehículo',
                      prefixIcon: const Icon(Icons.directions_car_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _casaController,
              decoration: InputDecoration(
                labelText: 'Casa de destino',
                prefixIcon: const Icon(Icons.home_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                hintText: 'Ej: A-101, B-205',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'La casa de destino es requerida';
                }
                return null;
              },
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _motivoController,
              decoration: InputDecoration(
                labelText: 'Motivo de la visita',
                prefixIcon: const Icon(Icons.description_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                hintText: 'Ej: Visita familiar, Delivery, Servicio técnico',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El motivo de la visita es requerido';
                }
                return null;
              },
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Hora de registro: ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
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
  
  Widget _buildSeccionDocumentos() {
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
                  Icons.camera_alt_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Documentos (Opcional)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // C.I. Frente
            _buildImagePicker(
              title: 'C.I. Frente',
              icon: Icons.badge_rounded,
              image: _ciFrenteImage,
              onTap: () => _pickImage('ci_frente'),
            ),
            
            const SizedBox(height: 16),
            
            // C.I. Reverso
            _buildImagePicker(
              title: 'C.I. Reverso',
              icon: Icons.badge_outlined,
              image: _ciReversoImage,
              onTap: () => _pickImage('ci_reverso'),
            ),
            
            const SizedBox(height: 16),
            
            // Placa del vehículo
            _buildImagePicker(
              title: 'Placa del Vehículo',
              icon: Icons.directions_car_rounded,
              image: _placaImage,
              onTap: () => _pickImage('placa'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImagePicker({
    required String title,
    required IconData icon,
    required File? image,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (image != null)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(image),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Icon(
                  Icons.add_a_photo_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _pickImage(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    
    if (source != null) {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          switch (type) {
            case 'ci_frente':
              _ciFrenteImage = File(pickedFile.path);
              break;
            case 'ci_reverso':
              _ciReversoImage = File(pickedFile.path);
              break;
            case 'placa':
              _placaImage = File(pickedFile.path);
              break;
          }
        });
      }
    }
  }

  Widget _buildBotones() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _guardando ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _registrarAcceso,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_guardando ? 'Registrando...' : 'Registrar Acceso'),
          ),
        ),
      ],
    );
  }

  Future<void> _registrarAcceso() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      // Subir imágenes a Storage si existen
      Map<String, String> imageUrls = {};
      
      if (_ciFrenteImage != null) {
        imageUrls['ciFrenteUrl'] = await _uploadImage(_ciFrenteImage!, 'ci_frente');
      }
      
      if (_ciReversoImage != null) {
        imageUrls['ciReversoUrl'] = await _uploadImage(_ciReversoImage!, 'ci_reverso');
      }
      
      if (_placaImage != null) {
        imageUrls['placaUrl'] = await _uploadImage(_placaImage!, 'placa');
      }
      
      // Crear documento de visitante en Firestore
      final visitanteDoc = await FirebaseFirestore.instance.collection('visitantes').add({
        'nombre': _visitanteController.text.trim(),
        'ci': _ciController.text.trim(),
        'placa': _placaController.text.trim(),
        'fotos': imageUrls,
        'creadoAt': FieldValue.serverTimestamp(),
        'creadoPorUid': widget.turno.guardiaId,
        'condominioId': widget.turno.condominioId,
        'casaDestino': _casaController.text.trim(),
        'motivo': _motivoController.text.trim(),
      });
      
      // Registrar acceso en el turno (actualizar turno con el reporte)
      await FirebaseFirestore.instance.collection('turnos').doc(widget.turno.id).update({
        'reportes': FieldValue.arrayUnion([{
          'visitante': _visitanteController.text.trim(),
          'casa': _casaController.text.trim(),
          'motivo': _motivoController.text.trim(),
          'ci': _ciController.text.trim(),
          'placa': _placaController.text.trim(),
          'visitanteId': visitanteDoc.id,
          'fecha': FieldValue.serverTimestamp(),
        }])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Acceso registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al registrar acceso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _guardando = false);
    }
  }
  
  Future<String> _uploadImage(File image, String type) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${widget.turno.condominioId}_${type}_$timestamp.jpg';
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('visitantes')
          .child(widget.turno.condominioId)
          .child(fileName);
      
      final uploadTask = await storageRef.putFile(image);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
      return '';
    }
  }
}

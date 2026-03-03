import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class GestionAreasScreen extends StatefulWidget {
  final String condominioId;

  const GestionAreasScreen({super.key, required this.condominioId});

  @override
  State<GestionAreasScreen> createState() => _GestionAreasScreenState();
}

class _GestionAreasScreenState extends State<GestionAreasScreen> {
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Gestión de Áreas'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoArea(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Área'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('condominios')
            .doc(widget.condominioId)
            .collection('areas_comunes')
            .orderBy('nombre')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final areas = snapshot.data?.docs ?? [];

          if (areas.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: areas.length,
            itemBuilder: (context, index) {
              final area = areas[index];
              final data = area.data() as Map<String, dynamic>;
              return _buildAreaCard(area.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_city_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay áreas comunes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega áreas como piscina, salón de eventos, etc.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _mostrarDialogoArea(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Área'),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaCard(String id, Map<String, dynamic> data) {
    final nombre = data['nombre'] ?? 'Sin nombre';
    final descripcion = data['descripcion'] ?? '';
    final capacidad = data['capacidad'] ?? 0;
    final activa = data['activa'] ?? true;
    final imagenUrl = data['imagenUrl'];
    final horaInicio = data['horaInicio'] ?? '08:00';
    final horaFin = data['horaFin'] ?? '22:00';
    final precioAdelanto = data['precioAdelanto']?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: imagenUrl != null
                ? Image.network(
                    imagenUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: activa 
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activa ? 'Activa' : 'Inactiva',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: activa ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    descripcion,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(Icons.people, '$capacidad personas'),
                    _buildInfoChip(Icons.access_time, '$horaInicio - $horaFin'),
                    if (precioAdelanto > 0)
                      _buildInfoChip(Icons.attach_money, '\$${precioAdelanto.toStringAsFixed(0)} adelanto'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _mostrarDialogoArea(context, id: id, data: data),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Editar'),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmarEliminar(id, nombre),
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 150,
      width: double.infinity,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Icon(
        Icons.image,
        size: 64,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  void _mostrarDialogoArea(BuildContext context, {String? id, Map<String, dynamic>? data}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AreaFormSheet(
        condominioId: widget.condominioId,
        areaId: id,
        initialData: data,
      ),
    );
  }

  void _confirmarEliminar(String id, String nombre) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Área'),
        content: Text('¿Estás seguro de eliminar "$nombre"?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await _firestore
                    .collection('condominios')
                    .doc(widget.condominioId)
                    .collection('areas_comunes')
                    .doc(id)
                    .delete();
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Área eliminada'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _AreaFormSheet extends StatefulWidget {
  final String condominioId;
  final String? areaId;
  final Map<String, dynamic>? initialData;

  const _AreaFormSheet({
    required this.condominioId,
    this.areaId,
    this.initialData,
  });

  @override
  State<_AreaFormSheet> createState() => _AreaFormSheetState();
}

class _AreaFormSheetState extends State<_AreaFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _capacidadController = TextEditingController();
  final _precioController = TextEditingController();
  
  String _horaInicio = '08:00';
  String _horaFin = '22:00';
  bool _activa = true;
  String? _imagenUrl;
  File? _imagenSeleccionada;
  bool _guardando = false;

  bool get _esEdicion => widget.areaId != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _nombreController.text = widget.initialData!['nombre'] ?? '';
      _descripcionController.text = widget.initialData!['descripcion'] ?? '';
      _capacidadController.text = (widget.initialData!['capacidad'] ?? 0).toString();
      _precioController.text = (widget.initialData!['precioAdelanto'] ?? 0).toString();
      _horaInicio = widget.initialData!['horaInicio'] ?? '08:00';
      _horaFin = widget.initialData!['horaFin'] ?? '22:00';
      _activa = widget.initialData!['activa'] ?? true;
      _imagenUrl = widget.initialData!['imagenUrl'];
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _capacidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: bottomInset,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + safeBottom),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  
                  // Título
                  Text(
                    _esEdicion ? 'Editar Área' : 'Nueva Área',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Imagen
                  GestureDetector(
                    onTap: _seleccionarImagen,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: _imagenSeleccionada != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(_imagenSeleccionada!, fit: BoxFit.cover),
                            )
                          : _imagenUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(_imagenUrl!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_photo_alternate,
                                      size: 48,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Agregar foto',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nombre
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre del área *',
                      hintText: 'Ej: Salón de eventos',
                      prefixIcon: const Icon(Icons.location_city),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  // Descripción
                  TextFormField(
                    controller: _descripcionController,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Describe el área...',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),

                  // Capacidad y Precio
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _capacidadController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Capacidad',
                            hintText: '0',
                            prefixIcon: const Icon(Icons.people),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _precioController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Adelanto (\$)',
                            hintText: '0',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Horarios
                  Text(
                    'Horario disponible',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _seleccionarHora(true),
                          icon: const Icon(Icons.access_time),
                          label: Text('Desde: $_horaInicio'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _seleccionarHora(false),
                          icon: const Icon(Icons.access_time),
                          label: Text('Hasta: $_horaFin'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Estado
                  SwitchListTile(
                    title: const Text('Área activa'),
                    subtitle: Text(_activa 
                        ? 'Disponible para reservas' 
                        : 'No disponible'),
                    value: _activa,
                    onChanged: (v) => setState(() => _activa = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  // Botones
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: const Text(
                              'Cancelar',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 8,
                        child: SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _guardando ? null : _guardar,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            child: _guardando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(
                                    _esEdicion ? 'Actualizar' : 'Crear Área',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final imagen = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (imagen != null) {
      setState(() {
        _imagenSeleccionada = File(imagen.path);
      });
    }
  }

  Future<void> _seleccionarHora(bool esInicio) async {
    final partes = (esInicio ? _horaInicio : _horaFin).split(':');
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(partes[0]),
        minute: int.parse(partes[1]),
      ),
    );
    if (hora != null) {
      final horaStr = '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (esInicio) {
          _horaInicio = horaStr;
        } else {
          _horaFin = horaStr;
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      String? urlImagen = _imagenUrl;

      // Subir imagen si se seleccionó una nueva
      if (_imagenSeleccionada != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('areas')
            .child(widget.condominioId)
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        await ref.putFile(_imagenSeleccionada!);
        urlImagen = await ref.getDownloadURL();
      }

      final data = {
        'nombre': _nombreController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'capacidad': int.tryParse(_capacidadController.text) ?? 0,
        'precioAdelanto': double.tryParse(_precioController.text) ?? 0,
        'horaInicio': _horaInicio,
        'horaFin': _horaFin,
        'horarioInicio': _horaInicio, // Compatibilidad con app propietarios
        'horarioFin': _horaFin, // Compatibilidad con app propietarios
        'activa': _activa,
        'imagenUrl': urlImagen,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final collection = FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.condominioId)
          .collection('areas_comunes');

      if (_esEdicion) {
        await collection.doc(widget.areaId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await collection.add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_esEdicion ? 'Área actualizada' : 'Área creada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

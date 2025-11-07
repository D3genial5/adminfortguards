import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class GestionQrPagoScreen extends StatefulWidget {
  final String condominioId;
  
  const GestionQrPagoScreen({
    super.key,
    required this.condominioId,
  });

  @override
  State<GestionQrPagoScreen> createState() => _GestionQrPagoScreenState();
}

class _GestionQrPagoScreenState extends State<GestionQrPagoScreen> {
  String? _qrImageUrl;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cargarQrActual();
    _verificarConfiguracion();
  }

  Future<void> _verificarConfiguracion() async {
    try {
      // Verificar conectividad con Firestore
      await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.condominioId)
          .get();
      
      // Verificar configuración de Storage
      FirebaseStorage.instance.ref().child('test');
      debugPrint('Firebase Storage configurado correctamente');
    } catch (e) {
      debugPrint('Error de configuración Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Problema de configuración: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _cargarQrActual() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.condominioId)
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['qrPagoUrl'] != null && data['qrPagoUrl'].toString().isNotEmpty) {
          setState(() {
            _qrImageUrl = data['qrPagoUrl'];
          });
        } else {
          setState(() {
            _qrImageUrl = null;
          });
        }
      } else {
        setState(() {
          _qrImageUrl = null;
        });
      }
    } catch (e) {
      debugPrint('Error cargando QR: $e');
      setState(() {
        _qrImageUrl = null;
      });
    }
  }

  Future<void> _mostrarOpcionesImagen() async {
    final opcion = await showModalBottomSheet<ImageSource>(
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
    
    if (opcion != null) {
      await _subirNuevoQr(opcion);
    }
  }

  Future<void> _subirNuevoQr(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      setState(() {
        _isLoading = true;
      });
      
      // Verificar que el archivo existe
      final file = File(image.path);
      if (!await file.exists()) {
        throw Exception('El archivo seleccionado no existe');
      }
      
      // Verificar tamaño del archivo (máximo 5MB)
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('El archivo es demasiado grande. Máximo 5MB');
      }
      
      // Crear referencia única en Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${widget.condominioId}_qr_pago_$timestamp.jpg';
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('qr_pagos')
          .child(fileName);
      
      // Subir archivo con metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'condominioId': widget.condominioId,
          'tipo': 'qr_pago',
          'fechaSubida': DateTime.now().toIso8601String(),
        },
      );
      
      final uploadTask = await storageRef.putFile(file, metadata);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Actualizar URL en Firestore
      await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.condominioId)
          .set({
        'qrPagoUrl': downloadUrl,
        'qrPagoActualizado': FieldValue.serverTimestamp(),
        'qrPagoFileName': fileName,
      }, SetOptions(merge: true));
      
      setState(() {
        _qrImageUrl = downloadUrl;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR de pago subido exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      String errorMessage = 'Error al subir QR';
      
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Sin permisos para subir archivos. Contacte al administrador del sistema.';
      } else if (e.toString().contains('unauthorized')) {
        errorMessage = 'No autorizado. Inicie sesión nuevamente.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Error de conexión. Verifique su internet.';
      } else if (e.toString().contains('storage/object-not-found')) {
        errorMessage = 'Error de configuración de almacenamiento.';
      } else {
        errorMessage = 'Error al subir QR: ${e.toString()}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _mostrarOpcionesImagen,
            ),
          ),
        );
      }
      debugPrint('Error detallado al subir QR: $e');
    }
  }

  Future<void> _eliminarQr() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text('¿Está seguro de eliminar el QR de pago actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    
    if (confirmar != true) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.condominioId)
          .update({
        'qrPagoUrl': FieldValue.delete(),
        'qrPagoActualizado': FieldValue.delete(),
      });
      
      setState(() {
        _qrImageUrl = null;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR de pago eliminado')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar QR: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR de Pago de Expensas'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Información
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Este QR será mostrado a los propietarios para que puedan realizar el pago de sus expensas.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // QR actual
                  if (_qrImageUrl != null) ...[
                    Text(
                      'QR Actual',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _qrImageUrl!,
                              height: 300,
                              width: 300,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  height: 300,
                                  width: 300,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 300,
                                  width: 300,
                                  color: colorScheme.errorContainer,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 48,
                                        color: colorScheme.onErrorContainer,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Error al cargar imagen',
                                        style: TextStyle(
                                          color: colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _eliminarQr,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Eliminar'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.error,
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: _mostrarOpcionesImagen,
                                icon: const Icon(Icons.upload),
                                label: const Text('Cambiar QR'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // No hay QR
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.qr_code_2,
                            size: 80,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay QR de pago configurado',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Suba una imagen del código QR para pagos',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _mostrarOpcionesImagen,
                            icon: const Icon(Icons.upload),
                            label: const Text('Subir QR de Pago'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

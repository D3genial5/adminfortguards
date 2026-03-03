import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/notification_service.dart';

class EnviarNotificacionScreen extends StatefulWidget {
  final String condominioId;
  final int? numero; // Opcional para enviar a todo el condominio
  
  const EnviarNotificacionScreen({
    super.key,
    required this.condominioId,
    this.numero,
  });

  @override
  State<EnviarNotificacionScreen> createState() => _EnviarNotificacionScreenState();
}

class _EnviarNotificacionScreenState extends State<EnviarNotificacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  final _notificationService = NotificationService();
  
  String _tipoDestinatario = 'casa'; // 'casa', 'condominio', 'multiple'
  List<Map<String, dynamic>> _casasDisponibles = [];
  List<int> _casasSeleccionadas = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.numero != null) {
      _casasSeleccionadas = [widget.numero!];
    }
    _cargarCasas();
  }
  
  Future<void> _cargarCasas() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('condominios')
          .doc(widget.condominioId)
          .collection('casas')
          .get();
      
      setState(() {
        _casasDisponibles = snapshot.docs
            .map((doc) => {'numero': doc.data()['numero'], 'id': doc.id})
            .toList();
      });
    } catch (e) {
      debugPrint('Error cargando casas: $e');
    }
  }
  
  Future<void> _enviarNotificacion() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final titulo = _tituloCtrl.text.trim();
      final mensaje = _mensajeCtrl.text.trim();
      
      if (_tipoDestinatario == 'condominio') {
        // Enviar a todo el condominio
        await _notificationService.sendNotificationToCondominio(
          condominioId: widget.condominioId,
          title: titulo,
          body: mensaje,
          data: {
            'tipo': 'condominio',
            'condominioId': widget.condominioId,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notificación enviada a todo el condominio'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (_tipoDestinatario == 'casa' || _tipoDestinatario == 'multiple') {
        // Enviar a casas específicas
        for (final numero in _casasSeleccionadas) {
          // Buscar el usuario de esa casa
          final credencialQuery = await FirebaseFirestore.instance
              .collection('credenciales')
              .where('condominio', isEqualTo: widget.condominioId)
              .where('casa', isEqualTo: numero)
              .where('tipo', isEqualTo: 'propietario')
              .limit(1)
              .get();
          
          if (credencialQuery.docs.isNotEmpty) {
            final userId = credencialQuery.docs.first.id;
            
            await _notificationService.sendNotificationToUser(
              userId: userId,
              title: titulo,
              body: mensaje,
              data: {
                'tipo': 'privada',
                'condominioId': widget.condominioId,
                'casa': numero,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
        }
        
        if (mounted) {
          final casasText = _casasSeleccionadas.length == 1
              ? 'casa ${_casasSeleccionadas.first}'
              : '${_casasSeleccionadas.length} casas';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notificación enviada a $casasText'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar Notificación'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      backgroundColor: const Color(0xFFF6EEE3),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Tipo de destinatario
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.people_rounded, color: colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Destinatarios',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    if (widget.numero == null) ...[
                      RadioListTile<String>(
                        title: const Text('Todo el condominio'),
                        value: 'condominio',
                        groupValue: _tipoDestinatario,
                        onChanged: (value) {
                          setState(() {
                            _tipoDestinatario = value!;
                            _casasSeleccionadas.clear();
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Casa específica'),
                        value: 'casa',
                        groupValue: _tipoDestinatario,
                        onChanged: (value) {
                          setState(() {
                            _tipoDestinatario = value!;
                            _casasSeleccionadas.clear();
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Múltiples casas'),
                        value: 'multiple',
                        groupValue: _tipoDestinatario,
                        onChanged: (value) {
                          setState(() {
                            _tipoDestinatario = value!;
                            _casasSeleccionadas.clear();
                          });
                        },
                      ),
                    ] else ...[
                      ListTile(
                        leading: const Icon(Icons.home),
                        title: Text('Casa ${widget.numero}'),
                        subtitle: const Text('Destinatario fijo'),
                      ),
                    ],
                    
                    // Selector de casas
                    if (_tipoDestinatario == 'casa' && widget.numero == null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar casa',
                          border: OutlineInputBorder(),
                        ),
                        items: _casasDisponibles
                            .map((casa) => DropdownMenuItem<int>(
                                  value: casa['numero'] as int,
                                  child: Text('Casa ${casa['numero']}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _casasSeleccionadas = value != null ? [value] : [];
                          });
                        },
                        validator: (value) {
                          if (_tipoDestinatario == 'casa' && value == null) {
                            return 'Seleccione una casa';
                          }
                          return null;
                        },
                      ),
                    ],
                    
                    // Selector múltiple de casas
                    if (_tipoDestinatario == 'multiple' && widget.numero == null) ...[
                      const SizedBox(height: 12),
                      const Text('Seleccionar casas:'),
                      const SizedBox(height: 8),
                      Container(
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: _casasDisponibles.length,
                          itemBuilder: (context, index) {
                            final casa = _casasDisponibles[index];
                            final numero = casa['numero'] as int;
                            
                            return CheckboxListTile(
                              title: Text('Casa $numero'),
                              value: _casasSeleccionadas.contains(numero),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _casasSeleccionadas.add(numero);
                                  } else {
                                    _casasSeleccionadas.remove(numero);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
            ),
            
            const SizedBox(height: 20),
            
            // Contenido del mensaje
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.message_rounded, color: colorScheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Mensaje',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _tituloCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingrese un título';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _mensajeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mensaje',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.message),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingrese un mensaje';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
            ),
            
            const SizedBox(height: 28),
            
            // Botón de enviar
            Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _enviarNotificacion,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isLoading ? 'Enviando...' : 'Enviar Notificación',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }
}

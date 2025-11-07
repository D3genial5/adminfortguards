import 'package:flutter/material.dart';
import '../../services/admin_firestore_service.dart';

class ExpensasScreen extends StatefulWidget {
  final String condominioId;
  final int numero;
  final bool estadoActual;
  const ExpensasScreen({super.key, required this.condominioId, required this.numero, required this.estadoActual});

  @override
  State<ExpensasScreen> createState() => _ExpensasScreenState();
}

class _ExpensasScreenState extends State<ExpensasScreen> {
  late bool _pagada;
  final _montoController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _pagada = widget.estadoActual;
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_pagada && !_formKey.currentState!.validate()) {
      return;
    }
    
    final monto = _pagada ? double.tryParse(_montoController.text) : null;
    
    await AdminFirestoreService.actualizarEstadoExpensa(
      condominioId: widget.condominioId,
      numero: widget.numero,
      pagada: _pagada,
      montoPagado: monto,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Actualizar Expensa'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      Icons.home,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Casa ${widget.numero}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Marcar como pagada',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _pagada ? 'La expensa está pagada' : 'La expensa está pendiente',
                          style: TextStyle(
                            color: _pagada ? Colors.green : Colors.orange,
                          ),
                        ),
                        value: _pagada,
                        onChanged: (v) => setState(() {
                          _pagada = v;
                          if (!v) {
                            _montoController.clear();
                          }
                        }),
                        activeColor: Colors.green,
                      ),
                      
                      if (_pagada) ...[
                        const Divider(height: 32),
                        TextFormField(
                          controller: _montoController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Monto pagado',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                          validator: (value) {
                            if (_pagada && (value == null || value.isEmpty)) {
                              return 'Por favor ingrese el monto pagado';
                            }
                            if (_pagada && double.tryParse(value!) == null) {
                              return 'Ingrese un monto válido';
                            }
                            if (_pagada && double.parse(value!) <= 0) {
                              return 'El monto debe ser mayor a 0';
                            }
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              FilledButton.icon(
                onPressed: _guardar,
                icon: const Icon(Icons.save),
                label: const Text('Guardar Cambios'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

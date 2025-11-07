import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/qr_invitado_model.dart';
import '../../services/qr_service.dart';

class EscanearQrScreen extends StatefulWidget {
  final String guardiaId;
  final String guardiaNombre;
  final String condominioGuardia;

  const EscanearQrScreen({
    super.key,
    required this.guardiaId,
    required this.guardiaNombre,
    required this.condominioGuardia,
  });

  @override
  State<EscanearQrScreen> createState() => _EscanearQrScreenState();
}

class _EscanearQrScreenState extends State<EscanearQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isProcessing = false;
  bool _showResult = false;
  Map<String, dynamic>? _validationResult;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _showResult) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _isProcessing = true);

    // Pausar escáner mientras procesamos
    await _scannerController.stop();

    final codigo = barcode!.rawValue!;

    // Validar el QR
    final resultado = await QrService.validarQr(
      codigo: codigo,
      condominioGuardia: widget.condominioGuardia,
    );

    setState(() {
      _validationResult = resultado;
      _showResult = true;
      _isProcessing = false;
    });
  }

  Future<void> _procesarAcceso(bool aceptado) async {
    if (_validationResult == null) return;

    setState(() => _isProcessing = true);

    final codigo = (_validationResult!['qr'] as QrInvitadoModel?)?.codigo ?? '';

    await QrService.procesarAcceso(
      codigo: codigo,
      guardiaId: widget.guardiaId,
      guardiaNombre: widget.guardiaNombre,
      condominioGuardia: widget.condominioGuardia,
      aceptado: aceptado,
    );

    if (!mounted) return;

    // Mostrar confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          aceptado ? '✅ Acceso registrado exitosamente' : '🚫 Acceso denegado',
        ),
        backgroundColor: aceptado ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Cerrar resultado y reiniciar escáner
    setState(() {
      _showResult = false;
      _validationResult = null;
      _isProcessing = false;
    });

    await _scannerController.start();
  }

  void _cerrarResultado() {
    setState(() {
      _showResult = false;
      _validationResult = null;
    });
    _scannerController.start();
  }

  String _formatHora(DateTime fecha) {
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    final segundo = fecha.second.toString().padLeft(2, '0');
    return '$hora:$minuto:$segundo';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Escáner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay de guía
          if (!_showResult)
            Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

          // Instrucciones
          if (!_showResult)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Apunta la cámara al código QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          // Resultado de validación
          if (_showResult && _validationResult != null)
            _buildResultCard(),

          // Indicador de carga
          if (_isProcessing && !_showResult)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final valido = _validationResult!['valido'] as bool;
    final mensaje = _validationResult!['mensaje'] as String;
    final qr = _validationResult!['qr'] as QrInvitadoModel?;

    final color = valido ? Colors.green : Colors.red;
    final icon = valido ? Icons.check_circle : Icons.cancel;

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header con estado
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: color, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      valido ? 'QR Válido' : 'QR Inválido',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      mensaje,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Información del invitado (si existe)
              if (qr != null) ...[
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person, 'Nombre', qr.invitadoNombre),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.badge, 'CI', qr.invitadoCi),
                      if (qr.placaVehiculo != null && qr.placaVehiculo!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.directions_car, 'Placa', qr.placaVehiculo!),
                      ],
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.home, 'Casa', 'Casa ${qr.casaNumero}'),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.category, 'Tipo', qr.tipoDescripcion),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.access_time,
                        'Hora de ingreso',
                        _formatHora(DateTime.now()),
                      ),
                    ],
                  ),
                ),
              ],

              // Botones de acción
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    if (valido) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _isProcessing ? null : () => _procesarAcceso(true),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Aceptar Acceso'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: _isProcessing ? null : () => _procesarAcceso(false),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Denegar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _cerrarResultado,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Escanear Otro'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

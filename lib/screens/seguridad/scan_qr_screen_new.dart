import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/access_info_model.dart';
import '../../services/qr_scan_service.dart';
import '../../services/access_service.dart';

class ScanQrScreenNew extends StatefulWidget {
  final Map<String, dynamic>? guardiaData;

  const ScanQrScreenNew({super.key, this.guardiaData});

  @override
  State<ScanQrScreenNew> createState() => _ScanQrScreenNewState();
}

class _ScanQrScreenNewState extends State<ScanQrScreenNew> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _showingResult = false;
  DateTime? _lastScanTime;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _processQr(String qrData) async {
    if (_isProcessing || _showingResult) return;

    // Cooldown: evitar múltiples escaneos en 1.5s
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!).inMilliseconds < 1500) {
      return;
    }
    _lastScanTime = now;

    setState(() => _isProcessing = true);

    try {
      // Verificar QR
      final accessInfo = await QrScanService.verifyAndFetch(qrData);

      if (!mounted) return;

      // Vibración según resultado
      if (accessInfo.puedePermitir) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.heavyImpact();
      }

      setState(() {
        _showingResult = true;
        _isProcessing = false;
      });

      // Mostrar modal de decisión
      await _showAccessDecisionDialog(accessInfo);
    } catch (e) {
      dev.log('Error procesando QR: $e', name: 'ScanQrScreen');
      if (!mounted) return;

      setState(() => _isProcessing = false);

      // Mostrar diálogo con el contenido del QR para debug
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error al procesar QR'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Error: ${e.toString()}'),
                const SizedBox(height: 16),
                const Text('Contenido del QR:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: SelectableText(
                    qrData,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showAccessDecisionDialog(AccessInfoModel info) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AccessDecisionDialog(
        accessInfo: info,
        guardiaData: widget.guardiaData!,
      ),
    );

    if (!mounted) return;

    setState(() => _showingResult = false);

    if (result == 'permitido' || result == 'denegado') {
      // Breve pausa antes de poder escanear otro
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    _processQr(barcode!.rawValue!);
  }

  @override
  Widget build(BuildContext context) {
    final guardiaData = widget.guardiaData;
    final guardiaInfo = guardiaData != null
        ? '${guardiaData['nombre'] ?? ''} ${guardiaData['apellido'] ?? ''} - ${guardiaData['condominio'] ?? ''}'
        : 'Guardia no identificado';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay
          CustomPaint(
            painter: _ScannerOverlayPainter(),
            child: Container(),
          ),

          // Info superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    guardiaInfo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Apunta al código QR',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Verificando QR...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    // Dibujar área oscurecida fuera del cuadro de escaneo
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRRect(RRect.fromRectAndRadius(scanArea, const Radius.circular(16)))
        ..fillType = PathFillType.evenOdd,
      paint,
    );

    // Dibujar esquinas del área de escaneo
    final cornerPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;

    // Esquina superior izquierda
    canvas.drawLine(scanArea.topLeft, scanArea.topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(scanArea.topLeft, scanArea.topLeft + const Offset(0, cornerLength), cornerPaint);

    // Esquina superior derecha
    canvas.drawLine(scanArea.topRight, scanArea.topRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(scanArea.topRight, scanArea.topRight + const Offset(0, cornerLength), cornerPaint);

    // Esquina inferior izquierda
    canvas.drawLine(scanArea.bottomLeft, scanArea.bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(scanArea.bottomLeft, scanArea.bottomLeft + const Offset(0, -cornerLength), cornerPaint);

    // Esquina inferior derecha
    canvas.drawLine(scanArea.bottomRight, scanArea.bottomRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(scanArea.bottomRight, scanArea.bottomRight + const Offset(0, -cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccessDecisionDialog extends StatefulWidget {
  final AccessInfoModel accessInfo;
  final Map<String, dynamic> guardiaData;

  const _AccessDecisionDialog({
    required this.accessInfo,
    required this.guardiaData,
  });

  @override
  State<_AccessDecisionDialog> createState() => _AccessDecisionDialogState();
}

class _AccessDecisionDialogState extends State<_AccessDecisionDialog> {
  bool _isProcessing = false;
  final _observacionesController = TextEditingController();

  @override
  void dispose() {
    _observacionesController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.accessInfo.colorEstado) {
      case 'verde':
        return Colors.green;
      case 'rojo':
        return Colors.red;
      case 'ambar':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (!widget.accessInfo.firmaValida) return Icons.warning_rounded;
    if (widget.accessInfo.estado == 'vigente') return Icons.check_circle_rounded;
    if (widget.accessInfo.estado == 'expirado') return Icons.schedule_rounded;
    if (widget.accessInfo.estado == 'sin_usos') return Icons.block_rounded;
    return Icons.info_rounded;
  }

  Future<void> _permitirAcceso() async {
    setState(() => _isProcessing = true);

    try {
      final result = await AccessService.authorizeEntry(
        accessInfo: widget.accessInfo,
        guardiaId: widget.guardiaData['id'],
        guardiaNombre: '${widget.guardiaData['nombre']} ${widget.guardiaData['apellido']}',
        observaciones: _observacionesController.text.isNotEmpty ? _observacionesController.text : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pop('permitido');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(result['message'] ?? 'Acceso permitido')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Error al registrar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _denegarAcceso() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (context) => _MotivoDialog(),
    );

    if (motivo == null || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      final result = await AccessService.denyEntry(
        accessInfo: widget.accessInfo,
        guardiaId: widget.guardiaData['id'],
        guardiaNombre: '${widget.guardiaData['nombre']} ${widget.guardiaData['apellido']}',
        motivo: motivo,
        observaciones: _observacionesController.text.isNotEmpty ? _observacionesController.text : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pop('denegado');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('Acceso denegado y registrado')),
              ],
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.accessInfo;
    final statusColor = _getStatusColor();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar e iniciales
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 3),
              ),
              child: Center(
                child: Text(
                  info.iniciales,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getStatusIcon(), color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      info.mensajeEstado,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Información
            _InfoRow(icon: Icons.home, label: 'Casa', value: info.casaNumero.toString()),
            _InfoRow(icon: Icons.location_city, label: 'Condominio', value: info.condominio),
            _InfoRow(icon: Icons.person, label: info.tipo == 'invitado' ? 'Invitado' : 'Propietario', value: info.titularInfo),
            
            if (info.tipoAcceso != null)
              _InfoRow(
                icon: info.tipoAcceso == 'usos'
                    ? Icons.repeat
                    : info.tipoAcceso == 'tiempo'
                        ? Icons.schedule
                        : Icons.all_inclusive,
                label: 'Tipo',
                value: info.tipoAcceso == 'usos'
                    ? 'Por usos'
                    : info.tipoAcceso == 'tiempo'
                        ? 'Por tiempo'
                        : 'Indefinido',
              ),

            const Divider(height: 32),

            // Campo de observaciones
            TextField(
              controller: _observacionesController,
              decoration: InputDecoration(
                labelText: 'Observaciones (opcional)',
                hintText: 'Ej: Traía paquete grande',
                prefixIcon: const Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              maxLines: 2,
              maxLength: 100,
            ),
            const SizedBox(height: 20),

            // Botones
            if (info.puedePermitir) ...[
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _permitirAcceso,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle),
                  label: const Text('PERMITIR ACCESO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : _denegarAcceso,
                  icon: const Icon(Icons.block),
                  label: const Text('Denegar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('CERRAR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MotivoDialog extends StatefulWidget {
  @override
  State<_MotivoDialog> createState() => _MotivoDialogState();
}

class _MotivoDialogState extends State<_MotivoDialog> {
  String? _motivo;
  final _otroController = TextEditingController();

  @override
  void dispose() {
    _otroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Motivo de denegación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            title: const Text('QR inválido o expirado'),
            value: 'QR inválido o expirado',
            groupValue: _motivo,
            onChanged: (v) => setState(() => _motivo = v),
          ),
          RadioListTile<String>(
            title: const Text('Persona no autorizada'),
            value: 'Persona no autorizada',
            groupValue: _motivo,
            onChanged: (v) => setState(() => _motivo = v),
          ),
          RadioListTile<String>(
            title: const Text('Comportamiento sospechoso'),
            value: 'Comportamiento sospechoso',
            groupValue: _motivo,
            onChanged: (v) => setState(() => _motivo = v),
          ),
          RadioListTile<String>(
            title: const Text('Otro'),
            value: 'otro',
            groupValue: _motivo,
            onChanged: (v) => setState(() => _motivo = v),
          ),
          if (_motivo == 'otro')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                controller: _otroController,
                decoration: const InputDecoration(
                  labelText: 'Especificar motivo',
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _motivo == null
              ? null
              : () {
                  final motivo = _motivo == 'otro' ? _otroController.text : _motivo!;
                  Navigator.of(context).pop(motivo);
                },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

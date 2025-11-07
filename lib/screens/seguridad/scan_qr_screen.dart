import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:developer' as dev;
import '../../services/registro_ingreso_service.dart';

class ScanQrScreen extends StatefulWidget {
  final Map<String, dynamic>? guardiaData;
  
  const ScanQrScreen({super.key, this.guardiaData});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _errorMessage;
  String _guardiaInfo = 'Guardia: No identificado';

  @override
  void initState() {
    super.initState();
    _initializeGuardiaInfo();
  }

  void _initializeGuardiaInfo() {
    if (widget.guardiaData != null) {
      final nombre = widget.guardiaData!['nombre'] ?? '';
      final apellido = widget.guardiaData!['apellido'] ?? '';
      final condominio = widget.guardiaData!['condominio'] ?? '';
      
      if (nombre.isNotEmpty && apellido.isNotEmpty) {
        setState(() {
          _guardiaInfo = 'Guardia: $nombre $apellido - $condominio';
        });
      } else {
        setState(() {
          _errorMessage = 'Error: Datos del guardia incompletos';
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Error: No se recibieron datos del guardia';
      });
    }
  }

  Future<void> _procesarQR(String qrData) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> qrInfo;
      
      // Intentar diferentes formatos de QR
      if (qrData.startsWith('{')) {
        // Formato JSON
        qrInfo = json.decode(qrData);
      } else if (qrData.contains('CONDO:') && qrData.contains('CASA:')) {
        // Formato texto: CONDO:SkyICASA:Casa 320
        final parts = qrData.split('I');
        final condoPart = parts.firstWhere((p) => p.startsWith('CONDO:'), orElse: () => '');
        final casaPart = parts.firstWhere((p) => p.startsWith('CASA:'), orElse: () => '');
        
        if (condoPart.isEmpty || casaPart.isEmpty) {
          throw Exception('Formato QR no válido');
        }
        
        qrInfo = {
          'condominio': condoPart.substring(6), // Remover 'CONDO:'
          'casa': casaPart.substring(5), // Remover 'CASA:'
          'visitante': 'Propietario',
        };
      } else {
        throw Exception('Formato QR no reconocido');
      }
      
      // Validar que tenga los campos necesarios
      if (!qrInfo.containsKey('casa') || !qrInfo.containsKey('condominio')) {
        throw Exception('QR inválido: faltan datos requeridos');
      }

      // Verificar que el guardia tenga datos completos
      if (widget.guardiaData == null) {
        throw Exception('Error: No hay datos del guardia');
      }

      final guardiaId = widget.guardiaData!['id'];
      final condominioGuardia = widget.guardiaData!['condominio'];
      
      if (guardiaId == null || condominioGuardia == null) {
        throw Exception('Error: Datos del guardia incompletos');
      }

      // Verificar que el QR sea del mismo condominio
      if (qrInfo['condominio'] != condominioGuardia) {
        throw Exception('QR de otro condominio');
      }

      // Registrar el ingreso usando el servicio existente
      await RegistroIngresoService.registrarIngreso(
        guardiaId: guardiaId,
        guardiaNombre: '${widget.guardiaData!['nombre']} ${widget.guardiaData!['apellido']}',
        condominio: condominioGuardia,
        datosQR: qrInfo,
      );

      if (!mounted) return;

      // Mostrar confirmación y volver
      _mostrarConfirmacion(qrInfo);
      
    } catch (e) {
      dev.log('Error procesando QR: $e', name: 'ScanQrScreen');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error al procesar QR: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _mostrarConfirmacion(Map<String, dynamic> qrInfo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Acceso Registrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Casa: ${qrInfo['casa']}'),
            Text('Visitante: ${qrInfo['visitante'] ?? 'Propietario'}'),
            Text('Condominio: ${qrInfo['condominio']}'),
            const SizedBox(height: 8),
            Text('Hora: ${DateTime.now().toString().substring(0, 19)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cerrar diálogo
              GoRouter.of(context).pop(); // Volver al perfil del guardia
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _manejarDeteccion(BarcodeCapture captura) {
    final valor = captura.barcodes.first.rawValue;
    if (valor == null || _isProcessing) return;

    _procesarQR(valor);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final padding = isTablet ? 24.0 : 16.0;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          } else {
            router.go('/perfil-guardia', extra: widget.guardiaData);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Escanear QR',
            style: TextStyle(fontSize: isTablet ? 24 : 20),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: isTablet ? 28 : 24),
            onPressed: () {
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
              } else {
                router.go('/perfil-guardia', extra: widget.guardiaData);
              }
            },
          ),
        ),
        body: Column(
          children: [
            // Información del guardia
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(padding),
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                _guardiaInfo,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: isTablet ? 18 : 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Error message si existe
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(padding),
                color: Colors.red,
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 16 : 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Instrucciones
            Padding(
              padding: EdgeInsets.all(padding),
              child: Text(
                'Apunta la cámara al código QR',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: isTablet ? 24 : 20,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Scanner con área de escaneo definida
            Expanded(
              child: _errorMessage == null 
                ? Container(
                    margin: EdgeInsets.symmetric(horizontal: padding),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MobileScanner(
                            controller: _controller,
                            onDetect: _manejarDeteccion,
                          ),
                        ),
                        // Overlay con marco de escaneo
                        Center(
                          child: Container(
                            width: screenSize.width * 0.7,
                            height: screenSize.width * 0.7,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              children: [
                                // Esquinas del marco
                                Positioned(
                                  top: -3,
                                  left: -3,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.green, width: 6),
                                        left: BorderSide(color: Colors.green, width: 6),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: Colors.green, width: 6),
                                        right: BorderSide(color: Colors.green, width: 6),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -3,
                                  left: -3,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: Colors.green, width: 6),
                                        left: BorderSide(color: Colors.green, width: 6),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: -3,
                                  right: -3,
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: Colors.green, width: 6),
                                        right: BorderSide(color: Colors.green, width: 6),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          Container(
                            color: Colors.black54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: isTablet ? 6 : 4,
                                  ),
                                  SizedBox(height: padding),
                                  Text(
                                    'Procesando QR...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isTablet ? 18 : 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error, 
                          size: isTablet ? 80 : 64, 
                          color: Colors.red,
                        ),
                        SizedBox(height: padding),
                        Text(
                          'No se puede usar el escáner',
                          style: TextStyle(fontSize: isTablet ? 18 : 16),
                        ),
                        Text(
                          'Revisa los datos del guardia',
                          style: TextStyle(fontSize: isTablet ? 16 : 14),
                        ),
                      ],
                    ),
                  ),
            ),
            
            // Espaciado inferior
            SizedBox(height: padding),
          ],
        ),
      ),
    );
  }
}

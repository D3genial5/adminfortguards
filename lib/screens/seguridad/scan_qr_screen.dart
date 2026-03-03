import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
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
      // Verificar que el guardia tenga datos completos
      if (widget.guardiaData == null) {
        throw Exception('Error: No hay datos del guardia');
      }

      final guardiaId = widget.guardiaData!['id'];
      final condominioGuardia = widget.guardiaData!['condominio'];
      
      if (guardiaId == null || condominioGuardia == null) {
        throw Exception('Error: Datos del guardia incompletos');
      }

      Map<String, dynamic> qrInfo;
      Map<String, dynamic>? visitanteInfo;
      
      // NUEVO: Primero intentar buscar por código QR único en access_requests
      if (!qrData.startsWith('{') && !qrData.contains('CONDO:')) {
        // Es un código QR único (ej: "ABC12345")
        final solicitudQuery = await FirebaseFirestore.instance
            .collection('access_requests')
            .where('codigoQr', isEqualTo: qrData)
            .where('estado', isEqualTo: 'aceptada')
            .limit(1)
            .get();
        
        if (solicitudQuery.docs.isEmpty) {
          throw Exception('QR no válido o no autorizado');
        }
        
        final solicitud = solicitudQuery.docs.first.data();
        final solicitudId = solicitudQuery.docs.first.id;
        
        // Verificar que sea del mismo condominio
        if (solicitud['condominio'] != condominioGuardia) {
          throw Exception('Este QR es de otro condominio');
        }
        
        // Verificar usos restantes
        final usosRestantes = solicitud['usosRestantes'] as int?;
        final tipoAcceso = solicitud['tipoAcceso'] as String?;
        
        if (tipoAcceso != 'indefinido' && usosRestantes != null && usosRestantes <= 0) {
          throw Exception('QR sin usos restantes');
        }
        
        // Verificar expiración
        final fechaExp = solicitud['fechaExpiracion'];
        if (fechaExp != null) {
          DateTime? expiracion;
          if (fechaExp is Timestamp) {
            expiracion = fechaExp.toDate();
          } else if (fechaExp is String) {
            expiracion = DateTime.tryParse(fechaExp);
          }
          if (expiracion != null && DateTime.now().isAfter(expiracion)) {
            throw Exception('QR expirado');
          }
        }
        
        // Buscar datos del visitante en la colección visitantes
        final ci = solicitud['ci'] as String?;
        if (ci != null) {
          final visitanteDoc = await FirebaseFirestore.instance
              .collection('visitantes')
              .doc(ci)
              .get();
          if (visitanteDoc.exists) {
            visitanteInfo = visitanteDoc.data();
          }
        }
        
        qrInfo = {
          'condominio': solicitud['condominio'],
          'casa': 'Casa ${solicitud['casaNumero']}',
          'casaNumero': solicitud['casaNumero'],
          'visitante': solicitud['nombre'] ?? 'Visitante',
          'ci': solicitud['ci'],
          'tipoAcceso': tipoAcceso,
          'usosRestantes': usosRestantes,
          'codigoQr': qrData,
          'solicitudId': solicitudId,
          'fotoCarnetFrente': visitanteInfo?['fotoCarnetFrente'],
          'fotoCarnetReverso': visitanteInfo?['fotoCarnetReverso'],
          'fotoPlaca': visitanteInfo?['fotoPlaca'],
          'placa': visitanteInfo?['placa'] ?? solicitud['placa'],
        };
        
      } else if (qrData.startsWith('{')) {
        // Formato JSON legacy
        qrInfo = json.decode(qrData);
      } else if (qrData.contains('CONDO:') && qrData.contains('CASA:')) {
        // Formato con tipo de acceso: ENTRADA|SESSION:xxx|CONDO:Sky|CASA:Casa 320
        // O formato legacy: CONDO:Sky|CASA:Casa 320
        final parts = qrData.split('|');
        
        // Detectar tipo, sesión y datos del visitante embebidos en el QR
        String? tipoQr;
        String? sessionId;
        String? ciFromQr;
        String? nombreFromQr;
        bool origenCodigoCasa = false;
        for (final part in parts) {
          if (part == 'ENTRADA' || part == 'SALIDA') {
            tipoQr = part;
          } else if (part.startsWith('SESSION:')) {
            sessionId = part.substring(8);
          } else if (part == 'ORIGEN:CASA') {
            origenCodigoCasa = true;
          } else if (part.startsWith('CI:')) {
            ciFromQr = part.substring(3);
          } else if (part.startsWith('NOMBRE:')) {
            nombreFromQr = Uri.decodeComponent(part.substring(7));
          }
        }
        
        final condoPart = parts.firstWhere((p) => p.startsWith('CONDO:'), orElse: () => '');
        final casaPart = parts.firstWhere((p) => p.startsWith('CASA:'), orElse: () => '');
        
        if (condoPart.isEmpty || casaPart.isEmpty) {
          throw Exception('Formato QR no válido');
        }
        
        final condominio = condoPart.substring(6);
        final casa = casaPart.substring(5);
        
        // Verificar condominio para formato legacy
        if (condominio != condominioGuardia) {
          throw Exception('QR de otro condominio');
        }
        
        // Extraer número de casa
        final casaNumMatch = RegExp(r'(\d+)').firstMatch(casa);
        final casaNum = casaNumMatch != null ? int.parse(casaNumMatch.group(1)!) : 0;
        
        // IMPORTANTE: Consultar Firestore para obtener datos reales del visitante
        int? usosRestantes;
        String tipoAcceso = 'usos';
        String nombreVisitante = nombreFromQr ?? 'Visitante';
        String? ciVisitante = ciFromQr;
        String? fotoFrente;
        String? fotoReverso;
        
        try {
          final casaDoc = await FirebaseFirestore.instance
              .collection('condominios')
              .doc(condominio)
              .collection('casas')
              .doc(casaNum.toString())
              .get();
          
          if (casaDoc.exists) {
            final data = casaDoc.data();
            
            // Obtener usos del código
            usosRestantes = data?['codigoUsos'] as int?;
            tipoAcceso = usosRestantes != null ? 'usos' : 'indefinido';
            
            // Obtener datos del ÚLTIMO visitante que ingresó el código
            nombreVisitante = nombreVisitante == 'Visitante'
                ? (data?['ultimoVisitanteNombre'] as String? ?? 'Visitante')
                : nombreVisitante;
            ciVisitante ??= data?['ultimoVisitanteCI'] as String?;
            fotoFrente = data?['ultimoVisitanteFotoFrente'] as String?;
            fotoReverso = data?['ultimoVisitanteFotoReverso'] as String?;
          }
        } catch (e) {
          dev.log('Error consultando datos de la casa: $e', name: 'ScanQrScreen');
        }
        
        qrInfo = {
          'condominio': condominio,
          'casa': casa,
          'casaNumero': casaNum,
          'visitante': nombreVisitante,
          'ci': ciVisitante,
          'tipoAcceso': tipoAcceso,
          'usosRestantes': usosRestantes,
          'fotoCarnetFrente': fotoFrente,
          'fotoCarnetReverso': fotoReverso,
          'sessionId': sessionId,
          'tipoQr': tipoQr,
          'origenCodigoCasa': origenCodigoCasa,
        };
      } else {
        throw Exception('Formato QR no reconocido');
      }

      // DETECCIÓN AUTOMÁTICA: Verificar si ya tiene un ingreso activo
      // IMPORTANTE: Solo detectar entrada/salida para visitantes CON CI
      // Para códigos de casa SIN CI, SIEMPRE es ENTRADA
      final ci = qrInfo['ci'] as String?;
      final tipoQr = qrInfo['tipoQr'] as String?;
      final sessionId = qrInfo['sessionId'] as String?;
      bool esEntrada = true;
      String? registroActivoId;

      Future<QuerySnapshot<Map<String, dynamic>>> buscarRegistroActivo() {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection('registros_ingreso')
            .where('condominio', isEqualTo: condominioGuardia)
            .where('estado', isEqualTo: 'ingresado');

        if (sessionId != null && sessionId.isNotEmpty) {
          query = query.where('sessionId', isEqualTo: sessionId);
        } else if (ci != null && ci.isNotEmpty) {
          query = query.where('visitanteCI', isEqualTo: ci);
        }

        return query.limit(1).get();
      }

      if (tipoQr == 'SALIDA') {
        final registrosActivos = await buscarRegistroActivo();
        if (registrosActivos.docs.isEmpty) {
          throw Exception('No hay ingreso activo para este QR');
        }
        esEntrada = false;
        registroActivoId = registrosActivos.docs.first.id;
      } else if (tipoQr == 'ENTRADA') {
        final registrosActivos = await buscarRegistroActivo();
        if (registrosActivos.docs.isNotEmpty) {
          throw Exception('Ya existe un ingreso activo para este QR');
        }
        esEntrada = true;
      } else if (ci != null && ci.isNotEmpty) {
        // Fallback legacy: detectar por CI
        final registrosActivos = await buscarRegistroActivo();
        if (registrosActivos.docs.isNotEmpty) {
          esEntrada = false;
          registroActivoId = registrosActivos.docs.first.id;
        }
      }
      
      // Registrar entrada o salida según corresponda
      if (esEntrada) {
        // ENTRADA: Crear nuevo registro
        // NOTA: Los usos ya fueron decrementados cuando el visitante ingresó el código
        // en ingreso_casa_screen.dart mediante CodigoCasaUtil.verificarCodigo()
        await RegistroIngresoService.registrarIngreso(
          guardiaId: guardiaId,
          guardiaNombre: '${widget.guardiaData!['nombre']} ${widget.guardiaData!['apellido']}',
          condominio: condominioGuardia,
          datosQR: qrInfo,
        );

        // Para solicitudes de invitados/visitas: sincronizar estado y usos
        final usosActualizados = await _actualizarSolicitudPostEntrada(qrInfo);
        if (usosActualizados != null) {
          qrInfo['usosRestantes'] = usosActualizados;
        }
      } else {
        // SALIDA: Actualizar registro existente
        if (registroActivoId != null) {
          await RegistroIngresoService.registrarSalida(registroActivoId);
        }
      }

      if (!mounted) return;

      // Mostrar confirmación con tipo de operación
      _mostrarConfirmacionCompleta(qrInfo, esEntrada: esEntrada);
      
    } catch (e) {
      dev.log('Error procesando QR: $e', name: 'ScanQrScreen');
      if (!mounted) return;
      
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<int?> _actualizarSolicitudPostEntrada(Map<String, dynamic> qrInfo) async {
    if (qrInfo['origenCodigoCasa'] == true) {
      return null;
    }

    final solicitudId = qrInfo['solicitudId'] as String?;

    if (solicitudId != null && solicitudId.isNotEmpty) {
      final ref = FirebaseFirestore.instance.collection('access_requests').doc(solicitudId);
      return _aplicarActualizacionSolicitud(ref);
    }

    final condominio = qrInfo['condominio']?.toString();
    final casaNumero = qrInfo['casaNumero'] as int?;
    final ci = qrInfo['ci']?.toString();
    if (condominio == null || casaNumero == null || ci == null || ci.isEmpty) {
      return null;
    }

    final query = await FirebaseFirestore.instance
        .collection('access_requests')
        .where('condominio', isEqualTo: condominio)
        .where('casaNumero', isEqualTo: casaNumero)
        .where('ci', isEqualTo: ci)
        .where('estado', isEqualTo: 'aceptada')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return _aplicarActualizacionSolicitud(query.docs.first.reference);
  }

  Future<int?> _aplicarActualizacionSolicitud(DocumentReference<Map<String, dynamic>> ref) async {
    return FirebaseFirestore.instance.runTransaction<int?>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return null;

      final data = snap.data()!;
      final tipoAcceso = data['tipoAcceso']?.toString() ?? 'usos';
      final usosActuales = (data['usosRestantes'] as num?)?.toInt() ??
          (data['codigoUsos'] as num?)?.toInt();

      final updates = <String, dynamic>{
        'entradaVerificada': true,
        'fechaEntrada': FieldValue.serverTimestamp(),
      };

      int? nuevosUsos;
      if (tipoAcceso != 'indefinido' && usosActuales != null) {
        if (usosActuales <= 0) {
          throw Exception('QR sin usos restantes');
        }
        nuevosUsos = usosActuales - 1;
        updates['usosRestantes'] = nuevosUsos;
      }

      tx.update(ref, updates);
      return nuevosUsos;
    });
  }

  void _mostrarConfirmacionCompleta(Map<String, dynamic> qrInfo, {required bool esEntrada}) {
    final fotoFrente = qrInfo['fotoCarnetFrente'] as String?;
    final fotoReverso = qrInfo['fotoCarnetReverso'] as String?;
    final tipoAcceso = qrInfo['tipoAcceso'] as String?;
    final usosRestantes = qrInfo['usosRestantes'] as int?;
    final visitante = qrInfo['visitante'] ?? 'Visitante';
    final now = DateTime.now();
    final horaFormateada = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    // Obtener iniciales del nombre
    final iniciales = visitante.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: (esEntrada ? Colors.green : Colors.orange).withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header con gradiente dinámico (verde=entrada, naranja=salida)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: esEntrada 
                            ? [const Color(0xFF00C853), const Color(0xFF00E676)]
                            : [const Color(0xFFFF6F00), const Color(0xFFFF9800)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Icono de check animado
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                esEntrada ? Icons.login_rounded : Icons.logout_rounded,
                                color: esEntrada ? const Color(0xFF00C853) : const Color(0xFFFF6F00),
                                size: 40,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            esEntrada ? '¡Entrada Verificada!' : '¡Salida Registrada!',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            horaFormateada,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Contenido principal
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Avatar y nombre del visitante
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    iniciales,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      visitante,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.badge_outlined,
                                          size: 16,
                                          color: Colors.grey[500],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'CI: ${qrInfo['ci'] ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Tarjetas de información
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE8EAFF),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Casa destino
                                _buildInfoCard(
                                  icon: Icons.home_rounded,
                                  iconColor: const Color(0xFF5C6BC0),
                                  iconBgColor: const Color(0xFFE8EAF6),
                                  label: 'Casa destino',
                                  value: qrInfo['casa'] ?? 'N/A',
                                ),
                                
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                
                                // Tipo de acceso con badge
                                _buildInfoCard(
                                  icon: tipoAcceso == 'indefinido' 
                                      ? Icons.all_inclusive_rounded 
                                      : Icons.timelapse_rounded,
                                  iconColor: tipoAcceso == 'indefinido' 
                                      ? const Color(0xFF00897B) 
                                      : const Color(0xFFFF7043),
                                  iconBgColor: tipoAcceso == 'indefinido' 
                                      ? const Color(0xFFE0F2F1) 
                                      : const Color(0xFFFBE9E7),
                                  label: 'Tipo de acceso',
                                  value: tipoAcceso == 'indefinido' 
                                      ? 'Ilimitado' 
                                      : tipoAcceso == 'tiempo' 
                                          ? 'Por tiempo' 
                                          : 'Por usos',
                                  badge: tipoAcceso == 'indefinido' ? '∞' : null,
                                ),
                                
                                if (tipoAcceso != 'indefinido') ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1),
                                  ),
                                  
                                  // Usos restantes
                                  _buildInfoCard(
                                    icon: Icons.confirmation_number_rounded,
                                    iconColor: const Color(0xFFAB47BC),
                                    iconBgColor: const Color(0xFFF3E5F5),
                                    label: 'Usos restantes',
                                    value: '${usosRestantes ?? 0}',
                                    badge: '${usosRestantes ?? 0}',
                                  ),
                                ],
                                
                                // Placa si existe
                                if (qrInfo['placa'] != null) ...[
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1),
                                  ),
                                  _buildInfoCard(
                                    icon: Icons.directions_car_rounded,
                                    iconColor: const Color(0xFF42A5F5),
                                    iconBgColor: const Color(0xFFE3F2FD),
                                    label: 'Placa del vehículo',
                                    value: qrInfo['placa'],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          
                          // Fotos del carnet si existen
                          if (fotoFrente != null || fotoReverso != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFE082),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.verified_user_rounded,
                                        size: 18,
                                        color: Colors.amber[700],
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Documento verificado',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (fotoFrente != null)
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              fotoFrente,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                height: 70,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.broken_image, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (fotoFrente != null && fotoReverso != null)
                                        const SizedBox(width: 8),
                                      if (fotoReverso != null)
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              fotoReverso,
                                              height: 70,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                height: 70,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[200],
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Icons.broken_image, color: Colors.grey),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // Botón de continuar
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                // Solo cerrar el diálogo, NO hacer doble pop
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C853),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Continuar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
    String? badge,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
          ),
      ],
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
      onPopInvokedWithResult: (didPop, result) {
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

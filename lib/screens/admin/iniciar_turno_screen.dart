import 'package:flutter/material.dart';
import '../../models/guardia_model.dart';
import '../../services/guardia_service.dart';
import '../../services/turno_service.dart';

class IniciarTurnoScreen extends StatefulWidget {
  final String condominioId;
  final String tipoTurno; // 'diurno' o 'nocturno'

  const IniciarTurnoScreen({
    super.key,
    required this.condominioId,
    required this.tipoTurno,
  });

  @override
  State<IniciarTurnoScreen> createState() => _IniciarTurnoScreenState();
}

class _IniciarTurnoScreenState extends State<IniciarTurnoScreen> {
  GuardiaModel? _guardiaSeleccionado;
  bool _iniciandoTurno = false;

  bool get _esDiurno => widget.tipoTurno == 'diurno';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('Iniciar Turno ${_esDiurno ? 'Diurno' : 'Nocturno'}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildInfoTurno(),
          Expanded(child: _buildListaGuardias()),
          _buildBotonIniciar(),
        ],
      ),
    );
  }

  Widget _buildInfoTurno() {
    final color = _esDiurno ? Colors.orange : Colors.indigo;
    final icono = _esDiurno ? Icons.wb_sunny_rounded : Icons.nightlight_rounded;
    final horario = _esDiurno ? '6:00 AM - 6:00 PM' : '6:00 PM - 6:00 AM';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icono, color: color, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turno ${_esDiurno ? 'Diurno' : 'Nocturno'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  horario,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Selecciona un guardia para iniciar el turno',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaGuardias() {
    return FutureBuilder<List<GuardiaModel>>(
      future: GuardiaService.obtenerActivosPorTurno(widget.condominioId, widget.tipoTurno),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_rounded,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final guardias = snapshot.data ?? [];

        if (guardias.isEmpty) {
          return _buildSinGuardias();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: guardias.length,
          itemBuilder: (context, index) {
            return _buildGuardiaCard(guardias[index]);
          },
        );
      },
    );
  }

  Widget _buildSinGuardias() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.security_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No hay guardias ${_esDiurno ? 'diurnos' : 'nocturnos'} activos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega guardias ${_esDiurno ? 'diurnos' : 'nocturnos'} para poder iniciar turnos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardiaCard(GuardiaModel guardia) {
    final isSelected = _guardiaSeleccionado?.id == guardia.id;
    final color = _esDiurno ? Colors.orange : Colors.indigo;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isSelected 
              ? color
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _esDiurno ? Icons.wb_sunny_rounded : Icons.nightlight_rounded,
            color: isSelected ? color : Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
        title: Text(
          guardia.nombre,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isSelected 
                ? color
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              guardia.email,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                guardia.turnoDisplay,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        trailing: isSelected
            ? Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              )
            : null,
        onTap: () {
          setState(() {
            _guardiaSeleccionado = isSelected ? null : guardia;
          });
        },
      ),
    );
  }

  Widget _buildBotonIniciar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _guardiaSeleccionado != null && !_iniciandoTurno
              ? _iniciarTurno
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _esDiurno ? Colors.orange : Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _iniciandoTurno
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(_esDiurno ? Icons.wb_sunny_rounded : Icons.nightlight_rounded),
          label: Text(
            _iniciandoTurno
                ? 'Iniciando turno...'
                : _guardiaSeleccionado != null
                    ? 'Iniciar Turno - ${_guardiaSeleccionado!.nombre}'
                    : 'Selecciona un guardia',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _iniciarTurno() async {
    if (_guardiaSeleccionado == null) return;

    setState(() {
      _iniciandoTurno = true;
    });

    try {
      await TurnoService.iniciarTurnoAutomatico(
        _guardiaSeleccionado!.id,
        widget.condominioId,
        widget.tipoTurno,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Turno ${widget.tipoTurno} iniciado para ${_guardiaSeleccionado!.nombre}'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _iniciandoTurno = false;
        });
      }
    }
  }
}

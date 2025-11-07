import 'package:flutter/material.dart';
import '../../scripts/limpiar_duplicados.dart';

class DebugToolsScreen extends StatefulWidget {
  const DebugToolsScreen({super.key});

  @override
  State<DebugToolsScreen> createState() => _DebugToolsScreenState();
}

class _DebugToolsScreenState extends State<DebugToolsScreen> {
  bool _isLoading = false;
  String _resultado = '';

  Future<void> _ejecutarLimpieza() async {
    setState(() {
      _isLoading = true;
      _resultado = 'Ejecutando limpieza...';
    });

    try {
      await limpiarCredencialiesDuplicadas();
      
      if (mounted) {
        setState(() {
          _resultado = '✅ Limpieza completada exitosamente';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duplicados eliminados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultado = '❌ Error: $e';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _listarCredenciales() async {
    setState(() {
      _isLoading = true;
      _resultado = 'Listando credenciales...';
    });

    try {
      await listarCredenciales();
      
      if (mounted) {
        setState(() {
          _resultado = '✅ Ver consola para listado completo';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultado = '❌ Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛠️ Herramientas de Debug'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Advertencia
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ Estas herramientas modifican la base de datos. Usar con precaución.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Botón: Limpiar duplicados
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _ejecutarLimpieza,
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Limpiar Credenciales Duplicadas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Botón: Listar credenciales
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _listarCredenciales,
              icon: const Icon(Icons.list),
              label: const Text('Listar Todas las Credenciales'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Resultado
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              )
            else if (_resultado.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Text(
                  _resultado,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            const Spacer(),
            
            // Instrucciones
            const Text(
              'Instrucciones:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. "Limpiar Duplicados" elimina credenciales con el mismo email, manteniendo solo el más antiguo.\n\n'
              '2. "Listar Credenciales" muestra todas las credenciales en la consola de debug.\n\n'
              '3. Asegúrate de tener las reglas de Firebase abiertas antes de ejecutar.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

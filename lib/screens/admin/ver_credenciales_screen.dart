import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import '../../services/propietario_service.dart';

/// Centro de gestión de credenciales (v2).
///
/// La v2 guarda las contraseñas hasheadas (PBKDF2), por lo que NO se pueden
/// "ver". En su lugar, el super admin puede **resetear** la contraseña de
/// cualquier propietario, guardia o admin: se genera una nueva temporal y se
/// muestra una sola vez para comunicársela al usuario.
class VerCredencialesScreen extends StatefulWidget {
  const VerCredencialesScreen({super.key});

  @override
  State<VerCredencialesScreen> createState() => _VerCredencialesScreenState();
}

class _VerCredencialesScreenState extends State<VerCredencialesScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  String? _condominioId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                Navigator.canPop(context) ? Navigator.pop(context) : context.go('/lista'),
          ),
          title: const Text('Gestión de credenciales'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Propietarios'),
              Tab(text: 'Guardias'),
              Tab(text: 'Admins'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              padding: const EdgeInsets.all(12),
              child: const Text(
                'Las contraseñas están cifradas y no pueden verse. Reseteá para '
                'generar una nueva y comunicársela al usuario.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPropietarios(),
                  _buildGuardias(),
                  _buildAdmins(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Selector de condominio (para propietarios y guardias)
  // ---------------------------------------------------------------------------
  Widget _condominioSelector() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('condominios').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }
        final docs = snap.data!.docs;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            value: _condominioId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Condominio',
              border: OutlineInputBorder(),
            ),
            items: docs
                .map((d) => DropdownMenuItem(
                      value: d.id,
                      child: Text(d.data()['nombre']?.toString() ?? d.id),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _condominioId = v),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // PROPIETARIOS (casas)
  // ---------------------------------------------------------------------------
  Widget _buildPropietarios() {
    return Column(
      children: [
        _condominioSelector(),
        if (_condominioId == null)
          const Expanded(child: Center(child: Text('Elegí un condominio')))
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('condominios')
                  .doc(_condominioId)
                  .collection('casas')
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final casas = snap.data!.docs;
                if (casas.isEmpty) {
                  return const Center(child: Text('Sin casas'));
                }
                return ListView.separated(
                  itemCount: casas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final data = casas[i].data();
                    final casaId = casas[i].id;
                    return ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: Text('Casa $casaId'),
                      subtitle: Text(
                        'Propietario: ${data['propietario'] ?? '-'}',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => _resetPropietario(
                          _condominioId!,
                          casaId,
                          data['propietario']?.toString() ?? 'Casa $casaId',
                        ),
                        child: const Text('Resetear'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // GUARDIAS
  // ---------------------------------------------------------------------------
  Widget _buildGuardias() {
    return Column(
      children: [
        _condominioSelector(),
        if (_condominioId == null)
          const Expanded(child: Center(child: Text('Elegí un condominio')))
        else
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('guardias')
                  .where('condominioId', isEqualTo: _condominioId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final guardias = snap.data!.docs;
                if (guardias.isEmpty) {
                  return const Center(child: Text('Sin guardias'));
                }
                return ListView.separated(
                  itemCount: guardias.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final data = guardias[i].data();
                    final email = data['email']?.toString();
                    final nombre =
                        '${data['nombre'] ?? ''} ${data['apellido'] ?? ''}'.trim();
                    return ListTile(
                      leading: const Icon(Icons.security_outlined),
                      title: Text(nombre.isEmpty ? 'Guardia' : nombre),
                      subtitle: Text(email ?? 'sin email'),
                      trailing: FilledButton.tonal(
                        onPressed: email == null
                            ? null
                            : () => _resetAuthUser(
                                  email: email,
                                  nombre: nombre.isEmpty ? email : nombre,
                                ),
                        child: const Text('Resetear'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ADMINS
  // ---------------------------------------------------------------------------
  Widget _buildAdmins() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('administradores').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final admins = snap.data!.docs;
        if (admins.isEmpty) {
          return const Center(child: Text('Sin administradores'));
        }
        return ListView.separated(
          itemCount: admins.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final data = admins[i].data();
            final uid = admins[i].id;
            final email = data['email']?.toString() ?? '';
            final esSuper = (data['condominio']?.toString() ?? '') == 'Todos';
            return ListTile(
              leading: Icon(
                esSuper ? Icons.shield : Icons.admin_panel_settings_outlined,
              ),
              title: Text(data['nombre']?.toString() ?? email),
              subtitle: Text(
                '$email${esSuper ? ' · super' : ' · ${data['condominio'] ?? ''}'}',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _resetAuthUser(
                  uid: uid,
                  nombre: data['nombre']?.toString() ?? email,
                ),
                child: const Text('Resetear'),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Acciones de reseteo
  // ---------------------------------------------------------------------------
  Future<void> _resetPropietario(
      String condominio, String casa, String nombre) async {
    if (!await _confirm('Resetear contraseña de "$nombre"?')) return;
    _loading(true);
    try {
      final pass = await PropietarioService.resetPasswordPropietario(
        condominio: condominio,
        casa: casa,
      );
      _loading(false);
      if (pass == null) {
        _snack('No se pudo resetear');
      } else {
        _showPassword(nombre, pass);
      }
    } catch (e) {
      _loading(false);
      _snack('Error: $e');
    }
  }

  Future<void> _resetAuthUser(
      {String? uid, String? email, required String nombre}) async {
    if (!await _confirm('Resetear contraseña de "$nombre"?')) return;
    _loading(true);
    try {
      final res = await _functions.httpsCallable('resetAuthUserPassword').call({
        if (uid != null) 'uid': uid,
        if (email != null) 'email': email,
      });
      _loading(false);
      final pass = (res.data as Map)['newPassword']?.toString();
      if (pass == null) {
        _snack('No se pudo resetear');
      } else {
        _showPassword(nombre, pass);
      }
    } on FirebaseFunctionsException catch (e) {
      _loading(false);
      _snack('Error: ${e.message ?? e.code}');
    } catch (e) {
      _loading(false);
      _snack('Error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers UI
  // ---------------------------------------------------------------------------
  Future<bool> _confirm(String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  void _showPassword(String nombre, String pass) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nueva contraseña — $nombre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guardala y comunicásela al usuario. No se vuelve a mostrar.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                pass,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pass));
              _snack('Copiada');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copiar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _loading(bool on) {
    if (!mounted) return;
    if (on) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    } else {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

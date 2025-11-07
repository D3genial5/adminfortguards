// Uso: flutter pub run tool/seed_firestore.dart
// Este script sembrará datos directo en Firestore usando cloud_firestore
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main(List<String> args) async {
  // Inicializar Firebase
  await Firebase.initializeApp();
  final firestore = FirebaseFirestore.instance;

  // TXT relative to project root
  final txtPath = File('../contraseñas/usuarios_fortguards.txt').absolute.path;
  final txtFile = File(txtPath);
  if (!await txtFile.exists()) {
    stderr.writeln('No se encontró el archivo de texto en $txtPath');
    exit(1);
  }

  final lines = await txtFile.readAsLines();
  final condos = <String, Map<int, List<String>>>{};
  bool inPropietarios = false;
  String? currentCondo;
  int? currentCasa;

  for (var line in lines) {
    line = line.trim();
    if (line.startsWith('PROPIETARIOS')) {
      inPropietarios = true;
      continue;
    }
    if (inPropietarios && line.startsWith('VISITANTES')) break;
    if (!inPropietarios) continue;

    final condoMatch = RegExp(r'^\*\s+(.+):').firstMatch(line);
    if (condoMatch != null) {
      currentCondo = condoMatch.group(1)!.trim();
      condos[currentCondo] = {};
      continue;
    }

    final casaMatch = RegExp(r'^-\s+Casa\s+(\d+):').firstMatch(line);
    if (casaMatch != null) {
      currentCasa = int.parse(casaMatch.group(1)!);
      condos[currentCondo!]![currentCasa] = [];
      continue;
    }

    final resMatch = RegExp(r'^\*\s+Residentes:\s+(.+)').firstMatch(line);
    if (resMatch != null && currentCondo != null && currentCasa != null) {
      final residentes = resMatch.group(1)!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      condos[currentCondo]![currentCasa] = residentes;
    }
  }

  if (condos.isEmpty) {
    stderr.writeln('No se encontró información de condominios en el TXT');
    exit(1);
  }

  stderr.writeln('Seeding ${condos.length} condominios...');

  final existingDocs = await firestore.collection('condominios').get();
  for (final doc in existingDocs.docs) {
    if (!condos.containsKey(doc.id)) {
      stderr.writeln('Eliminando condominio de prueba: ${doc.id}');
      await doc.reference.delete();
    }
  }

  for (final entry in condos.entries) {
    final condoId = entry.key;
    final casas = entry.value;

    final condoRef = firestore.collection('condominios').doc(condoId);
    await condoRef.set({'nombre': condoId});

    for (final casaEntry in casas.entries) {
      final numero = casaEntry.key;
      final residentes = casaEntry.value;
      final propietario = residentes.isNotEmpty ? residentes.first : '';
      await condoRef.collection('casas').doc(numero.toString()).set({
        'numero': numero,
        'propietario': propietario,
        'residentes': residentes,
        'estadoExpensa': 'pagada',
      });
    }
  }

  stderr.writeln('Seed completado correctamente.');
  stderr.writeln('IMPORTANTE: Ahora ejecuta "flutter run" y verifica que se muestren las 4 casas de Villa del Rocio');
  exit(0);
}
